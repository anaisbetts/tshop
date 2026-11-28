import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/theme/tshop_theme.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';

void main() {
  group('visualPadButton', () {
    test('Nintendo layout swaps A/B and X/Y to match the Thor', () {
      expect(
        visualPadButton(PadButton.a, PadButtonLayout.nintendo),
        PadButton.b,
      );
      expect(
        visualPadButton(PadButton.b, PadButtonLayout.nintendo),
        PadButton.a,
      );
      expect(
        visualPadButton(PadButton.x, PadButtonLayout.nintendo),
        PadButton.y,
      );
      expect(
        visualPadButton(PadButton.y, PadButtonLayout.nintendo),
        PadButton.x,
      );
      expect(
        visualPadButton(PadButton.l, PadButtonLayout.nintendo),
        PadButton.l,
      );
    });

    test('Xbox layout keeps semantic letters', () {
      expect(visualPadButton(PadButton.a, PadButtonLayout.xbox), PadButton.a);
      expect(visualPadButton(PadButton.b, PadButtonLayout.xbox), PadButton.b);
      expect(visualPadButton(PadButton.x, PadButtonLayout.xbox), PadButton.x);
      expect(visualPadButton(PadButton.y, PadButtonLayout.xbox), PadButton.y);
    });
  });

  group('PadGlyph', () {
    testWidgets('defaults to Nintendo letters: B confirms, A cancels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Row(
            children: [
              PadGlyph(PadButton.a),
              PadGlyph(PadButton.b),
              PadGlyph(PadButton.x),
              PadGlyph(PadButton.y),
            ],
          ),
        ),
      );

      expect(find.text('B'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);
      expect(find.text('X'), findsOneWidget);
      expect(_glyphColor(tester, 'B'), TshopBrand.padB);
      expect(_glyphColor(tester, 'A'), TshopBrand.padA);
      expect(_glyphColor(tester, 'X'), TshopBrand.padX);
      expect(_glyphColor(tester, 'Y'), TshopBrand.padY);
    });

    testWidgets('Xbox scope restores A/B/X/Y letters', (tester) async {
      await tester.pumpWidget(
        _host(
          const PadLayoutScope(
            layout: PadButtonLayout.xbox,
            child: Row(
              children: [
                PadGlyph(PadButton.a),
                PadGlyph(PadButton.b),
                PadGlyph(PadButton.x),
                PadGlyph(PadButton.y),
              ],
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('X'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);
    });
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: buildTshopTheme(Brightness.light),
    home: Scaffold(body: child),
  );
}

Color _glyphColor(WidgetTester tester, String letter) {
  final glyph = find.ancestor(
    of: find.text(letter),
    matching: find.byType(PadGlyph),
  );
  final container = tester.widget<Container>(
    find.descendant(of: glyph, matching: find.byType(Container)).first,
  );
  return (container.decoration! as BoxDecoration).color!;
}
