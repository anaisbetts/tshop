import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/input/gamepad_scope.dart';
import 'package:tshop/src/platform/app_services.dart';

void main() {
  group('TshopGamepadScope', () {
    testWidgets(
      'delivers keyboard and gamepadHatEvents actions to onAction',
      (tester) async {
        final hatController = StreamController<GamepadHatEvent>.broadcast();
        addTearDown(hatController.close);

        final fakeServices = _FakeHatAppServices(hatController.stream);
        final received = <GamepadAction>[];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(fakeServices),
            ],
            child: MaterialApp(
              home: TshopGamepadScope(
                onAction: received.add,
                child: const Scaffold(body: Text('Storefront')),
              ),
            ),
          ),
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.bracketRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.bracketRight);

        expect(received, [
          GamepadAction.right,
          GamepadAction.confirm,
          GamepadAction.tabNext,
        ]);

        // Emit a held hat event and verify initial + 100 ms repeat + neutral.
        hatController.add(const GamepadHatEvent(x: 0, y: 1));
        await tester.pump();
        expect(received.last, GamepadAction.down);

        await tester.pump(const Duration(milliseconds: 100));
        expect(received.sublist(3), [GamepadAction.down, GamepadAction.down]);

        hatController.add(const GamepadHatEvent(x: 0, y: 0));
        await tester.pump(const Duration(milliseconds: 300));
        expect(received.length, 5);
      },
    );

    testWidgets(
      'pauses keyboard and hat interception when enabled is false',
      (tester) async {
        final hatController = StreamController<GamepadHatEvent>.broadcast();
        addTearDown(hatController.close);

        final fakeServices = _FakeHatAppServices(hatController.stream);
        final received = <GamepadAction>[];

        Widget buildScope({required bool enabled}) {
          return ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(fakeServices),
            ],
            child: MaterialApp(
              home: TshopGamepadScope(
                enabled: enabled,
                onAction: received.add,
                child: const Scaffold(body: Text('Storefront')),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildScope(enabled: true));

        // Starts enabled.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        expect(received, [GamepadAction.down]);

        // Disable scope (for example while search modal is open).
        await tester.pumpWidget(buildScope(enabled: false));

        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        hatController.add(const GamepadHatEvent(x: -1, y: 0));
        await tester.pump(const Duration(milliseconds: 200));
        hatController.add(const GamepadHatEvent(x: 0, y: 0));
        await tester.pump();

        expect(received, [GamepadAction.down]);

        // Re-enable scope and confirm events flow again.
        await tester.pumpWidget(buildScope(enabled: true));

        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
        expect(received, [GamepadAction.down, GamepadAction.back]);
      },
    );

    testWidgets(
      'does not intercept keys while a TextField holds primary focus',
      (tester) async {
        final hatController = StreamController<GamepadHatEvent>.broadcast();
        addTearDown(hatController.close);

        final fakeServices = _FakeHatAppServices(hatController.stream);
        final received = <GamepadAction>[];
        final textController = TextEditingController();
        addTearDown(textController.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(fakeServices),
            ],
            child: MaterialApp(
              home: TshopGamepadScope(
                onAction: received.add,
                child: Scaffold(
                  body: TextField(controller: textController),
                ),
              ),
            ),
          ),
        );

        // Focus the TextField.
        await tester.tap(find.byType(TextField));
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyX);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);

        expect(received, isEmpty);
      },
    );
  });
}

final class _FakeHatAppServices implements AppServices {
  _FakeHatAppServices(this._hatStream)
    : _delegate = StubAppServices(talker: Talker());

  final Stream<GamepadHatEvent> _hatStream;
  final StubAppServices _delegate;

  @override
  bool get canInstall => _delegate.canInstall;

  @override
  Future<DeviceInfo> deviceInfo() => _delegate.deviceInfo();

  @override
  Future<List<InstalledPackage>> scanInstalled() => _delegate.scanInstalled();

  @override
  Future<Set<String>> metCapabilities() => _delegate.metCapabilities();

  @override
  Future<bool> canRequestPackageInstalls() =>
      _delegate.canRequestPackageInstalls();

  @override
  Future<void> installApkFile({
    required String packageName,
    required String filePath,
  }) => _delegate.installApkFile(packageName: packageName, filePath: filePath);

  @override
  Future<bool> launchPendingConfirmation({required String packageName}) =>
      _delegate.launchPendingConfirmation(packageName: packageName);

  @override
  Future<void> cancelPendingConfirmation({required String packageName}) =>
      _delegate.cancelPendingConfirmation(packageName: packageName);

  @override
  Stream<InstallEvent> get installEvents => _delegate.installEvents;

  @override
  Stream<GamepadHatEvent> get gamepadHatEvents => _hatStream;

  @override
  Future<void> enqueueInstall({
    required String packageName,
    required Uri apk,
  }) => _delegate.enqueueInstall(packageName: packageName, apk: apk);

  @override
  Future<void> enqueueUninstall({required String packageName}) =>
      _delegate.enqueueUninstall(packageName: packageName);

  @override
  Future<void> openInstalled({required String packageName}) =>
      _delegate.openInstalled(packageName: packageName);

  @override
  Future<void> notifyUpdates({required int count}) =>
      _delegate.notifyUpdates(count: count);

  @override
  Future<void> openInstallPermissionSettings() =>
      _delegate.openInstallPermissionSettings();

  @override
  Future<void> requestNotificationPermission() =>
      _delegate.requestNotificationPermission();
}
