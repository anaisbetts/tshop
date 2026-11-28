import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/platform/android_app_services.dart';
import 'package:tshop/src/platform/app_services.dart';

void main() {
  late AppServices services;

  setUp(() {
    services = bindAppServices(talker: Talker());
  });

  test('bindAppServices returns stubs on non-Android hosts', () {
    expect(services, isA<StubAppServices>());
    expect(services.canInstall, isFalse);
  });

  test('bindAppServices returns AndroidAppServices on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    final bound = bindAppServices(talker: Talker());
    expect(bound, isA<AndroidAppServices>());
    expect(bound.canInstall, isTrue);
  });

  test('appServicesProvider is stubbed on non-Android hosts', () {
    final container = ProviderContainer(
      overrides: [
        talkerProvider.overrideWithValue(Talker()),
      ],
    );
    addTearDown(container.dispose);
    final bound = container.read(appServicesProvider);
    expect(bound, isA<StubAppServices>());
    expect(bound.canInstall, isFalse);
  });

  test('deviceInfo, scanInstalled, capabilities, and install grant', () async {
    expect(
      await services.deviceInfo(),
      const DeviceInfo(
        supportedAbis: [],
        sdkInt: 0,
        hasPServiceBridge: false,
      ),
    );
    expect(await services.scanInstalled(), isEmpty);
    expect(await services.metCapabilities(), isEmpty);
    expect(await services.canRequestPackageInstalls(), isFalse);
  });

  test('confirmation helpers and event streams are safe no-ops', () async {
    expect(
      await services.launchPendingConfirmation(packageName: 'org.example.app'),
      isFalse,
    );
    await services.cancelPendingConfirmation(packageName: 'org.example.app');
    expect(await services.installEvents.toList(), isEmpty);
    expect(await services.gamepadHatEvents.toList(), isEmpty);
  });

  test('install, uninstall, and open throw', () async {
    final unsupported = isA<AppServiceUnsupported>();
    await expectLater(
      services.installApkFile(
        packageName: 'org.example.app',
        filePath: '/tmp/app.apk',
      ),
      throwsA(unsupported),
    );
    await expectLater(
      services.enqueueInstall(
        packageName: 'org.example.app',
        apk: Uri.parse('https://example.com/app.apk'),
      ),
      throwsA(unsupported),
    );
    await expectLater(
      services.enqueueUninstall(packageName: 'org.example.app'),
      throwsA(unsupported),
    );
    await expectLater(
      services.openInstalled(packageName: 'org.example.app'),
      throwsA(unsupported),
    );
  });

  test('notifications and permission prompts are no-ops', () async {
    await services.notifyUpdates(count: 2);
    await services.openInstallPermissionSettings();
    await services.requestNotificationPermission();
  });

  test('InstalledPackage exposes signingSha256s default and explicit', () {
    const single = InstalledPackage(
      packageName: 'org.example.single',
      versionCode: 10,
      signingSha256: 'deadbeef',
    );
    expect(single.signingSha256s, ['deadbeef']);

    const multi = InstalledPackage(
      packageName: 'org.example.multi',
      versionCode: 11,
      signingSha256: 'cert1',
      signingSha256s: ['cert1', 'cert2'],
    );
    expect(multi.signingSha256s, ['cert1', 'cert2']);
  });
}
