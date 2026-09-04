import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ime_shape/controller_page.dart';
import 'package:ime_shape/ime_page.dart';
import 'package:ime_shape/main.dart';

void main() {
  test('grid stays visible above the minimum leftover height', () {
    expect(gridRemainsVisible(remainingHeight: 200, minVisible: 80), isTrue);
    expect(gridRemainsVisible(remainingHeight: 20, minVisible: 80), isFalse);
  });

  test('keyKind names down, repeat, and up', () {
    expect(
      keyKind(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      ),
      'down',
    );
    expect(
      keyKind(
        const KeyRepeatEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      ),
      'repeat',
    );
    expect(
      keyKind(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      ),
      'up',
    );
  });

  test('RepeatWatch counts repeats after the first down', () {
    var watch = RepeatWatch.empty.observe(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.gameButtonA,
        logicalKey: LogicalKeyboardKey.gameButtonA,
        timeStamp: Duration.zero,
      ),
    );
    expect(watch.repeats, 0);
    watch = watch.observe(
      const KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.gameButtonA,
        logicalKey: LogicalKeyboardKey.gameButtonA,
        timeStamp: Duration.zero,
      ),
    );
    expect(watch.repeats, 1);
  });

  testWidgets('home opens both prototype pages', (tester) async {
    await tester.pumpWidget(const ProtoApp());
    expect(find.text('Controller input'), findsOneWidget);
    expect(find.text('Widget focus'), findsOneWidget);
    expect(find.text('IME shape'), findsOneWidget);

    await tester.tap(find.text('IME shape'));
    await tester.pumpAndSettle();
    expect(find.text('#12 IME shape'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Controller input'));
    await tester.pumpAndSettle();
    expect(find.text('#2 Controller input'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Widget focus'));
    await tester.pumpAndSettle();
    expect(find.text('Focus kitchen'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
  });
}
