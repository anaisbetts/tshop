import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/platform/android_app_services.dart';
import 'package:tshop/src/platform/app_services.dart';

const _methodChannel = MethodChannel(appServicesMethodChannelName);
const _installEventsMethodChannel = MethodChannel(installEventsChannelName);
const _gamepadHatMethodChannel = MethodChannel(gamepadHatChannelName);
const _codec = StandardMethodCodec();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AndroidAppServices services;
  late List<MethodCall> recordedCalls;

  setUp(() {
    recordedCalls = <MethodCall>[];
    services = AndroidAppServices(talker: Talker());
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(_methodChannel, null)
          ..setMockMethodCallHandler(_installEventsMethodChannel, null)
          ..setMockMethodCallHandler(_gamepadHatMethodChannel, null);
    // Reference kept explicit for readability; handlers cleared above.
    expect(messenger, isNotNull);
  });

  test('canInstall is true and metCapabilities is empty in v1', () async {
    expect(services.canInstall, isTrue);
    expect(await services.metCapabilities(), isEmpty);
  });

  test(
    'deviceInfo parses supportedAbis, sdkInt, and hasPServiceBridge',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_methodChannel, (call) async {
            recordedCalls.add(call);
            if (call.method == 'deviceInfo') {
              return <String, Object?>{
                'supportedAbis': <String>['arm64-v8a', 'armeabi-v7a'],
                'sdkInt': 35,
                'hasPServiceBridge': true,
              };
            }
            return null;
          });

      final info = await services.deviceInfo();
      expect(
        info,
        const DeviceInfo(
          supportedAbis: ['arm64-v8a', 'armeabi-v7a'],
          sdkInt: 35,
          hasPServiceBridge: true,
        ),
      );
      expect(recordedCalls.map((c) => c.method), ['deviceInfo']);
    },
  );

  test('scanInstalled parses packages and skips malformed entries', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (call) async {
          recordedCalls.add(call);
          if (call.method == 'scanInstalled') {
            return <Object?>[
              <String, Object?>{
                'packageName': 'org.dolphinemu.dolphinemu',
                'versionCode': 24090,
                'signingSha256': 'aaa111',
                'signingSha256s': <String>['aaa111', 'bbb222'],
              },
              <String, Object?>{
                'packageName': 'com.retroarch',
                'versionCode': 1234,
                'signingSha256': 'ccc333',
              },
              'not-a-map',
              <String, Object?>{'packageName': '', 'versionCode': 1},
            ];
          }
          return null;
        });

    final packages = await services.scanInstalled();
    expect(packages, const [
      InstalledPackage(
        packageName: 'org.dolphinemu.dolphinemu',
        versionCode: 24090,
        signingSha256: 'aaa111',
        signingSha256s: ['aaa111', 'bbb222'],
      ),
      InstalledPackage(
        packageName: 'com.retroarch',
        versionCode: 1234,
        signingSha256: 'ccc333',
      ),
    ]);
  });

  test('canRequestPackageInstalls and openInstallPermissionSettings', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (call) async {
          recordedCalls.add(call);
          if (call.method == 'canRequestPackageInstalls') {
            return true;
          }
          return null;
        });

    expect(await services.canRequestPackageInstalls(), isTrue);
    await services.openInstallPermissionSettings();

    expect(
      recordedCalls.map((c) => c.method),
      ['canRequestPackageInstalls', 'openInstallPermissionSettings'],
    );
  });

  test('installApkFile, confirmation controls, open, and uninstall', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (call) async {
          recordedCalls.add(call);
          switch (call.method) {
            case 'launchPendingConfirmation':
              return true;
            case 'openInstalled':
              return true;
            default:
              return null;
          }
        });

    await services.installApkFile(
      packageName: 'org.ppsspp.ppsspp',
      filePath: '/data/user/0/dev.anais.tshop/cache/ppsspp.apk',
    );
    final launched = await services.launchPendingConfirmation(
      packageName: 'org.ppsspp.ppsspp',
    );
    await services.cancelPendingConfirmation(
      packageName: 'org.ppsspp.ppsspp',
    );
    await services.openInstalled(packageName: 'org.ppsspp.ppsspp');
    await services.enqueueUninstall(packageName: 'org.ppsspp.ppsspp');

    expect(launched, isTrue);
    expect(recordedCalls.map((c) => c.method), [
      'installApkFile',
      'launchPendingConfirmation',
      'cancelPendingConfirmation',
      'openInstalled',
      'uninstallPackage',
    ]);
    expect(recordedCalls[0].arguments, {
      'packageName': 'org.ppsspp.ppsspp',
      'filePath': '/data/user/0/dev.anais.tshop/cache/ppsspp.apk',
    });
    expect(recordedCalls[1].arguments, {'packageName': 'org.ppsspp.ppsspp'});
    expect(recordedCalls[2].arguments, {'packageName': 'org.ppsspp.ppsspp'});
    expect(recordedCalls[3].arguments, {'packageName': 'org.ppsspp.ppsspp'});
    expect(recordedCalls[4].arguments, {'packageName': 'org.ppsspp.ppsspp'});
  });

  test('enqueueInstall accepts file URIs and rejects remote URIs', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (call) async {
          recordedCalls.add(call);
          return null;
        });

    await services.enqueueInstall(
      packageName: 'org.example.app',
      apk: Uri.file('/tmp/example.apk'),
    );
    expect(recordedCalls.single.method, 'installApkFile');
    expect(recordedCalls.single.arguments, {
      'packageName': 'org.example.app',
      'filePath': '/tmp/example.apk',
    });

    await expectLater(
      services.enqueueInstall(
        packageName: 'org.example.app',
        apk: Uri.parse('https://example.com/example.apk'),
      ),
      throwsA(isA<AppServiceUnsupported>()),
    );
  });

  test(
    'installEvents parses awaiting_confirmation, succeeded, and failed',
    () async {
      _registerPassthroughEventChannel(_installEventsMethodChannel);

      final received = <InstallEvent>[];
      final subscription = services.installEvents.listen(received.add);
      addTearDown(subscription.cancel);

      await _emitPlatformEvent(installEventsChannelName, <String, Object?>{
        'type': 'awaiting_confirmation',
        'packageName': 'org.dolphinemu.dolphinemu',
        'sessionId': 42,
      });
      await _emitPlatformEvent(installEventsChannelName, <String, Object?>{
        'type': 'succeeded',
        'packageName': 'org.dolphinemu.dolphinemu',
        'sessionId': 42,
      });
      await _emitPlatformEvent(installEventsChannelName, <String, Object?>{
        'type': 'failed',
        'packageName': 'com.retroarch',
        'sessionId': 43,
        'message': 'Install aborted by user',
        'aborted': true,
      });
      await _emitPlatformEvent(installEventsChannelName, <String, Object?>{
        'type': 'unknown_type',
        'packageName': 'ignored',
        'sessionId': 1,
      });
      await _emitPlatformEvent(installEventsChannelName, 'malformed');

      expect(received, const <InstallEvent>[
        InstallAwaitingConfirmation(
          packageName: 'org.dolphinemu.dolphinemu',
          sessionId: 42,
        ),
        InstallSucceeded(
          packageName: 'org.dolphinemu.dolphinemu',
          sessionId: 42,
        ),
        InstallFailed(
          packageName: 'com.retroarch',
          sessionId: 43,
          message: 'Install aborted by user',
          aborted: true,
        ),
      ]);
    },
  );

  test('gamepadHatEvents parses quantized events and clamps values', () async {
    _registerPassthroughEventChannel(_gamepadHatMethodChannel);

    final received = <GamepadHatEvent>[];
    final subscription = services.gamepadHatEvents.listen(received.add);
    addTearDown(subscription.cancel);

    await _emitPlatformEvent(gamepadHatChannelName, <String, Object?>{
      'x': -1,
      'y': 0,
    });
    await _emitPlatformEvent(gamepadHatChannelName, <String, Object?>{
      'x': 5,
      'y': -9,
    });
    await _emitPlatformEvent(gamepadHatChannelName, <String, Object?>{
      'x': 0,
      'y': 0,
    });
    await _emitPlatformEvent(gamepadHatChannelName, <String, Object?>{
      'x': 'bad',
    });

    expect(received, const <GamepadHatEvent>[
      GamepadHatEvent(x: -1, y: 0),
      GamepadHatEvent(x: 1, y: -1),
      GamepadHatEvent(x: 0, y: 0),
    ]);
  });
}

void _registerPassthroughEventChannel(MethodChannel channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'listen' || call.method == 'cancel') {
          return null;
        }
        return null;
      });
}

Future<void> _emitPlatformEvent(String channelName, Object? payload) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        channelName,
        _codec.encodeSuccessEnvelope(payload),
        (_) {},
      );
}
