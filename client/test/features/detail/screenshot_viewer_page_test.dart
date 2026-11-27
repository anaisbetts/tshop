import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/features/detail/detail_page.dart';
import 'package:tshop/src/features/detail/screenshot_viewer_page.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';

import 'test_helpers.dart';

void main() {
  group('ScreenshotViewerPage', () {
    testWidgets(
      'starts at initialIndex and updates counter and dots on button taps',
      (tester) async {
        final entry = buildWayfinderEntry();
        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}/screenshots/1',
        );

        expect(find.byType(ScreenshotViewerPage), findsOneWidget);
        expect(find.text('Wayfinder'), findsOneWidget);
        expect(find.text('2 / 4'), findsOneWidget);
        expect(_dotWidth(tester, 0), 7);
        expect(_dotWidth(tester, 1), 20);
        expect(_dotWidth(tester, 2), 7);

        // Tap Next [R] button -> 3 / 4.
        await tester.tap(find.bySemanticsLabel('Next screenshot'));
        await tester.pumpAndSettle();

        expect(find.text('3 / 4'), findsOneWidget);
        expect(_dotWidth(tester, 1), 7);
        expect(_dotWidth(tester, 2), 20);

        // Tap Next [R] again -> 4 / 4 (clamped at end).
        await tester.tap(find.bySemanticsLabel('Next screenshot'));
        await tester.pumpAndSettle();
        expect(find.text('4 / 4'), findsOneWidget);
        expect(_dotWidth(tester, 3), 20);

        // Tap Previous [L] button -> 3 / 4.
        await tester.tap(find.bySemanticsLabel('Previous screenshot'));
        await tester.pumpAndSettle();
        expect(find.text('3 / 4'), findsOneWidget);
        expect(_dotWidth(tester, 2), 20);
      },
    );

    testWidgets(
      'pages with gamepad [L]/[R] and Left/Right arrow keys',
      (tester) async {
        final entry = buildWayfinderEntry();
        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}/screenshots/0',
        );

        expect(find.text('1 / 4'), findsOneWidget);

        // Right arrow -> 2 / 4.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(find.text('2 / 4'), findsOneWidget);

        // [R] shoulder (bracketRight) -> 3 / 4.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.bracketRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.bracketRight);
        await tester.pumpAndSettle();
        expect(find.text('3 / 4'), findsOneWidget);
        expect(_dotWidth(tester, 2), 20);

        // [L] shoulder (bracketLeft) -> 2 / 4.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.bracketLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.bracketLeft);
        await tester.pumpAndSettle();
        expect(find.text('2 / 4'), findsOneWidget);

        // Left arrow -> 1 / 4; extra Left stays clamped at 1 / 4.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(find.text('1 / 4'), findsOneWidget);
        expect(_dotWidth(tester, 0), 20);
      },
    );

    testWidgets(
      '[B] pops back to DetailPage when pushed from detail',
      (tester) async {
        final entry = buildWayfinderEntry();
        final harness = await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
        );

        // Push viewer on top of DetailPage just like selecting a thumbnail.
        unawaited(
          harness.router.push('/app/${entry.packageName}/screenshots/2'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ScreenshotViewerPage), findsOneWidget);
        expect(find.text('3 / 4'), findsOneWidget);

        // Press [B] (Escape) -> pops back to DetailPage.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.byType(ScreenshotViewerPage), findsNothing);
        expect(find.byType(DetailPage), findsOneWidget);
      },
    );

    testWidgets(
      'tapping [B] Back legend hint pops back to DetailPage while Page stays '
      'non-interactive',
      (tester) async {
        final entry = buildWayfinderEntry();
        final harness = await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
        );

        unawaited(
          harness.router.push('/app/${entry.packageName}/screenshots/0'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ScreenshotViewerPage), findsOneWidget);

        final pageHint = tester.widget<TshopLegendHint>(
          find.ancestor(
            of: find.text('Page'),
            matching: find.byType(TshopLegendHint),
          ),
        );
        expect(pageHint.item.onTap, isNull);

        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        expect(find.byType(ScreenshotViewerPage), findsNothing);
        expect(find.byType(DetailPage), findsOneWidget);
      },
    );
  });
}

double _dotWidth(WidgetTester tester, int index) {
  final finder = find.byKey(ValueKey<String>('viewer-dot-$index'));
  return tester.getSize(finder).width;
}
