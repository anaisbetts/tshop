import 'package:flutter/foundation.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/install/variant_selector.dart';
import 'package:tshop/src/platform/app_services.dart';

/// Download intent value for fresh installations.
const String installIntentInstall = 'install';

/// Download intent value for updates to an existing matching installation.
const String installIntentUpdate = 'update';

const int _bytesPerKilobyte = 1024;
const int _bytesPerMegabyte = 1024 * 1024;
const int _bytesPerGigabyte = 1024 * 1024 * 1024;

const DeviceInfo _stubDeviceInfo = DeviceInfo(
  supportedAbis: <String>[],
  sdkInt: 0,
  hasPServiceBridge: false,
);

/// Lifecycle stage of an active or failed [InstallTask] in the install queue.
enum InstallTaskStage {
  /// Waiting for a download slot.
  queued,

  /// Streaming APK bytes from the catalog host or upstream URL.
  downloading,

  /// Verifying downloaded APK integrity against expected SHA-256.
  verifying,

  /// Handed to Android's installer (`PServiceBridge` or `PackageInstaller`).
  installing,

  /// Staged in `PackageInstaller` and waiting for user confirmation on Library.
  awaitingConfirm,

  /// Failed or cancelled; stays visible until retried or dismissed.
  failed;

  /// Whether this task is actively running or waiting to run automatically.
  bool get isInProgress => switch (this) {
    InstallTaskStage.queued ||
    InstallTaskStage.downloading ||
    InstallTaskStage.verifying ||
    InstallTaskStage.installing => true,
    InstallTaskStage.awaitingConfirm || InstallTaskStage.failed => false,
  };
}

/// Resolved catalog status for a single [CatalogEntry] on this device.
enum AppCatalogStatus {
  /// Not installed and rehosted by tShop.
  available,

  /// Distributed via publisher landing page rather than rehosted APKs.
  landing,

  /// Installed with a matching signing certificate and up to date (or newer).
  installed,

  /// Installed with a matching signing certificate and older than the catalog.
  updateAvailable,

  /// Installed, but signed by a certificate outside `allowedSigningCerts`.
  otherSource,

  /// Queued for download.
  queued,

  /// Actively downloading APK bytes.
  downloading,

  /// Verifying SHA-256 digest of the downloaded APK.
  verifying,

  /// Handed to the platform installer.
  installing,

  /// Downloaded and waiting for the user to confirm installation in Library.
  awaitingConfirm,

  /// Download, verification, or installation failed.
  failed,
}

/// Immutable state record for a single package in the install queue.
@immutable
final class InstallTask {
  /// Creates an [InstallTask].
  const InstallTask({
    required this.packageName,
    required this.appName,
    required this.variant,
    required this.intent,
    required this.stage,
    this.progress = 0.0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.needsInstallPermission = false,
    this.localApkPath,
    this.sessionId,
  });

  /// Target Android package name.
  final String packageName;

  /// Resolved display name of the application.
  final String appName;

  /// Selected APK variant being downloaded or installed.
  final CatalogVariant variant;

  /// Download intent (`'install'` or `'update'`).
  final String intent;

  /// Current stage of the task.
  final InstallTaskStage stage;

  /// Normalized download/install progress in `0.0..1.0`.
  final double progress;

  /// Number of bytes received so far.
  final int bytesReceived;

  /// Expected total size in bytes.
  final int totalBytes;

  /// Readable failure reason when [stage] is [InstallTaskStage.failed].
  final String? errorMessage;

  /// Whether installation is blocked on Android's "Install unknown apps" grant.
  final bool needsInstallPermission;

  /// Local filesystem path to the verified `.apk` once downloaded.
  final String? localApkPath;

  /// Android `PackageInstaller` session id, when available.
  final int? sessionId;

  /// Returns a copy with updated fields.
  InstallTask copyWith({
    String? packageName,
    String? appName,
    CatalogVariant? variant,
    String? intent,
    InstallTaskStage? stage,
    double? progress,
    int? bytesReceived,
    int? totalBytes,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? needsInstallPermission,
    String? localApkPath,
    bool clearLocalApkPath = false,
    int? sessionId,
    bool clearSessionId = false,
  }) {
    return InstallTask(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      variant: variant ?? this.variant,
      intent: intent ?? this.intent,
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      needsInstallPermission:
          needsInstallPermission ?? this.needsInstallPermission,
      localApkPath: clearLocalApkPath
          ? null
          : (localApkPath ?? this.localApkPath),
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstallTask &&
            other.packageName == packageName &&
            other.appName == appName &&
            other.variant == variant &&
            other.intent == intent &&
            other.stage == stage &&
            other.progress == progress &&
            other.bytesReceived == bytesReceived &&
            other.totalBytes == totalBytes &&
            other.errorMessage == errorMessage &&
            other.needsInstallPermission == needsInstallPermission &&
            other.localApkPath == localApkPath &&
            other.sessionId == sessionId;
  }

  @override
  int get hashCode => Object.hash(
    packageName,
    appName,
    variant,
    intent,
    stage,
    progress,
    bytesReceived,
    totalBytes,
    errorMessage,
    needsInstallPermission,
    localApkPath,
    sessionId,
  );

  @override
  String toString() =>
      'InstallTask(packageName: $packageName, stage: ${stage.name}, '
      'progress: $progress, needsInstallPermission: $needsInstallPermission)';
}

/// Complete resolved storefront state for a [CatalogEntry].
@immutable
final class ResolvedAppState {
  /// Creates a [ResolvedAppState].
  ResolvedAppState({
    required this.entry,
    required this.status,
    required this.installedPackage,
    required this.activeTask,
    required this.selectedVariant,
    required List<String> unmetCapabilities,
    List<CatalogVariant> compatibleVariants = const <CatalogVariant>[],
    this.needsUserChoice = false,
  }) : unmetCapabilities = List<String>.unmodifiable(unmetCapabilities),
       compatibleVariants = List<CatalogVariant>.unmodifiable(
         compatibleVariants,
       );

  /// Source catalog entry.
  final CatalogEntry entry;

  /// Computed catalog/install status for tiles, Detail, and Library.
  final AppCatalogStatus status;

  /// Installed package metadata from the device, if present.
  final InstalledPackage? installedPackage;

  /// Active or failed install queue task for this package, if any.
  final InstallTask? activeTask;

  /// Best compatible APK variant for the current device, if available.
  final CatalogVariant? selectedVariant;

  /// All compatible APK variants ordered by preference.
  final List<CatalogVariant> compatibleVariants;

  /// Whether the user should be shown a variant chooser before downloading.
  final bool needsUserChoice;

  /// Capability tags required by [entry] that the current device does not meet.
  final List<String> unmetCapabilities;

  /// Whether the device is missing one or more required capabilities.
  bool get hasUnmetCapabilities => unmetCapabilities.isNotEmpty;

  /// Whether the installed version code is strictly ahead of the catalog
  /// release while carrying a trusted signing certificate.
  bool get isDeviceAhead {
    final installed = installedPackage;
    final releaseCode = entry.release?.versionCode;
    if (installed == null || releaseCode == null) {
      return false;
    }
    return matchesAllowedSigningCert(installed, entry.allowedSigningCerts) &&
        installed.versionCode > releaseCode;
  }

  /// Whether the installed version cannot be compared because the catalog
  /// release omits a `versionCode`.
  bool get isVersionUnclear {
    final installed = installedPackage;
    if (installed == null || entry.rehostMode == RehostMode.landing) {
      return false;
    }
    return matchesAllowedSigningCert(installed, entry.allowedSigningCerts) &&
        entry.release?.versionCode == null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ResolvedAppState &&
            other.entry == entry &&
            other.status == status &&
            other.installedPackage == installedPackage &&
            other.activeTask == activeTask &&
            other.selectedVariant == selectedVariant &&
            listEquals(other.compatibleVariants, compatibleVariants) &&
            other.needsUserChoice == needsUserChoice &&
            listEquals(other.unmetCapabilities, unmetCapabilities);
  }

  @override
  int get hashCode => Object.hash(
    entry,
    status,
    installedPackage,
    activeTask,
    selectedVariant,
    Object.hashAll(compatibleVariants),
    needsUserChoice,
    Object.hashAll(unmetCapabilities),
  );
}

/// Computes the [ResolvedAppState] for [entry] from local device and queue
/// state.
ResolvedAppState resolveAppInstallState({
  required CatalogEntry entry,
  required Map<String, InstalledPackage> installedPackages,
  InstallTask? activeTask,
  Set<String> metCapabilities = const <String>{},
  DeviceInfo deviceInfo = _stubDeviceInfo,
}) {
  final installed = installedPackages[entry.packageName];
  final release = entry.release;
  final selection = release == null
      ? null
      : resolveVariantSelection(release, deviceInfo);
  final unmet = <String>[
    for (final cap in entry.capabilities)
      if (!metCapabilities.contains(cap)) cap,
  ];
  final status = computeAppCatalogStatus(
    entry: entry,
    installedPackage: installed,
    activeTask: activeTask,
  );

  return ResolvedAppState(
    entry: entry,
    status: status,
    installedPackage: installed,
    activeTask: activeTask,
    selectedVariant: activeTask?.variant ?? selection?.bestVariant,
    compatibleVariants:
        selection?.compatibleVariants ?? const <CatalogVariant>[],
    needsUserChoice: selection?.needsUserChoice ?? false,
    unmetCapabilities: unmet,
  );
}

/// Computes the [AppCatalogStatus] for [entry] given its [installedPackage]
/// and [activeTask].
AppCatalogStatus computeAppCatalogStatus({
  required CatalogEntry entry,
  InstalledPackage? installedPackage,
  InstallTask? activeTask,
}) {
  if (activeTask != null) {
    return _statusFromTaskStage(activeTask.stage);
  }
  if (entry.rehostMode == RehostMode.landing) {
    return AppCatalogStatus.landing;
  }
  if (installedPackage == null) {
    return AppCatalogStatus.available;
  }
  if (!matchesAllowedSigningCert(installedPackage, entry.allowedSigningCerts)) {
    return AppCatalogStatus.otherSource;
  }

  final releaseVersionCode = entry.release?.versionCode;
  if (releaseVersionCode != null &&
      installedPackage.versionCode < releaseVersionCode) {
    return AppCatalogStatus.updateAvailable;
  }
  return AppCatalogStatus.installed;
}

/// Returns `true` when [installed] carries a signing certificate permitted by
/// [allowedSigningCerts], or when [allowedSigningCerts] is empty.
///
/// Comparison is case-insensitive and ignores colons, hyphens, and whitespace.
bool matchesAllowedSigningCert(
  InstalledPackage installed,
  List<String> allowedSigningCerts,
) {
  if (allowedSigningCerts.isEmpty) {
    return true;
  }

  final normalizedAllowlist = <String>{
    for (final cert in allowedSigningCerts)
      if (_normalizeCert(cert).isNotEmpty) _normalizeCert(cert),
  };
  if (normalizedAllowlist.isEmpty) {
    return true;
  }

  for (final cert in installed.signingSha256s) {
    final normalized = _normalizeCert(cert);
    if (normalized.isNotEmpty && normalizedAllowlist.contains(normalized)) {
      return true;
    }
  }
  return false;
}

/// Formats a byte count into a concise human-readable label such as `"512 KB"`
/// or `"4.4 MB"`.
String formatByteSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  if (bytes < _bytesPerKilobyte) {
    return '$bytes B';
  }

  final kilobytes = (bytes / _bytesPerKilobyte).round();
  if (kilobytes < _bytesPerKilobyte) {
    return '$kilobytes KB';
  }

  if (bytes < _bytesPerGigabyte) {
    final megabytes = bytes / _bytesPerMegabyte;
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  final gigabytes = bytes / _bytesPerGigabyte;
  return '${gigabytes.toStringAsFixed(1)} GB';
}

AppCatalogStatus _statusFromTaskStage(InstallTaskStage stage) {
  return switch (stage) {
    InstallTaskStage.queued => AppCatalogStatus.queued,
    InstallTaskStage.downloading => AppCatalogStatus.downloading,
    InstallTaskStage.verifying => AppCatalogStatus.verifying,
    InstallTaskStage.installing => AppCatalogStatus.installing,
    InstallTaskStage.awaitingConfirm => AppCatalogStatus.awaitingConfirm,
    InstallTaskStage.failed => AppCatalogStatus.failed,
  };
}

String _normalizeCert(String value) {
  return value.replaceAll(RegExp(r'[\s:-]'), '').toLowerCase();
}
