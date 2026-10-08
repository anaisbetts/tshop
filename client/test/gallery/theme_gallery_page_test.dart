import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshop/src/gallery/theme_gallery_page.dart';
import 'package:tshop/src/theme/tshop_theme.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_chip.dart';
import 'package:tshop/src/theme/widgets/tshop_settings.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';
import 'package:tshop/src/theme/widgets/tshop_wallpaper.dart';

void main() {
  testWidgets('gallery renders every section in Day and Night', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTshopTheme(Brightness.light),
        home: const ThemeGalleryPage(),
      ),
    );
    await tester.pump();

    expect(find.text('BROWSE ON THOR (837 × 471)'), findsOneWidget);
    expect(find.byType(TshopTile), findsWidgets);
    expect(tester.getSize(find.byType(TshopChip).first).width, lessThan(400));
    expect(tester.getSize(find.byType(PadGlyph).at(4)).width, lessThan(40));
    expect(tester.takeException(), isNull);
    expect(_tokensOf(tester).brightness, Brightness.light);

    await tester.tap(find.text('Night'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_tokensOf(tester).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings switch toggles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTshopTheme(Brightness.light),
        home: Scaffold(body: _SwitchHarness()),
      ),
    );

    TshopSwitch switchWidget() => tester.widget(find.byType(TshopSwitch));
    expect(switchWidget().value, isFalse);
    await tester.tap(find.byType(TshopSwitch));
    await tester.pump();
    expect(switchWidget().value, isTrue);
  });
}

TshopTokens _tokensOf(WidgetTester tester) {
  final context = tester.element(find.byType(TshopWallpaper).first);
  return context.tshop;
}

class _SwitchHarness extends StatefulWidget {
  @override
  State<_SwitchHarness> createState() => _SwitchHarnessState();
}

class _SwitchHarnessState extends State<_SwitchHarness> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    return TshopSwitch(
      value: _value,
      onChanged: (value) => setState(() => _value = value),
    );
  }
}
