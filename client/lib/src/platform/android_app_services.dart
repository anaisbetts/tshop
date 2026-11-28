import 'package:flutter/services.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/platform/app_services.dart';

/// Method channel name for Android package and device operations.
const appServicesMethodChannelName = 'dev.anais.tshop/app_services';

/// Event channel name for Android APK installation lifecycle events.
const installEventsChannelName = 'dev.anais.tshop/install_events';

/// Event channel name for Android gamepad `AXIS_HAT_X/Y` d-pad events.
const gamepadHatChannelName = 'dev.anais.tshop/gamepad_hat';

const _defaultMethodChannel = MethodChannel(appServicesMethodChannelName);
const _defaultInstallEventsChannel = EventChannel(installEventsChannelName);
const _defaultGamepadHatChannel = EventChannel(gamepadHatChannelName);

/// Android [AppServices] implementation backed by Kotlin platform channels.
///
/// Communicates with `MainActivity`, `PServiceBridge`,
/// `PackageInstallerBridge`, and `PackageScanner` via [MethodChannel] and
/// [EventChannel]. Safe to import on web (does not depend on `dart:io`).
final class AndroidAppServices implements AppServices {
  /// Creates an Android platform-channel service client.
  AndroidAppServices({
    required this.talker,
    this._methodChannel = _defaultMethodChannel,
    this._installEventsChannel = _defaultInstallEventsChannel,
    this._gamepadHatChannel = _defaultGamepadHatChannel,
  });

  /// Logger used for channel diagnostics and parsing anomalies.
  final Talker talker;

  final MethodChannel _methodChannel;
  final EventChannel _installEventsChannel;
  final EventChannel _gamepadHatChannel;

  Stream<InstallEvent>? _installEvents;
  Stream<GamepadHatEvent>? _gamepadHatEvents;

  @override
  bool get canInstall => true;

  @override
  Future<DeviceInfo> deviceInfo() async {
    try {
      final raw = await _methodChannel.invokeMapMethod<String, Object?>(
        'deviceInfo',
      );
      if (raw == null) {
        talker.warning('android: deviceInfo returned null');
        return const DeviceInfo(
          supportedAbis: [],
          sdkInt: 0,
          hasPServiceBridge: false,
        );
      }
      return _parseDeviceInfo(raw);
    } on PlatformException catch (error, stackTrace) {
      talker.error('android: deviceInfo failed', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<InstalledPackage>> scanInstalled() async {
    try {
      final rawList = await _methodChannel.invokeListMethod<Object?>(
        'scanInstalled',
      );
      if (rawList == null) {
        return const [];
      }
      final packages = <InstalledPackage>[];
      for (final item in rawList) {
        final parsed = _parseInstalledPackage(item, talker);
        if (parsed != null) {
          packages.add(parsed);
        }
      }
      return List<InstalledPackage>.unmodifiable(packages);
    } on PlatformException catch (error, stackTrace) {
      talker.error('android: scanInstalled failed', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<Set<String>> metCapabilities() async {
    // v1 starts with an empty hardware-capability tag vocabulary.
    return const <String>{};
  }

  @override
  Future<bool> canRequestPackageInstalls() async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      return granted ?? false;
    } on PlatformException catch (error, stackTrace) {
      talker.error(
        'android: canRequestPackageInstalls failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> installApkFile({
    required String packageName,
    required String filePath,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'installApkFile',
        <String, Object?>{
          'packageName': packageName,
          'filePath': filePath,
        },
      );
    } on PlatformException catch (error, stackTrace) {
      talker.error(
        'android: installApkFile failed for $packageName',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<bool> launchPendingConfirmation({required String packageName}) async {
    try {
      final launched = await _methodChannel.invokeMethod<bool>(
        'launchPendingConfirmation',
        <String, Object?>{'packageName': packageName},
      );
      return launched ?? false;
    } on PlatformException catch (error, stackTrace) {
      talker.error(
        'android: launchPendingConfirmation failed for $packageName',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> cancelPendingConfirmation({required String packageName}) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'cancelPendingConfirmation',
        <String, Object?>{'packageName': packageName},
      );
    } on PlatformException catch (error, stackTrace) {
      talker.error(
        'android: cancelPendingConfirmation failed for $packageName',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Stream<InstallEvent> get installEvents {
    return _installEvents ??= _installEventsChannel
        .receiveBroadcastStream()
        .expand<InstallEvent>((raw) {
          final parsed = _parseInstallEvent(raw, talker);
          return parsed == null ? const [] : <InstallEvent>[parsed];
        });
  }

  @override
  Stream<GamepadHatEvent> get gamepadHatEvents {
    return _gamepadHatEvents ??= _gamepadHatChannel
        .receiveBroadcastStream()
        .expand<GamepadHatEvent>((raw) {
          final parsed = _parseGamepadHatEvent(raw, talker);
          return parsed == null ? const [] : <GamepadHatEvent>[parsed];
        });
  }

  @override
  Future<void> enqueueInstall({
    required String packageName,
    required Uri apk,
  }) async {
    if (apk.isScheme('file')) {
      return installApkFile(
        packageName: packageName,
        filePath: apk.toFilePath(),
      );
    }
    throw const AppServiceUnsupported(
      'enqueueInstall requires a local file URI; download the APK and call '
      'installApkFile.',
    );
  }

  @override
  Future<void> enqueueUninstall({required String packageName}) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'uninstallPackage',
        <String, Object?>{'packageName': packageName},
      );
    } on PlatformException catch (error, stackTrace) {
      talker.error(
        'android: uninstallPackage failed for $packageName',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> openInstalled({required String packageName}) async {
    try {
      final opened = await _methodChannel.invokeMethod<bool>(
        'openInstalled',
        <String, Object?>{'packageName': packageName},
      );
      if (opened != true) {
        talker.warning('android: no launch intent for $packageName');
      }
    } on PlatformException catch (error, stackTrace) {
      talker.error(
        'android: openInstalled failed for $packageName',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> notifyUpdates({required int count}) async {
    talker.debug(
      'android: notifyUpdates($count) skipped until notifications land',
    );
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    try {
      await _methodChannel.invokeMethod<void>('openInstallPermissionSettings');
    } on PlatformException catch (error, stackTrace) {
      talker.error(
        'android: openInstallPermissionSettings failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> requestNotificationPermission() async {
    talker.debug(
      'android: requestNotificationPermission skipped until notifications land',
    );
  }
}

DeviceInfo _parseDeviceInfo(Map<String, Object?> raw) {
  final abisRaw = raw['supportedAbis'];
  final supportedAbis = abisRaw is List<Object?>
      ? abisRaw.whereType<String>().toList(growable: false)
      : const <String>[];
  final sdkInt = (raw['sdkInt'] as num?)?.toInt() ?? 0;
  final hasPServiceBridge = raw['hasPServiceBridge'] == true;
  return DeviceInfo(
    supportedAbis: supportedAbis,
    sdkInt: sdkInt,
    hasPServiceBridge: hasPServiceBridge,
  );
}

InstalledPackage? _parseInstalledPackage(Object? raw, Talker talker) {
  if (raw is! Map<Object?, Object?>) {
    talker.warning('android: ignoring non-map installed package entry: $raw');
    return null;
  }
  final packageName = raw['packageName'];
  final versionCode = raw['versionCode'];
  if (packageName is! String || packageName.isEmpty || versionCode is! num) {
    talker.warning('android: ignoring malformed installed package: $raw');
    return null;
  }
  final primarySha256 = raw['signingSha256'] is String
      ? raw['signingSha256']! as String
      : '';
  final allRaw = raw['signingSha256s'];
  final allSha256s = allRaw is List<Object?>
      ? allRaw.whereType<String>().toList(growable: false)
      : null;
  return InstalledPackage(
    packageName: packageName,
    versionCode: versionCode.toInt(),
    signingSha256: primarySha256,
    signingSha256s: allSha256s,
  );
}

InstallEvent? _parseInstallEvent(Object? raw, Talker talker) {
  if (raw is! Map<Object?, Object?>) {
    talker.warning('android: ignoring non-map install event: $raw');
    return null;
  }
  final type = raw['type'];
  final packageName = raw['packageName'] is String
      ? raw['packageName']! as String
      : '';
  final sessionId = (raw['sessionId'] as num?)?.toInt() ?? -1;

  switch (type) {
    case 'awaiting_confirmation':
      return InstallAwaitingConfirmation(
        packageName: packageName,
        sessionId: sessionId,
      );
    case 'succeeded':
      return InstallSucceeded(
        packageName: packageName,
        sessionId: sessionId,
      );
    case 'failed':
      final message = raw['message'] is String
          ? raw['message']! as String
          : 'Install failed';
      final aborted = raw['aborted'] == true;
      return InstallFailed(
        packageName: packageName,
        sessionId: sessionId,
        message: message,
        aborted: aborted,
      );
    default:
      talker.warning('android: ignoring unknown install event: $raw');
      return null;
  }
}

GamepadHatEvent? _parseGamepadHatEvent(Object? raw, Talker talker) {
  if (raw is! Map<Object?, Object?>) {
    talker.warning('android: ignoring non-map gamepad hat event: $raw');
    return null;
  }
  final xRaw = raw['x'];
  final yRaw = raw['y'];
  if (xRaw is! num || yRaw is! num) {
    talker.warning('android: ignoring malformed gamepad hat event: $raw');
    return null;
  }
  return GamepadHatEvent(
    x: _clampHatAxis(xRaw.toInt()),
    y: _clampHatAxis(yRaw.toInt()),
  );
}

int _clampHatAxis(int value) {
  if (value < -1) return -1;
  if (value > 1) return 1;
  return value;
}
