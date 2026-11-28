import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/input/input_providers.dart';
import 'package:tshop/src/platform/app_services.dart';

void main() {
  group('GamepadActionMapper keyboard mapping', () {
    test('maps gamepad and desktop keyboard keys to GamepadAction', () {
      final mapper = GamepadActionMapper();
      addTearDown(mapper.dispose);

      expect(mapper.mapKey(LogicalKeyboardKey.arrowUp), GamepadAction.up);
      expect(mapper.mapKey(LogicalKeyboardKey.arrowDown), GamepadAction.down);
      expect(mapper.mapKey(LogicalKeyboardKey.arrowLeft), GamepadAction.left);
      expect(mapper.mapKey(LogicalKeyboardKey.arrowRight), GamepadAction.right);

      expect(
        mapper.mapKey(LogicalKeyboardKey.gameButtonA),
        GamepadAction.confirm,
      );
      expect(mapper.mapKey(LogicalKeyboardKey.enter), GamepadAction.confirm);
      expect(mapper.mapKey(LogicalKeyboardKey.space), GamepadAction.confirm);

      expect(mapper.mapKey(LogicalKeyboardKey.gameButtonB), GamepadAction.back);
      expect(mapper.mapKey(LogicalKeyboardKey.escape), GamepadAction.back);
      expect(mapper.mapKey(LogicalKeyboardKey.backspace), GamepadAction.back);

      expect(
        mapper.mapKey(LogicalKeyboardKey.gameButtonX),
        GamepadAction.secondary,
      );
      expect(mapper.mapKey(LogicalKeyboardKey.keyX), GamepadAction.secondary);

      expect(
        mapper.mapKey(LogicalKeyboardKey.gameButtonY),
        GamepadAction.searchOrRetry,
      );
      expect(
        mapper.mapKey(LogicalKeyboardKey.keyY),
        GamepadAction.searchOrRetry,
      );
      expect(
        mapper.mapKey(LogicalKeyboardKey.slash),
        GamepadAction.searchOrRetry,
      );

      expect(
        mapper.mapKey(LogicalKeyboardKey.gameButtonLeft1),
        GamepadAction.tabPrev,
      );
      expect(
        mapper.mapKey(LogicalKeyboardKey.bracketLeft),
        GamepadAction.tabPrev,
      );
      expect(mapper.mapKey(LogicalKeyboardKey.keyQ), GamepadAction.tabPrev);

      expect(
        mapper.mapKey(LogicalKeyboardKey.gameButtonRight1),
        GamepadAction.tabNext,
      );
      expect(
        mapper.mapKey(LogicalKeyboardKey.bracketRight),
        GamepadAction.tabNext,
      );
      expect(mapper.mapKey(LogicalKeyboardKey.keyE), GamepadAction.tabNext);

      expect(
        mapper.mapKey(LogicalKeyboardKey.gameButtonStart),
        GamepadAction.menu,
      );
      expect(mapper.mapKey(LogicalKeyboardKey.keyZ), isNull);
    });

    test('enforces 100 ms repeat cooldown for held D-pad directions', () {
      var now = DateTime.utc(2026, 11, 27, 12);
      final mapper = GamepadActionMapper(clock: () => now);
      addTearDown(mapper.dispose);

      // Initial press fires immediately.
      expect(
        mapper.handleKeyEvent(
          _down(PhysicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowRight),
        ),
        GamepadAction.right,
      );

      // Repeats before 100 ms are suppressed.
      now = now.add(const Duration(milliseconds: 40));
      expect(
        mapper.handleKeyEvent(
          _repeat(
            PhysicalKeyboardKey.arrowRight,
            LogicalKeyboardKey.arrowRight,
          ),
        ),
        isNull,
      );

      now = now.add(const Duration(milliseconds: 59));
      expect(
        mapper.handleKeyEvent(
          _repeat(
            PhysicalKeyboardKey.arrowRight,
            LogicalKeyboardKey.arrowRight,
          ),
        ),
        isNull,
      );

      // At exactly 100 ms since initial press, repeat fires.
      now = now.add(const Duration(milliseconds: 1));
      expect(
        mapper.handleKeyEvent(
          _repeat(
            PhysicalKeyboardKey.arrowRight,
            LogicalKeyboardKey.arrowRight,
          ),
        ),
        GamepadAction.right,
      );

      // Next repeat gated again until another 100 ms elapses.
      now = now.add(const Duration(milliseconds: 80));
      expect(
        mapper.handleKeyEvent(
          _repeat(
            PhysicalKeyboardKey.arrowRight,
            LogicalKeyboardKey.arrowRight,
          ),
        ),
        isNull,
      );

      now = now.add(const Duration(milliseconds: 20));
      expect(
        mapper.handleKeyEvent(
          _repeat(
            PhysicalKeyboardKey.arrowRight,
            LogicalKeyboardKey.arrowRight,
          ),
        ),
        GamepadAction.right,
      );
    });

    test('never repeats face or shoulder buttons while held', () {
      var now = DateTime.utc(2026, 11, 27, 12);
      final mapper = GamepadActionMapper(clock: () => now);
      addTearDown(mapper.dispose);

      final nonRepeating =
          <(PhysicalKeyboardKey, LogicalKeyboardKey, GamepadAction)>[
            (
              PhysicalKeyboardKey.enter,
              LogicalKeyboardKey.gameButtonA,
              GamepadAction.confirm,
            ),
            (
              PhysicalKeyboardKey.escape,
              LogicalKeyboardKey.gameButtonB,
              GamepadAction.back,
            ),
            (
              PhysicalKeyboardKey.keyX,
              LogicalKeyboardKey.gameButtonX,
              GamepadAction.secondary,
            ),
            (
              PhysicalKeyboardKey.keyY,
              LogicalKeyboardKey.gameButtonY,
              GamepadAction.searchOrRetry,
            ),
            (
              PhysicalKeyboardKey.keyQ,
              LogicalKeyboardKey.gameButtonLeft1,
              GamepadAction.tabPrev,
            ),
            (
              PhysicalKeyboardKey.keyE,
              LogicalKeyboardKey.gameButtonRight1,
              GamepadAction.tabNext,
            ),
            (
              PhysicalKeyboardKey.f1,
              LogicalKeyboardKey.gameButtonStart,
              GamepadAction.menu,
            ),
          ];

      for (final (physical, logical, expected) in nonRepeating) {
        expect(mapper.handleKeyEvent(_down(physical, logical)), expected);

        // Even well past 100 ms, repeats and duplicate KeyDowns are suppressed.
        now = now.add(const Duration(milliseconds: 500));
        expect(mapper.handleKeyEvent(_repeat(physical, logical)), isNull);
        expect(mapper.handleKeyEvent(_down(physical, logical)), isNull);

        // Releasing allows the next press to fire cleanly.
        expect(mapper.handleKeyEvent(_up(physical, logical)), isNull);
        expect(mapper.handleKeyEvent(_down(physical, logical)), expected);
        expect(mapper.handleKeyEvent(_up(physical, logical)), isNull);
      }
    });

    test(
      'AYN Thor shim tracks physical keys and ignores mismatched/stray key-ups',
      () {
        var now = DateTime.utc(2026, 11, 27, 12);
        final mapper = GamepadActionMapper(clock: () => now);
        addTearDown(mapper.dispose);

        // Stray KeyUpEvent for an unpressed key is ignored cleanly.
        final strayResult = mapper.processKeyEvent(
          _up(PhysicalKeyboardKey.keyA, LogicalKeyboardKey.keyA),
        );
        expect(strayResult, GamepadKeyResult.unhandled);
        expect(mapper.pressedPhysicalKeys, isEmpty);

        // Press A on physical key `enter` with logical `gameButtonA`.
        expect(
          mapper.handleKeyEvent(
            _down(PhysicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA),
          ),
          GamepadAction.confirm,
        );
        expect(mapper.pressedPhysicalKeys, {PhysicalKeyboardKey.enter});

        // Thor driver sends mismatched logical key on repeat: still suppressed
        // as non-repeating face button because physical key is tracked.
        now = now.add(const Duration(milliseconds: 250));
        final repeatResult = mapper.processKeyEvent(
          _repeat(PhysicalKeyboardKey.enter, LogicalKeyboardKey.keyZ),
        );
        expect(repeatResult, GamepadKeyResult.consumed);

        // Thor driver sends mismatched logical key on key-up: physical key is
        // still released properly.
        final upResult = mapper.processKeyEvent(
          _up(PhysicalKeyboardKey.enter, LogicalKeyboardKey.keyZ),
        );
        expect(upResult, GamepadKeyResult.consumed);
        expect(mapper.pressedPhysicalKeys, isEmpty);

        // Next press of A works again immediately.
        expect(
          mapper.handleKeyEvent(
            _down(PhysicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA),
          ),
          GamepadAction.confirm,
        );
      },
    );
  });

  group('GamepadActionMapper hat events', () {
    testWidgets(
      'translates hat events, repeats every 100 ms while held, and cancels '
      'on neutral',
      (tester) async {
        final mapper = GamepadActionMapper();
        addTearDown(mapper.dispose);

        final received = <GamepadAction>[];

        // Neutral emits nothing.
        mapper.handleHatEvent(
          const GamepadHatEvent(x: 0, y: 0),
          received.add,
        );
        expect(received, isEmpty);

        // Hold right: fires immediately, then every 100 ms.
        mapper.handleHatEvent(
          const GamepadHatEvent(x: 1, y: 0),
          received.add,
        );
        expect(received, [GamepadAction.right]);

        // Duplicate identical hat event while held does not double-fire.
        mapper.handleHatEvent(
          const GamepadHatEvent(x: 1, y: 0),
          received.add,
        );
        expect(received, [GamepadAction.right]);

        await tester.pump(const Duration(milliseconds: 99));
        expect(received, [GamepadAction.right]);

        await tester.pump(const Duration(milliseconds: 1));
        expect(received, [GamepadAction.right, GamepadAction.right]);

        await tester.pump(const Duration(milliseconds: 100));
        expect(received, [
          GamepadAction.right,
          GamepadAction.right,
          GamepadAction.right,
        ]);

        // Rolling direction to down fires immediately and replaces timer.
        mapper.handleHatEvent(
          const GamepadHatEvent(x: 0, y: 1),
          received.add,
        );
        expect(received.last, GamepadAction.down);

        await tester.pump(const Duration(milliseconds: 100));
        expect(received.sublist(3), [GamepadAction.down, GamepadAction.down]);

        // Returning to (0, 0) cancels repeat timer.
        mapper.handleHatEvent(
          const GamepadHatEvent(x: 0, y: 0),
          received.add,
        );
        final countAtNeutral = received.length;
        await tester.pump(const Duration(milliseconds: 500));
        expect(received.length, countAtNeutral);
      },
    );

    test('maps cardinal hat directions cleanly', () {
      final mapper = GamepadActionMapper();
      addTearDown(mapper.dispose);

      expect(mapper.mapHat(const GamepadHatEvent(x: 0, y: 0)), isNull);
      expect(
        mapper.mapHat(const GamepadHatEvent(x: -1, y: 0)),
        GamepadAction.left,
      );
      expect(
        mapper.mapHat(const GamepadHatEvent(x: 1, y: 0)),
        GamepadAction.right,
      );
      expect(
        mapper.mapHat(const GamepadHatEvent(x: 0, y: -1)),
        GamepadAction.up,
      );
      expect(
        mapper.mapHat(const GamepadHatEvent(x: 0, y: 1)),
        GamepadAction.down,
      );
    });
  });

  group('padButtonLayoutProvider', () {
    test('defaults to Nintendo and updates cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(padButtonLayoutProvider), PadButtonLayout.nintendo);

      container
          .read(padButtonLayoutProvider.notifier)
          .setLayout(PadButtonLayout.xbox);
      expect(container.read(padButtonLayoutProvider), PadButtonLayout.xbox);

      container.read(padButtonLayoutProvider.notifier).toggle();
      expect(container.read(padButtonLayoutProvider), PadButtonLayout.nintendo);
    });
  });
}

KeyDownEvent _down(PhysicalKeyboardKey physical, LogicalKeyboardKey logical) {
  return KeyDownEvent(
    physicalKey: physical,
    logicalKey: logical,
    timeStamp: Duration.zero,
  );
}

KeyRepeatEvent _repeat(
  PhysicalKeyboardKey physical,
  LogicalKeyboardKey logical,
) {
  return KeyRepeatEvent(
    physicalKey: physical,
    logicalKey: logical,
    timeStamp: Duration.zero,
  );
}

KeyUpEvent _up(PhysicalKeyboardKey physical, LogicalKeyboardKey logical) {
  return KeyUpEvent(
    physicalKey: physical,
    logicalKey: logical,
    timeStamp: Duration.zero,
  );
}
