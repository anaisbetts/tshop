import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/logging/app_talker.dart';

const _webDemoRefuse =
    'tShop web is a demo and cannot change packages on a device.';

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

/// A package present on the device, as Library and tile marks need it.
final class InstalledPackage {
  /// Creates an installed-package record.
  const InstalledPackage({
    required this.packageName,
    required this.versionCode,
    required this.signingSha256,
  });

  /// Android package name.
  final String packageName;

  /// Installed version code.
  final int versionCode;

  /// Signing-certificate SHA-256, hex, for other-source comparison.
  final String signingSha256;
}

/// Device-facing store operations.
///
/// The web target binds [StubAppServices] and must not install anything.
/// Android PackageInstaller wiring lands with the storefront.
abstract interface class AppServices {
  /// Whether this host can install, update, or uninstall APKs.
  bool get canInstall;

  /// Packages on the device. Empty on the web demo.
  Future<List<InstalledPackage>> scanInstalled();

  /// Capability tags this device meets. Empty on the web demo.
  Future<Set<String>> metCapabilities();

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

/// Web (and current Android) host: no package manager, no notifications.
///
/// ponytail: one stub until PackageInstaller exists. Split with
/// conditional imports when the Android host would pull dart:io or
/// plugins.
final class StubAppServices implements AppServices {
  /// Creates stubs that log through [talker] and refuse installs.
  StubAppServices({required this.talker});

  /// Logger used when a stubbed action is skipped or refused.
  final Talker talker;

  @override
  bool get canInstall => false;

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

/// Binds device services for this process.
///
/// Web is always [StubAppServices]. Android stays on the same stub
/// until a PackageInstaller host exists, so a debug APK cannot start
/// install sessions by accident.
AppServices bindAppServices({required Talker talker}) {
  return StubAppServices(talker: talker);
}

/// Device services used by the app. Overridden at the composition root.
final appServicesProvider = Provider<AppServices>(
  (ref) => bindAppServices(talker: ref.watch(talkerProvider)),
);
