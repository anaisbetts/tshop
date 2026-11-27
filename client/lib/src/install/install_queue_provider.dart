import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/data/remote/dio_client.dart';
import 'package:tshop/src/install/apk_downloader.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/variant_selector.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/platform/app_services.dart';

/// Maximum number of concurrent APK downloads permitted by the queue.
const int maxConcurrentApkDownloads = 2;

const String _defaultApkBasePath = '/apk';
const String _installUnsupportedMessage =
    'Installing apps is only supported on Android devices.';
const String _installPermissionRequiredMessage =
    'Allow "Install unknown apps" for tShop in Android Settings to continue.';
const String _noCompatibleVariantMessage =
    'No compatible APK variant is available for this device.';
const Set<String> _selfPackageNames = <String>{
  'dev.anais.tshop',
  'dev.anais.tshop.dev',
};

const DeviceInfo _fallbackDeviceInfo = DeviceInfo(
  supportedAbis: <String>[],
  sdkInt: 0,
  hasPServiceBridge: false,
);

/// Immutable snapshot of all active, awaiting-confirmation, and failed tasks
/// managed by [InstallQueueNotifier].
@immutable
final class InstallQueueState {
  /// Creates an [InstallQueueState].
  InstallQueueState({
    Map<String, InstallTask> tasks = const <String, InstallTask>{},
    List<String> order = const <String>[],
  }) : tasks = Map<String, InstallTask>.unmodifiable(tasks),
       order = List<String>.unmodifiable(order);

  /// Tasks keyed by Android package name.
  final Map<String, InstallTask> tasks;

  /// Stable insertion-ordered list of queued package names.
  final List<String> order;

  /// Tasks in stable FIFO display order.
  List<InstallTask> get orderedTasks =>
      List<InstallTask>.unmodifiable(<InstallTask>[
        for (final packageName in order)
          if (tasks.containsKey(packageName)) tasks[packageName]!,
      ]);

  /// Returns the active or failed task for [packageName], or `null` if absent.
  InstallTask? taskFor(String packageName) => tasks[packageName];

  /// Total number of tasks currently in the queue.
  int get count => orderedTasks.length;

  /// Whether at least one task is queued, downloading, verifying, or
  /// installing.
  bool get hasActiveWork => orderedTasks.any((task) => task.stage.isInProgress);

  /// Whether at least one task is waiting for user confirmation on Library.
  bool get hasAwaitingConfirmation => orderedTasks.any(
    (task) => task.stage == InstallTaskStage.awaitingConfirm,
  );

  /// First task awaiting user confirmation, or `null` if none.
  InstallTask? get nextAwaitingConfirmation {
    for (final task in orderedTasks) {
      if (task.stage == InstallTaskStage.awaitingConfirm) {
        return task;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstallQueueState &&
            mapEquals(other.tasks, tasks) &&
            listEquals(other.order, order);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      tasks.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    Object.hashAll(order),
  );
}

/// Manages APK downloads, SHA-256 verification, and serialized Android
/// installation handoff with up to [maxConcurrentApkDownloads] parallel
/// downloads and one active installer handoff at a time.
class InstallQueueNotifier extends Notifier<InstallQueueState> {
  StreamSubscription<InstallEvent>? _installEventsSub;
  final Map<String, _DownloadRequest> _pendingRequests =
      <String, _DownloadRequest>{};
  final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};
  final Set<String> _activeDownloads = <String>{};
  final Set<String> _enqueuing = <String>{};
  final List<String> _readyToInstall = <String>[];
  String? _activeInstallPackage;
  bool _updateAllInFlight = false;
  bool _disposed = false;

  @override
  InstallQueueState build() {
    final services = ref.watch(appServicesProvider);
    _disposed = false;
    unawaited(_installEventsSub?.cancel());
    _installEventsSub = services.installEvents.listen(
      _handleInstallEvent,
      onError: (Object error, StackTrace stackTrace) {
        ref
            .read(talkerProvider)
            .error('installEvents stream error', error, stackTrace);
      },
    );
    ref.onDispose(_disposeResources);
    return InstallQueueState();
  }

  /// Enqueues an APK download and install for [entry].
  ///
  /// Uses [variantOverride] when provided; otherwise chooses the best
  /// compatible variant for the host device. Respects Privacy Mode without
  /// falling back to the counted host on failure.
  Future<void> enqueueInstall(
    CatalogEntry entry, {
    CatalogVariant? variantOverride,
    bool? privacyMode,
  }) async {
    final packageName = entry.packageName;
    if (entry.rehostMode == RehostMode.landing) {
      ref
          .read(talkerProvider)
          .warning('Skipped install for landing-page entry $packageName');
      return;
    }

    final existing = state.taskFor(packageName);
    if (_enqueuing.contains(packageName) ||
        (existing != null && existing.stage != InstallTaskStage.failed)) {
      return;
    }

    _enqueuing.add(packageName);
    try {
      final services = ref.read(appServicesProvider);
      final deviceInfo = await _readDeviceInfo();
      if (_disposed) {
        return;
      }

      final release = entry.release;
      final variant =
          variantOverride ??
          (release == null ? null : pickBestVariant(release, deviceInfo));
      if (variant == null) {
        if (release != null && release.variants.isNotEmpty) {
          _upsertTask(
            InstallTask(
              packageName: packageName,
              appName: entry.name.resolve(),
              variant: release.variants.first,
              intent: installIntentInstall,
              stage: InstallTaskStage.failed,
              totalBytes: release.variants.first.sizeBytes,
              errorMessage: _noCompatibleVariantMessage,
            ),
          );
        } else {
          ref
              .read(talkerProvider)
              .warning('No release variants available for $packageName');
        }
        return;
      }

      final installed = await _readInstalledPackages();
      if (_disposed) {
        return;
      }
      final installedPkg = installed[packageName];
      final intent =
          installedPkg != null &&
              matchesAllowedSigningCert(installedPkg, entry.allowedSigningCerts)
          ? installIntentUpdate
          : installIntentInstall;

      final appName = entry.name.resolve();

      if (!services.canInstall) {
        _upsertTask(
          InstallTask(
            packageName: packageName,
            appName: appName,
            variant: variant,
            intent: intent,
            stage: InstallTaskStage.failed,
            totalBytes: variant.sizeBytes,
            errorMessage: _installUnsupportedMessage,
          ),
        );
        return;
      }

      if (!deviceInfo.hasPServiceBridge) {
        final canRequest = await services.canRequestPackageInstalls();
        if (_disposed) {
          return;
        }
        if (!canRequest) {
          _upsertTask(
            InstallTask(
              packageName: packageName,
              appName: appName,
              variant: variant,
              intent: intent,
              stage: InstallTaskStage.failed,
              totalBytes: variant.sizeBytes,
              errorMessage: _installPermissionRequiredMessage,
              needsInstallPermission: true,
            ),
          );
          return;
        }
      }

      final effectivePrivacyMode =
          privacyMode ?? ref.read<bool>(privacyModeProvider);
      final config = ref.read(tshopConfigProvider);
      final apkBaseUrl =
          ref.read(catalogProvider).value?.catalog.apkBaseUrl ??
          _defaultApkBasePath;
      final downloadUri = entry.apkDownloadUri(
        catalogBaseUrl: config.catalogBaseUrl,
        apkBaseUrl: apkBaseUrl,
        variant: variant,
        intent: intent,
        privacyMode: effectivePrivacyMode,
      );

      _pendingRequests[packageName] = _DownloadRequest(
        entry: entry,
        variant: variant,
        uri: downloadUri,
        privacyMode: effectivePrivacyMode,
      );

      _upsertTask(
        InstallTask(
          packageName: packageName,
          appName: appName,
          variant: variant,
          intent: intent,
          stage: InstallTaskStage.queued,
          totalBytes: variant.sizeBytes,
        ),
      );
      _pumpDownloads();
    } finally {
      _enqueuing.remove(packageName);
    }
  }

  /// Launches Android's deferred confirmation dialog for a package currently
  /// in [InstallTaskStage.awaitingConfirm].
  Future<bool> confirmPendingInstall(String packageName) async {
    final services = ref.read(appServicesProvider);
    try {
      return await services.launchPendingConfirmation(
        packageName: packageName,
      );
    } on Object catch (error, stackTrace) {
      ref
          .read(talkerProvider)
          .error(
            'Failed to launch pending confirmation for $packageName',
            error,
            stackTrace,
          );
      return false;
    }
  }

  /// Cancels an active download or pending installation for [packageName] and
  /// removes the task from the queue.
  Future<void> cancelTask(String packageName) async {
    final existing = state.taskFor(packageName);
    final cancelToken = _cancelTokens.remove(packageName);
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Cancelled by user');
    }

    _pendingRequests.remove(packageName);
    _activeDownloads.remove(packageName);
    _readyToInstall.remove(packageName);
    if (_activeInstallPackage == packageName) {
      _activeInstallPackage = null;
    }

    _removeTask(packageName);

    if (existing != null &&
        (existing.stage == InstallTaskStage.installing ||
            existing.stage == InstallTaskStage.awaitingConfirm)) {
      try {
        await ref
            .read(appServicesProvider)
            .cancelPendingConfirmation(packageName: packageName);
      } on Object catch (error, stackTrace) {
        ref
            .read(talkerProvider)
            .warning(
              'Failed to cancel pending confirmation for $packageName',
              error,
              stackTrace,
            );
      }
    }

    if (!_disposed) {
      _pumpDownloads();
      _pumpInstalls();
    }
  }

  /// Restarts a failed task for [entry].
  Future<void> retryTask(
    CatalogEntry entry, {
    CatalogVariant? variantOverride,
    bool? privacyMode,
  }) async {
    final existing = state.taskFor(entry.packageName);
    final effectiveVariant = variantOverride ?? existing?.variant;
    if (existing != null && existing.stage == InstallTaskStage.failed) {
      _removeTask(entry.packageName);
    }
    await enqueueInstall(
      entry,
      variantOverride: effectiveVariant,
      privacyMode: privacyMode,
    );
  }

  /// Removes a failed task for [packageName] from the queue.
  void dismissFailed(String packageName) {
    final existing = state.taskFor(packageName);
    if (existing == null || existing.stage != InstallTaskStage.failed) {
      return;
    }
    _pendingRequests.remove(packageName);
    _removeTask(packageName);
  }

  /// Enqueues updates for every entry in [entries] whose current status is
  /// [AppCatalogStatus.updateAvailable].
  ///
  /// Guarded against concurrent double-taps, and schedules tShop self-updates
  /// last in the batch.
  Future<void> updateAll(
    List<CatalogEntry> entries, {
    bool? privacyMode,
  }) async {
    if (_updateAllInFlight) {
      return;
    }
    _updateAllInFlight = true;
    try {
      final installed = await _readInstalledPackages();
      if (_disposed) {
        return;
      }

      final standardUpdates = <CatalogEntry>[];
      final selfUpdates = <CatalogEntry>[];

      for (final entry in entries) {
        final existing = state.taskFor(entry.packageName);
        if (existing != null && existing.stage != InstallTaskStage.failed) {
          continue;
        }
        final status = computeAppCatalogStatus(
          entry: entry,
          installedPackage: installed[entry.packageName],
        );
        if (status != AppCatalogStatus.updateAvailable) {
          continue;
        }
        if (_selfPackageNames.contains(entry.packageName)) {
          selfUpdates.add(entry);
        } else {
          standardUpdates.add(entry);
        }
      }

      for (final entry in <CatalogEntry>[...standardUpdates, ...selfUpdates]) {
        if (_disposed) {
          return;
        }
        await enqueueInstall(entry, privacyMode: privacyMode);
      }
    } finally {
      _updateAllInFlight = false;
    }
  }

  /// Opens an installed app on the device.
  Future<void> openApp(String packageName) async {
    await ref.read(appServicesProvider).openInstalled(packageName: packageName);
  }

  /// Requests package uninstallation and refreshes [installedPackagesProvider].
  Future<void> uninstallApp(String packageName) async {
    await ref
        .read(appServicesProvider)
        .enqueueUninstall(packageName: packageName);
    if (!_disposed) {
      await ref.read(installedPackagesProvider.notifier).refresh();
    }
  }

  /// Opens Android's "Install unknown apps" settings screen for tShop.
  Future<void> openInstallPermissionSettings() async {
    await ref.read(appServicesProvider).openInstallPermissionSettings();
  }

  void _pumpDownloads() {
    if (_disposed) {
      return;
    }
    while (_activeDownloads.length < maxConcurrentApkDownloads) {
      final next = _nextQueuedDownload();
      if (next == null) {
        return;
      }
      _activeDownloads.add(next);
      unawaited(_runDownload(next));
    }
  }

  String? _nextQueuedDownload() {
    for (final task in state.orderedTasks) {
      if (task.stage == InstallTaskStage.queued &&
          !_activeDownloads.contains(task.packageName) &&
          _pendingRequests.containsKey(task.packageName)) {
        return task.packageName;
      }
    }
    return null;
  }

  Future<void> _runDownload(String packageName) async {
    final request = _pendingRequests[packageName];
    final initialTask = state.taskFor(packageName);
    if (request == null || initialTask == null || _disposed) {
      _activeDownloads.remove(packageName);
      _pumpDownloads();
      return;
    }

    final cancelToken = CancelToken();
    _cancelTokens[packageName] = cancelToken;

    _upsertTask(
      initialTask.copyWith(
        stage: InstallTaskStage.downloading,
        progress: 0,
        bytesReceived: 0,
        clearErrorMessage: true,
        needsInstallPermission: false,
      ),
    );

    final downloader = ref.read(apkDownloaderProvider);
    try {
      final localPath = await downloader.downloadAndVerify(
        uri: request.uri,
        expectedSha256: request.variant.sha256,
        expectedSizeBytes: request.variant.sizeBytes,
        cancelToken: cancelToken,
        onProgress: (bytesReceived, totalBytes) {
          if (_disposed || cancelToken.isCancelled) {
            return;
          }
          final current = state.taskFor(packageName);
          if (current == null ||
              current.stage != InstallTaskStage.downloading) {
            return;
          }
          final effectiveTotal = totalBytes > 0
              ? totalBytes
              : request.variant.sizeBytes;
          final progress = effectiveTotal > 0
              ? (bytesReceived / effectiveTotal).clamp(0.0, 1.0)
              : 0.0;
          _upsertTask(
            current.copyWith(
              bytesReceived: bytesReceived,
              totalBytes: effectiveTotal,
              progress: progress,
            ),
          );
        },
        onVerifying: () {
          if (_disposed || cancelToken.isCancelled) {
            return;
          }
          final current = state.taskFor(packageName);
          if (current == null) {
            return;
          }
          _upsertTask(
            current.copyWith(
              stage: InstallTaskStage.verifying,
              progress: 1,
              bytesReceived: current.totalBytes > 0
                  ? current.totalBytes
                  : request.variant.sizeBytes,
            ),
          );
        },
      );

      if (_disposed || cancelToken.isCancelled) {
        return;
      }

      final current = state.taskFor(packageName);
      if (current == null) {
        return;
      }

      // Ensure observers always see the verifying stage even when a test fake
      // omits the onVerifying callback.
      _upsertTask(
        current.copyWith(
          stage: InstallTaskStage.verifying,
          progress: 1,
          bytesReceived: current.totalBytes > 0
              ? current.totalBytes
              : request.variant.sizeBytes,
          localApkPath: localPath,
        ),
      );

      if (!_readyToInstall.contains(packageName)) {
        _readyToInstall.add(packageName);
      }
      _pumpInstalls();
    } on DioException catch (error, stackTrace) {
      if (_disposed || CancelToken.isCancel(error) || cancelToken.isCancelled) {
        return;
      }
      ref
          .read(talkerProvider)
          .error('APK download failed for $packageName', error, stackTrace);
      _markTaskFailed(
        packageName,
        _formatErrorMessage(error, privacyMode: request.privacyMode),
      );
    } on Object catch (error, stackTrace) {
      if (_disposed || cancelToken.isCancelled) {
        return;
      }
      ref
          .read(talkerProvider)
          .error(
            'APK download/verification failed for $packageName',
            error,
            stackTrace,
          );
      _markTaskFailed(
        packageName,
        _formatErrorMessage(error, privacyMode: request.privacyMode),
      );
    } finally {
      _cancelTokens.remove(packageName);
      _activeDownloads.remove(packageName);
      _pumpDownloads();
    }
  }

  void _pumpInstalls() {
    if (_disposed || _activeInstallPackage != null) {
      return;
    }
    while (_readyToInstall.isNotEmpty) {
      final packageName = _readyToInstall.removeAt(0);
      final task = state.taskFor(packageName);
      final localPath = task?.localApkPath;
      if (task == null || localPath == null || localPath.isEmpty) {
        continue;
      }
      _activeInstallPackage = packageName;
      unawaited(_handoffInstall(packageName, localPath));
      return;
    }
  }

  Future<void> _handoffInstall(String packageName, String localApkPath) async {
    final services = ref.read(appServicesProvider);
    try {
      final deviceInfo = await _readDeviceInfo();
      if (_disposed || _activeInstallPackage != packageName) {
        return;
      }

      if (!deviceInfo.hasPServiceBridge) {
        final canRequest = await services.canRequestPackageInstalls();
        if (_disposed || _activeInstallPackage != packageName) {
          return;
        }
        if (!canRequest) {
          _activeInstallPackage = null;
          _markTaskFailed(
            packageName,
            _installPermissionRequiredMessage,
            needsInstallPermission: true,
          );
          _pumpInstalls();
          return;
        }
      }

      final current = state.taskFor(packageName);
      if (current == null) {
        _activeInstallPackage = null;
        _pumpInstalls();
        return;
      }

      _upsertTask(
        current.copyWith(
          stage: InstallTaskStage.installing,
          progress: 1,
          clearErrorMessage: true,
          needsInstallPermission: false,
        ),
      );

      await services.installApkFile(
        packageName: packageName,
        filePath: localApkPath,
      );
    } on Object catch (error, stackTrace) {
      if (_disposed) {
        return;
      }
      ref
          .read(talkerProvider)
          .error('installApkFile failed for $packageName', error, stackTrace);
      if (_activeInstallPackage == packageName) {
        _activeInstallPackage = null;
      }
      _markTaskFailed(packageName, _formatErrorMessage(error));
      _pumpInstalls();
    }
  }

  void _handleInstallEvent(InstallEvent event) {
    if (_disposed) {
      return;
    }

    switch (event) {
      case InstallAwaitingConfirmation(:final packageName, :final sessionId):
        if (_activeInstallPackage == packageName) {
          _activeInstallPackage = null;
        }
        final current = state.taskFor(packageName);
        if (current != null) {
          _upsertTask(
            current.copyWith(
              stage: InstallTaskStage.awaitingConfirm,
              progress: 1,
              sessionId: sessionId,
              clearErrorMessage: true,
              needsInstallPermission: false,
            ),
          );
        }
        _pumpInstalls();
      case InstallSucceeded(:final packageName):
        if (_activeInstallPackage == packageName) {
          _activeInstallPackage = null;
        }
        final completed = state.taskFor(packageName);
        _pendingRequests.remove(packageName);
        _readyToInstall.remove(packageName);
        _removeTask(packageName);

        if (completed != null) {
          unawaited(
            _cleanupCachedApk(completed.variant.sha256),
          );
        }
        unawaited(ref.read(installedPackagesProvider.notifier).refresh());
        _pumpInstalls();
        _pumpDownloads();
      case InstallFailed(:final packageName, :final message, :final aborted):
        if (_activeInstallPackage == packageName) {
          _activeInstallPackage = null;
        }
        _readyToInstall.remove(packageName);
        final errorText = aborted
            ? 'Installation was cancelled.'
            : (message.trim().isNotEmpty ? message : 'Installation failed.');
        _markTaskFailed(packageName, errorText);
        _pumpInstalls();
        _pumpDownloads();
    }
  }

  Future<void> _cleanupCachedApk(String sha256) async {
    try {
      await ref.read(apkDownloaderProvider).deleteCachedApk(sha256);
    } on Object catch (error, stackTrace) {
      ref
          .read(talkerProvider)
          .debug('Failed to clean up cached APK ($sha256): $error', stackTrace);
    }
  }

  Future<DeviceInfo> _readDeviceInfo() async {
    final existing = ref.read(deviceInfoProvider).value;
    if (existing != null) {
      return existing;
    }
    try {
      return await ref.read(deviceInfoProvider.future);
    } on Object {
      return _fallbackDeviceInfo;
    }
  }

  Future<Map<String, InstalledPackage>> _readInstalledPackages() async {
    final existing = ref.read(installedPackagesProvider).value;
    if (existing != null) {
      return existing;
    }
    try {
      return await ref.read(installedPackagesProvider.future);
    } on Object {
      return const <String, InstalledPackage>{};
    }
  }

  void _markTaskFailed(
    String packageName,
    String errorMessage, {
    bool needsInstallPermission = false,
  }) {
    final current = state.taskFor(packageName);
    if (current == null) {
      return;
    }
    _upsertTask(
      current.copyWith(
        stage: InstallTaskStage.failed,
        errorMessage: errorMessage,
        needsInstallPermission: needsInstallPermission,
      ),
    );
  }

  void _upsertTask(InstallTask task) {
    if (_disposed) {
      return;
    }
    final nextTasks = Map<String, InstallTask>.of(state.tasks)
      ..[task.packageName] = task;
    final nextOrder = List<String>.of(state.order);
    if (!nextOrder.contains(task.packageName)) {
      nextOrder.add(task.packageName);
    }
    state = InstallQueueState(tasks: nextTasks, order: nextOrder);
  }

  void _removeTask(String packageName) {
    if (_disposed || !state.tasks.containsKey(packageName)) {
      return;
    }
    final nextTasks = Map<String, InstallTask>.of(state.tasks)
      ..remove(packageName);
    final nextOrder = List<String>.of(state.order)..remove(packageName);
    state = InstallQueueState(tasks: nextTasks, order: nextOrder);
  }

  void _disposeResources() {
    _disposed = true;
    unawaited(_installEventsSub?.cancel());
    _installEventsSub = null;
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) {
        token.cancel('InstallQueueNotifier disposed');
      }
    }
    _cancelTokens.clear();
    _pendingRequests.clear();
    _activeDownloads.clear();
    _enqueuing.clear();
    _readyToInstall.clear();
    _activeInstallPackage = null;
  }
}

/// Scans installed Android packages on startup and exposes [refresh] after
/// installs or uninstalls complete.
class InstalledPackagesNotifier
    extends AsyncNotifier<Map<String, InstalledPackage>> {
  @override
  Future<Map<String, InstalledPackage>> build() async {
    final services = ref.watch(appServicesProvider);
    final packages = await services.scanInstalled();
    return _indexPackages(packages);
  }

  /// Re-scans installed packages on the device and updates state in place.
  Future<void> refresh() async {
    final previous = state.value;
    try {
      final packages = await ref.read(appServicesProvider).scanInstalled();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<Map<String, InstalledPackage>>(
        _indexPackages(packages),
      );
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      if (previous != null) {
        ref
            .read(talkerProvider)
            .error('Failed to refresh installed packages', error, stackTrace);
        state = AsyncData<Map<String, InstalledPackage>>(previous);
      } else {
        state = AsyncError<Map<String, InstalledPackage>>(error, stackTrace);
      }
    }
  }
}

/// Manages the Privacy Mode setting controlling whether APK downloads fetch
/// directly from upstream URLs instead of tShop's counted download host.
class PrivacyModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Updates whether Privacy Mode is enabled.
  void setEnabled({required bool enabled}) {
    if (state == enabled) {
      return;
    }
    state = enabled;
  }
}

/// Hardware ABI, Android SDK level, and `PServiceBridge` availability for the
/// host device.
final deviceInfoProvider = FutureProvider<DeviceInfo>((ref) {
  return ref.watch(appServicesProvider).deviceInfo();
});

/// Capability tags satisfied by the host device.
final metCapabilitiesProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(appServicesProvider).metCapabilities();
});

/// Platform-appropriate [ApkDownloader] (overridable in tests).
final apkDownloaderProvider = Provider<ApkDownloader>((ref) {
  return createDefaultApkDownloader(
    dio: ref.watch(dioProvider),
    config: ref.watch(tshopConfigProvider),
    talker: ref.watch(talkerProvider),
  );
});

/// Whether Privacy Mode is enabled (`false` by default).
final privacyModeProvider = NotifierProvider<PrivacyModeNotifier, bool>(
  PrivacyModeNotifier.new,
);

/// Installed packages indexed by Android package name.
final installedPackagesProvider =
    AsyncNotifierProvider<
      InstalledPackagesNotifier,
      Map<String, InstalledPackage>
    >(
      InstalledPackagesNotifier.new,
    );

/// Active APK download and installation queue.
final installQueueProvider =
    NotifierProvider<InstallQueueNotifier, InstallQueueState>(
      InstallQueueNotifier.new,
    );

/// Total count shown in the Library tab badge: active/pending/failed queue
/// items plus catalog entries with an available update not already queued.
final libraryBadgeCountProvider = Provider<int>((ref) {
  final queue = ref.watch(installQueueProvider);
  final catalog = ref.watch(
    catalogProvider.select((asyncState) => asyncState.value?.catalog),
  );
  final installed = ref.watch(
    installedPackagesProvider.select(
      (asyncState) => asyncState.value ?? const <String, InstalledPackage>{},
    ),
  );

  var count = queue.count;
  if (catalog == null) {
    return count;
  }

  for (final entry in catalog.entries) {
    if (queue.tasks.containsKey(entry.packageName)) {
      continue;
    }
    final status = computeAppCatalogStatus(
      entry: entry,
      installedPackage: installed[entry.packageName],
    );
    if (status == AppCatalogStatus.updateAvailable) {
      count++;
    }
  }
  return count;
});

/// Resolves full storefront, installed-package, variant, capability, and queue
/// state for a single catalog entry by Android `packageName`.
final ProviderFamily<ResolvedAppState?, String> resolvedAppStateProvider =
    Provider.autoDispose.family<ResolvedAppState?, String>((ref, packageName) {
      final entry = ref.watch(catalogEntryProvider(packageName));
      if (entry == null) {
        return null;
      }
      final installed = ref.watch(
        installedPackagesProvider.select(
          (asyncState) =>
              asyncState.value ?? const <String, InstalledPackage>{},
        ),
      );
      final activeTask = ref.watch(
        installQueueProvider.select((queue) => queue.taskFor(packageName)),
      );
      final deviceInfo = ref.watch(
        deviceInfoProvider.select(
          (asyncState) => asyncState.value ?? _fallbackDeviceInfo,
        ),
      );
      final metCapabilities = ref.watch(
        metCapabilitiesProvider.select(
          (asyncState) => asyncState.value ?? const <String>{},
        ),
      );

      return resolveAppInstallState(
        entry: entry,
        installedPackages: installed,
        activeTask: activeTask,
        metCapabilities: metCapabilities,
        deviceInfo: deviceInfo,
      );
    });

final class _DownloadRequest {
  const _DownloadRequest({
    required this.entry,
    required this.variant,
    required this.uri,
    required this.privacyMode,
  });

  final CatalogEntry entry;
  final CatalogVariant variant;
  final Uri uri;
  final bool privacyMode;
}

Map<String, InstalledPackage> _indexPackages(List<InstalledPackage> packages) {
  return Map<String, InstalledPackage>.unmodifiable(<String, InstalledPackage>{
    for (final pkg in packages) pkg.packageName: pkg,
  });
}

String _formatErrorMessage(Object error, {bool privacyMode = false}) {
  if (error is ApkVerificationException) {
    return error.description;
  }
  if (error is AppServiceUnsupported) {
    return error.message;
  }
  if (error is DioException) {
    final detail = error.message ?? 'Network error (${error.type.name}).';
    if (privacyMode) {
      return 'Upstream download failed in Privacy Mode: $detail';
    }
    return detail;
  }
  return error.toString();
}
