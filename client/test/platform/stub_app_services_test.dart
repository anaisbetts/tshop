import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/platform/app_services.dart';

void main() {
  late AppServices services;

  setUp(() {
    services = bindAppServices(talker: Talker());
  });

  test('bindAppServices returns stubs that cannot install', () {
    expect(services, isA<StubAppServices>());
    expect(services.canInstall, isFalse);
  });

  test('appServicesProvider is stubbed', () {
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

  test('scanInstalled and capabilities are empty', () async {
    expect(await services.scanInstalled(), isEmpty);
    expect(await services.metCapabilities(), isEmpty);
  });

  test('install, uninstall, and open throw', () async {
    final unsupported = isA<AppServiceUnsupported>();
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
}
