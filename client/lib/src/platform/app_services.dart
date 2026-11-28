import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/platform/app_services_binding_stub.dart'
    if (dart.library.io) 'package:tshop/src/platform/app_services_binding_io.dart'
    as platform_binding;

const _webDemoRefuse =
    'tShop web is a demo and cannot change packages on a device.';

const _stubDeviceInfo = DeviceInfo(
  supportedAbis: [],
  sdkInt: 0,
  hasPServiceBridge: false,
);

/// Thrown when a device-only action is invoked on a host that cannot
/// do it. The web demo always throws this for install, uninstall, and
/// open.
final class AppServiceUnsupported implements Exception {
  /// Creates an exception with a [message] safe to log or show.
  const AppServiceUnsupported(this.message);

  /// Why the action did not run.
  final String message;

  @override
  String toString() => 'AppServiceUnsupported: $message';
}

/// Hardware and runtime capabilities reported by the host device.
@immutable
final class DeviceInfo {
  /// Creates a device-info snapshot.
  const DeviceInfo({
    required this.supportedAbis,
    required this.sdkInt,
    required this.hasPServiceBridge,
  });

  /// Supported Android ABIs in preference order (for example `arm64-v8a`).
  final List<String> supportedAbis;

  /// Android API level (`Build.VERSION.SDK_INT`), or `0` on non-Android hosts.
  final int sdkInt;

  /// Whether AYN Thor's `PServerBinder` root bridge is reachable.
  final bool hasPServiceBridge;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DeviceInfo &&
            listEquals(supportedAbis, other.supportedAbis) &&
            sdkInt == other.sdkInt &&
            hasPServiceBridge == other.hasPServiceBridge);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(supportedAbis),
    sdkInt,
    hasPServiceBridge,
  );

  @override
  String toString() =>
      'DeviceInfo(supportedAbis: $supportedAbis, sdkInt: $sdkInt, '
      'hasPServiceBridge: $hasPServiceBridge)';
}

/// A package present on the device, as Library and tile marks need it.
@immutable
final class InstalledPackage {
  /// Creates an installed-package record.
  const InstalledPackage({
    required this.packageName,
    required this.versionCode,
    required this.signingSha256,
    this._signingSha256s,
  });

  /// Android package name.
  final String packageName;

  /// Installed version code.
  final int versionCode;

  /// Primary signing-certificate SHA-256, lowercase hex, for other-source
  /// comparison.
  final String signingSha256;

  final List<String>? _signingSha256s;

  /// All signing-certificate SHA-256 digests (current signers and lineage),
  /// lowercase hex.
  List<String> get signingSha256s {
    final explicit = _signingSha256s;
    if (explicit != null) {
      return List<String>.unmodifiable(explicit);
    }
    return signingSha256.isEmpty ? const [] : <String>[signingSha256];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is InstalledPackage &&
            packageName == other.packageName &&
            versionCode == other.versionCode &&
            signingSha256 == other.signingSha256 &&
            listEquals(signingSha256s, other.signingSha256s));
  }

  @override
  int get hashCode => Object.hash(
    packageName,
    versionCode,
    signingSha256,
    Object.hashAll(signingSha256s),
  );

  @override
  String toString() =>
      'InstalledPackage(packageName: $packageName, versionCode: $versionCode, '
      'signingSha256: $signingSha256, signingSha256s: $signingSha256s)';
}

/// Lifecycle event emitted while installing an APK on Android.
@immutable
sealed class InstallEvent {
  /// Creates an install lifecycle event for [packageName].
  const InstallEvent({
    required this.packageName,
    required this.sessionId,
  });

  /// Target Android package name.
  final String packageName;

  /// Android `PackageInstaller` session id, or `0` for `PServiceBridge`.
  final int sessionId;
}

/// The system package installer requires user confirmation to complete.
final class InstallAwaitingConfirmation extends InstallEvent {
  /// Creates an awaiting-confirmation event.
  const InstallAwaitingConfirmation({
    required super.packageName,
    required super.sessionId,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is InstallAwaitingConfirmation &&
            packageName == other.packageName &&
            sessionId == other.sessionId);
  }

  @override
  int get hashCode => Object.hash(packageName, sessionId);

  @override
  String toString() =>
      'InstallAwaitingConfirmation(packageName: $packageName, '
      'sessionId: $sessionId)';
}

/// The APK installation completed successfully.
final class InstallSucceeded extends InstallEvent {
  /// Creates an install-succeeded event.
  const InstallSucceeded({
    required super.packageName,
    required super.sessionId,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is InstallSucceeded &&
            packageName == other.packageName &&
            sessionId == other.sessionId);
  }

  @override
  int get hashCode => Object.hash(packageName, sessionId);

  @override
  String toString() =>
      'InstallSucceeded(packageName: $packageName, sessionId: $sessionId)';
}

/// The APK installation failed or was aborted by the user.
final class InstallFailed extends InstallEvent {
  /// Creates an install-failed event.
  const InstallFailed({
    required super.packageName,
    required super.sessionId,
    required this.message,
    this.aborted = false,
  });

  /// Human-readable error message from the installer.
  final String message;

  /// Whether the user cancelled or dismissed the confirmation prompt.
  final bool aborted;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is InstallFailed &&
            packageName == other.packageName &&
            sessionId == other.sessionId &&
            message == other.message &&
            aborted == other.aborted);
  }

  @override
  int get hashCode => Object.hash(packageName, sessionId, message, aborted);

  @override
  String toString() =>
      'InstallFailed(packageName: $packageName, sessionId: $sessionId, '
      'message: $message, aborted: $aborted)';
}

/// Quantized directional hat (`AXIS_HAT_X` / `AXIS_HAT_Y`) event from a
/// gamepad d-pad.
@immutable
final class GamepadHatEvent {
  /// Creates a hat event with [x] and [y] values in `{-1, 0, 1}`.
  const GamepadHatEvent({
    required this.x,
    required this.y,
  });

  /// Horizontal hat direction: `-1` left, `0` neutral, `1` right.
  final int x;

  /// Vertical hat direction: `-1` up, `0` neutral, `1` down.
  final int y;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is GamepadHatEvent && x == other.x && y == other.y);
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'GamepadHatEvent(x: $x, y: $y)';
}

/// Device-facing store operations.
///
/// The web target binds [StubAppServices] and must not install anything.
/// Android binds `AndroidAppServices` over platform channels.
abstract interface class AppServices {
  /// Whether this host can install, update, or uninstall APKs.
  bool get canInstall;

  /// Hardware ABIs, Android SDK level, and root-bridge availability.
  Future<DeviceInfo> deviceInfo();

  /// Packages on the device. Empty on the web demo.
  Future<List<InstalledPackage>> scanInstalled();

  /// Capability tags this device meets. Empty on the web demo.
  Future<Set<String>> metCapabilities();

  /// Whether the app currently holds Android's "Install unknown apps" grant.
  Future<bool> canRequestPackageInstalls();

  /// Starts installing a local APK at [filePath] for [packageName].
  ///
  /// Install outcomes are emitted on [installEvents].
  Future<void> installApkFile({
    required String packageName,
    required String filePath,
  });

  /// Launches a pending `PackageInstaller` confirmation dialog for
  /// [packageName], returning `false` when no confirmation is pending.
  Future<bool> launchPendingConfirmation({required String packageName});

  /// Abandons any pending install confirmation for [packageName].
  Future<void> cancelPendingConfirmation({required String packageName});

  /// Broadcast stream of APK installation lifecycle events.
  Stream<InstallEvent> get installEvents;

  /// Broadcast stream of Android gamepad `AXIS_HAT_X/Y` d-pad events.
  Stream<GamepadHatEvent> get gamepadHatEvents;

  /// Enqueue a download and package install.
  Future<void> enqueueInstall({
    required String packageName,
    required Uri apk,
  });

  /// Request that [packageName] be uninstalled.
  Future<void> enqueueUninstall({required String packageName});

  /// Open an installed app.
  Future<void> openInstalled({required String packageName});

  /// Show the Library-bound update notification.
  Future<void> notifyUpdates({required int count});

  /// Open the system screen for installing unknown apps.
  Future<void> openInstallPermissionSettings();

  /// Request notification permission.
  Future<void> requestNotificationPermission();
}

/// Binds device services for this process.
///
/// Android binds `AndroidAppServices`; web and non-Android hosts bind
/// [StubAppServices] without importing `dart:io` on web.
AppServices bindAppServices({required Talker talker}) {
  return platform_binding.bindPlatformAppServices(talker: talker);
}

/// Device services used by the app. Overridden at the composition root.
final appServicesProvider = Provider<AppServices>(
  (ref) => bindAppServices(talker: ref.watch(talkerProvider)),
);

/// Web and non-Android host: no package manager, no notifications.
final class StubAppServices implements AppServices {
  /// Creates stubs that log through [talker] and refuse installs.
  StubAppServices({required this.talker});

  /// Logger used when a stubbed action is skipped or refused.
  final Talker talker;

  @override
  bool get canInstall => false;

  @override
  Future<DeviceInfo> deviceInfo() async {
    talker.info('web demo: returning stub device info');
    return _stubDeviceInfo;
  }

  @override
  Future<List<InstalledPackage>> scanInstalled() async {
    talker.info('web demo: package scan is empty');
    return const [];
  }

  @override
  Future<Set<String>> metCapabilities() async {
    talker.info('web demo: no device capabilities');
    return const <String>{};
  }

  @override
  Future<bool> canRequestPackageInstalls() async {
    talker.info('web demo: install-unknown-apps permission is unavailable');
    return false;
  }

  @override
  Future<void> installApkFile({
    required String packageName,
    required String filePath,
  }) async {
    _refuse('install', '$packageName from $filePath');
  }

  @override
  Future<bool> launchPendingConfirmation({required String packageName}) async {
    talker.info('web demo: no pending confirmation for $packageName');
    return false;
  }

  @override
  Future<void> cancelPendingConfirmation({required String packageName}) async {
    talker.info('web demo: skipped cancelling confirmation for $packageName');
  }

  @override
  Stream<InstallEvent> get installEvents => const Stream<InstallEvent>.empty();

  @override
  Stream<GamepadHatEvent> get gamepadHatEvents =>
      const Stream<GamepadHatEvent>.empty();

  @override
  Future<void> enqueueInstall({
    required String packageName,
    required Uri apk,
  }) async {
    _refuse('install', '$packageName from $apk');
  }

  @override
  Future<void> enqueueUninstall({required String packageName}) async {
    _refuse('uninstall', packageName);
  }

  @override
  Future<void> openInstalled({required String packageName}) async {
    _refuse('open', packageName);
  }

  @override
  Future<void> notifyUpdates({required int count}) async {
    talker.info('web demo: skipped update notification ($count)');
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    talker.info('web demo: skipped install-unknown-apps settings');
  }

  @override
  Future<void> requestNotificationPermission() async {
    talker.info('web demo: skipped notification permission');
  }

  Never _refuse(String action, String detail) {
    talker.warning('web demo: refused $action ($detail)');
    throw const AppServiceUnsupported(_webDemoRefuse);
  }
}
