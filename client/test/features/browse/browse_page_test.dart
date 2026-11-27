import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/features/browse/browse_catalog_helpers.dart';
import 'package:tshop/src/features/browse/browse_page.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/platform/app_services.dart';
import 'package:tshop/src/theme/tshop_theme.dart';
import 'package:tshop/src/theme/widgets/tshop_chip.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';
import 'package:tshop/src/theme/widgets/tshop_surfaces.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';

const Size _thorSize = Size(837, 471);
const Size _squareSize = Size(592, 516);
const String _testServerUrl = 'http://127.0.0.1:8787';

void main() {
  group('BrowsePage', () {
    testWidgets(
      'renders Wayfinder in Utilities shelf and updates Info Strip on D-pad '
      'navigation',
      (tester) async {
        _setViewport(tester, _thorSize);
        final catalog = _buildSampleCatalog();
        final catalogNotifier = _FakeCatalogNotifier(
          AsyncData<CatalogState>(_catalogState(catalog)),
        );

        await _pumpBrowseApp(
          tester,
          catalogNotifier: catalogNotifier,
          installedPackages: const <String, InstalledPackage>{
            'org.dolphinemu.dolphinemu': InstalledPackage(
              packageName: 'org.dolphinemu.dolphinemu',
              versionCode: 2509,
              signingSha256: 'cert-dolphin',
            ),
            'org.ppsspp.ppsspp': InstalledPackage(
              packageName: 'org.ppsspp.ppsspp',
              versionCode: 1171,
              signingSha256: 'cert-ppsspp',
            ),
          },
        );

        // Both category frames render with counts.
        expect(find.text('Emulators'), findsWidgets);
        expect(find.text('Utilities'), findsOneWidget);

        // Wayfinder tile renders inside Utilities shelf.
        final utilitiesFrame = find.ancestor(
          of: find.text('Utilities'),
          matching: find.byType(TshopFrame),
        );
        expect(utilitiesFrame, findsOneWidget);
        expect(
          find.descendant(
            of: utilitiesFrame,
            matching: find.bySemanticsLabel('Wayfinder'),
          ),
          findsOneWidget,
        );

        // Initial focus is on the first tile (Dolphin) with Installed chip.
        expect(_infoStrip(tester).title, 'Dolphin');
        expect(
          _infoStrip(tester).summary,
          'GameCube and Wii games in HD, with netplay and save states.',
        );
        expect(find.text('Installed'), findsOneWidget);

        // Move down to PPSSPP (update available with version arrow).
        await _pressKey(tester, LogicalKeyboardKey.arrowDown);
        expect(_infoStrip(tester).title, 'PPSSPP');
        expect(find.text('Update 1.17.1 → 1.18.1'), findsOneWidget);

        // Move right into Utilities shelf -> focuses Wayfinder.
        await _pressKey(tester, LogicalKeyboardKey.arrowRight);
        expect(_infoStrip(tester).title, 'Wayfinder');
        expect(
          _infoStrip(tester).summary,
          'Dual-screen handheld launcher for AYN Thor.',
        );
        expect(find.text('8.0 MB'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'search filters shelves, shows empty state for 0 matches, and clear '
      'restores catalog',
      (tester) async {
        _setViewport(tester, _thorSize);
        final catalog = _buildSampleCatalog();
        final catalogNotifier = _FakeCatalogNotifier(
          AsyncData<CatalogState>(_catalogState(catalog)),
        );

        await _pumpBrowseApp(tester, catalogNotifier: catalogNotifier);

        // Press Y to open search modal.
        await _pressKey(tester, LogicalKeyboardKey.keyY);
        expect(
          find.byKey(const ValueKey<String>('browse-search-input')),
          findsOneWidget,
        );

        // Escape cancels without changing shelves.
        await _pressKey(tester, LogicalKeyboardKey.escape);
        expect(
          find.byKey(const ValueKey<String>('browse-search-input')),
          findsNothing,
        );
        expect(find.byType(TshopFrame), findsNWidgets(2));

        // Tap search pill to open search modal and commit matching query.
        await tester.tap(
          find.byKey(const ValueKey<String>('browse-search-pill')),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey<String>('browse-search-input')),
          'wayfinder',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();

        // Only Utilities shelf remains, with Wayfinder focused.
        expect(find.byType(TshopFrame), findsOneWidget);
        expect(_infoStrip(tester).title, 'Wayfinder');
        expect(find.text('wayfinder'), findsOneWidget);
        expect(find.text('Clear search'), findsOneWidget);

        // Press X to clear active search -> restores both shelves and preserves
        // focus on Wayfinder since it remains in the catalog.
        await _pressKey(tester, LogicalKeyboardKey.keyX);
        expect(find.byType(TshopFrame), findsNWidgets(2));
        expect(_infoStrip(tester).title, 'Wayfinder');

        // Enter non-matching query -> shows empty ghost-tile message.
        await _pressKey(tester, LogicalKeyboardKey.keyY);
        await tester.enterText(
          find.byKey(const ValueKey<String>('browse-search-input')),
          'zzz-does-not-exist',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();

        expect(find.text('Nothing in the catalog matches.'), findsOneWidget);
        expect(find.byType(TshopFrame), findsNothing);

        // Tapping active search pill clears search and restores shelves +
        // first-tile focus.
        await tester.tap(
          find.byKey(const ValueKey<String>('browse-search-pill')),
        );
        await tester.pump();

        expect(find.text('Nothing in the catalog matches.'), findsNothing);
        expect(find.byType(TshopFrame), findsNWidgets(2));
        expect(_infoStrip(tester).title, 'Dolphin');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'offline with cached catalog shows offline Wi-Fi glyph while keeping '
      'shelves interactive',
      (tester) async {
        _setViewport(tester, _thorSize);
        final catalog = _buildSampleCatalog();
        final catalogNotifier = _FakeCatalogNotifier(
          AsyncData<CatalogState>(_catalogState(catalog, isOffline: true)),
        );

        await _pumpBrowseApp(tester, catalogNotifier: catalogNotifier);

        final wifi = tester.widget<TshopWifiGlyph>(find.byType(TshopWifiGlyph));
        expect(wifi.online, isFalse);
        expect(find.bySemanticsLabel('Offline'), findsOneWidget);

        // Shelves remain interactive via D-pad.
        expect(_infoStrip(tester).title, 'Dolphin');
        await _pressKey(tester, LogicalKeyboardKey.arrowDown);
        expect(_infoStrip(tester).title, 'PPSSPP');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'offline without catalog shows retry state and triggers refresh on tap '
      'or button press',
      (tester) async {
        _setViewport(tester, _thorSize);
        final catalogNotifier = _FakeCatalogNotifier(
          AsyncError<CatalogState>(
            Exception('Connection refused'),
            StackTrace.current,
          ),
        );

        await _pumpBrowseApp(tester, catalogNotifier: catalogNotifier);

        expect(find.text("Can't reach the catalog server."), findsOneWidget);
        expect(find.text(_testServerUrl), findsOneWidget);
        expect(find.text('Retry'), findsWidgets);

        final wifi = tester.widget<TshopWifiGlyph>(find.byType(TshopWifiGlyph));
        expect(wifi.online, isFalse);

        // Tap Retry button.
        await tester.tap(find.text('Retry').first);
        await tester.pump();
        expect(catalogNotifier.refreshCallCount(), 1);

        // Press Y (searchOrRetry) -> triggers refresh.
        await _pressKey(tester, LogicalKeyboardKey.keyY);
        expect(catalogNotifier.refreshCallCount(), 2);

        // Press A (confirm) -> triggers refresh.
        await _pressKey(tester, LogicalKeyboardKey.enter);
        expect(catalogNotifier.refreshCallCount(), 3);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows TshopDownloadsPill when a task is downloading and navigates to '
      '/library on tap',
      (tester) async {
        _setViewport(tester, _thorSize);
        final catalog = _buildSampleCatalog();
        final wayfinder = catalog.entryByPackageName('app.wayfinder')!;
        final ppsspp = catalog.entryByPackageName('org.ppsspp.ppsspp')!;

        final queueState = InstallQueueState(
          tasks: <String, InstallTask>{
            wayfinder.packageName: InstallTask(
              packageName: wayfinder.packageName,
              appName: 'Wayfinder',
              variant: wayfinder.release!.variants.first,
              intent: installIntentInstall,
              stage: InstallTaskStage.downloading,
              progress: 0.62,
              bytesReceived: 5200000,
              totalBytes: 8400000,
            ),
            ppsspp.packageName: InstallTask(
              packageName: ppsspp.packageName,
              appName: 'PPSSPP',
              variant: ppsspp.release!.variants.first,
              intent: installIntentUpdate,
              stage: InstallTaskStage.awaitingConfirm,
              progress: 1,
            ),
          },
          order: <String>[wayfinder.packageName, ppsspp.packageName],
        );

        final router = await _pumpBrowseApp(
          tester,
          catalogNotifier: _FakeCatalogNotifier(
            AsyncData<CatalogState>(_catalogState(catalog)),
          ),
          installQueueState: queueState,
        );

        expect(find.byType(TshopDownloadsPill), findsOneWidget);
        expect(find.text('Wayfinder 62%'), findsOneWidget);
        expect(find.text('+1 · Library'), findsOneWidget);

        await tester.tap(find.byType(TshopDownloadsPill));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(router.state.uri.toString(), '/library');
        expect(find.text('Route: /library'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping or pressing A on Wayfinder navigates to /app/app.wayfinder',
      (tester) async {
        _setViewport(tester, _thorSize);
        final catalog = _buildSampleCatalog();
        final router = await _pumpBrowseApp(
          tester,
          catalogNotifier: _FakeCatalogNotifier(
            AsyncData<CatalogState>(_catalogState(catalog)),
          ),
        );

        // Tap Wayfinder directly -> pushes /app/app.wayfinder.
        await tester.tap(find.bySemanticsLabel('Wayfinder'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(router.state.uri.toString(), '/app/app.wayfinder');
        expect(find.text('Detail: app.wayfinder'), findsOneWidget);

        // Pop back to Browse; Wayfinder remains focused, pressing A re-opens.
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(router.state.uri.toString(), '/');
        expect(_infoStrip(tester).title, 'Wayfinder');

        await _pressKey(tester, LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 50));

        expect(router.state.uri.toString(), '/app/app.wayfinder');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'supports L/R shoulder buttons and tab taps for route switching',
      (tester) async {
        _setViewport(tester, _thorSize);
        final catalog = _buildSampleCatalog();
        final router = await _pumpBrowseApp(
          tester,
          catalogNotifier: _FakeCatalogNotifier(
            AsyncData<CatalogState>(_catalogState(catalog)),
          ),
        );

        // R switches Browse -> /library.
        await _pressKey(tester, LogicalKeyboardKey.bracketRight);
        await tester.pump(const Duration(milliseconds: 50));
        expect(router.state.uri.toString(), '/library');

        // Go back to Browse, then L switches Browse -> /settings.
        router.go('/');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _pressKey(tester, LogicalKeyboardKey.bracketLeft);
        await tester.pump(const Duration(milliseconds: 400));
        expect(router.state.uri.toString(), '/settings');

        // Return to Browse and tap Settings tab directly.
        router.go('/');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Settings'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(router.state.uri.toString(), '/settings');

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'uses 4-row layout and omits category chip on compact square screens',
      (tester) async {
        _setViewport(tester, _squareSize);
        final catalog = _buildSampleCatalog();
        await _pumpBrowseApp(
          tester,
          catalogNotifier: _FakeCatalogNotifier(
            AsyncData<CatalogState>(_catalogState(catalog)),
          ),
          installedPackages: const <String, InstalledPackage>{
            'org.dolphinemu.dolphinemu': InstalledPackage(
              packageName: 'org.dolphinemu.dolphinemu',
              versionCode: 2509,
              signingSha256: 'cert-dolphin',
            ),
          },
        );

        final firstFrame = tester.widget<TshopFrame>(
          find.byType(TshopFrame).first,
        );
        expect(firstFrame.rows, 4);

        final strip = _infoStrip(tester);
        expect(strip.chips.length, 1);
        expect(strip.chips.single.label, 'Installed');
        expect(strip.chips.single.tone, TshopChipTone.good);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping actionable footer legend items opens focused app, clears '
      'search, and retries offline catalog while Move stays non-interactive',
      (tester) async {
        _setViewport(tester, _thorSize);
        final catalog = _buildSampleCatalog();
        final router = await _pumpBrowseApp(
          tester,
          catalogNotifier: _FakeCatalogNotifier(
            AsyncData<CatalogState>(_catalogState(catalog)),
          ),
        );

        final legendFinder = find.byType(TshopLegend);
        final moveHint = tester.widget<TshopLegendHint>(
          find.ancestor(
            of: find.text('Move'),
            matching: find.byType(TshopLegendHint),
          ),
        );
        expect(moveHint.item.onTap, isNull);

        // Tap [A] Open in the footer legend -> opens focused app (Dolphin).
        await tester.tap(
          find.descendant(of: legendFinder, matching: find.text('Open')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(router.state.uri.toString(), '/app/org.dolphinemu.dolphinemu');

        // Return to Browse, filter via search, then tap [X] Clear search in
        // the footer legend to restore both shelves.
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await _pressKey(tester, LogicalKeyboardKey.keyY);
        await tester.enterText(
          find.byKey(const ValueKey<String>('browse-search-input')),
          'wayfinder',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(find.byType(TshopFrame), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: legendFinder,
            matching: find.text('Clear search'),
          ),
        );
        await tester.pump();
        expect(find.byType(TshopFrame), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping [Y] Retry in offline empty footer legend triggers refresh',
      (tester) async {
        _setViewport(tester, _thorSize);
        final offlineNotifier = _FakeCatalogNotifier(
          AsyncError<CatalogState>(
            Exception('Connection refused'),
            StackTrace.current,
          ),
        );
        await _pumpBrowseApp(tester, catalogNotifier: offlineNotifier);
        await tester.tap(
          find.descendant(
            of: find.byType(TshopLegend),
            matching: find.text('Retry'),
          ),
        );
        await tester.pump();
        expect(offlineNotifier.refreshCallCount(), 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shelf header clears focused tile ring at both Thor and square viewports',
      (tester) async {
        for (final size in <Size>[_thorSize, _squareSize]) {
          _setViewport(tester, size);
          final catalog = _buildSampleCatalog();
          await _pumpBrowseApp(
            tester,
            catalogNotifier: _FakeCatalogNotifier(
              AsyncData<CatalogState>(_catalogState(catalog)),
            ),
          );

          final utilitiesFrame = find.ancestor(
            of: find.text('Utilities'),
            matching: find.byType(TshopFrame),
          );
          final headingRect = tester.getRect(
            find.descendant(
              of: utilitiesFrame,
              matching: find.text('Utilities'),
            ),
          );
          final tileRect = tester.getRect(
            find.descendant(
              of: utilitiesFrame,
              matching: find.byType(TshopTile),
            ),
          );
          // Focused tile ring protrudes ~11.2 dp above the unscaled tile edge.
          expect(tileRect.top - headingRect.bottom, greaterThanOrEqualTo(12));
          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  group('browse_catalog_helpers', () {
    test('parses valid and malformed backdrop hex colors safely', () {
      expect(parseHexColor('#ff7a1a'), const Color(0xFFFF7A1A));
      expect(parseHexColor('#0f0'), const Color(0xFF00FF00));
      expect(parseHexColor('80112233'), const Color(0x80112233));
      expect(parseHexColor('not-a-color'), isNull);

      final singleStop = parseTileBackdrop(
        CatalogTile(
          iconUrl: '',
          backdropColors: const <String>['#123456'],
          backdropAngle: 160,
          iconScale: 1,
        ),
      );
      expect(singleStop.colors, const <Color>[
        Color(0xFF123456),
        Color(0xFF123456),
      ]);

      final fallback = parseTileBackdrop(
        CatalogTile(
          iconUrl: '',
          backdropColors: const <String>['bad'],
          backdropAngle: 90,
          iconScale: 1,
        ),
      );
      expect(fallback.colors.length, 2);
    });

    test('maps every AppCatalogStatus to a TileStatus', () {
      for (final status in AppCatalogStatus.values) {
        expect(tileStatusForCatalogStatus(status), isA<TileStatus>());
      }
      expect(
        tileStatusForCatalogStatus(AppCatalogStatus.updateAvailable),
        TileStatus.update,
      );
      expect(
        tileStatusForCatalogStatus(AppCatalogStatus.awaitingConfirm),
        TileStatus.confirm,
      );
      expect(
        tileStatusForCatalogStatus(AppCatalogStatus.otherSource),
        TileStatus.otherSource,
      );
    });

    test(
      'builds info chips for unmet, landing, otherSource, confirm, failed',
      () {
        final catalog = _buildSampleCatalog();
        final wayfinder = catalog.entryByPackageName('app.wayfinder')!;

        final unmetChips = buildBrowseInfoChips(
          ResolvedAppState(
            entry: wayfinder,
            status: AppCatalogStatus.available,
            installedPackage: null,
            activeTask: null,
            selectedVariant: wayfinder.release!.variants.first,
            unmetCapabilities: const <String>['vulkan-1.1'],
          ),
          catalog,
          compact: false,
        );
        expect(unmetChips.last.label, 'Needs Vulkan 1.1 GPU driver');
        expect(unmetChips.last.tone, TshopChipTone.bad);

        final otherSourceChips = buildBrowseInfoChips(
          ResolvedAppState(
            entry: wayfinder,
            status: AppCatalogStatus.otherSource,
            installedPackage: const InstalledPackage(
              packageName: 'app.wayfinder',
              versionCode: 42,
              signingSha256: 'other-cert',
            ),
            activeTask: null,
            selectedVariant: wayfinder.release!.variants.first,
            unmetCapabilities: const <String>[],
          ),
          catalog,
          compact: false,
        );
        expect(otherSourceChips.last.label, 'Other source');

        final landingChips = buildBrowseInfoChips(
          ResolvedAppState(
            entry: wayfinder,
            status: AppCatalogStatus.landing,
            installedPackage: null,
            activeTask: null,
            selectedVariant: null,
            unmetCapabilities: const <String>[],
          ),
          catalog,
          compact: false,
        );
        expect(landingChips.last.label, 'From the publisher');

        final confirmChips = buildBrowseInfoChips(
          ResolvedAppState(
            entry: wayfinder,
            status: AppCatalogStatus.awaitingConfirm,
            installedPackage: null,
            activeTask: InstallTask(
              packageName: wayfinder.packageName,
              appName: 'Wayfinder',
              variant: wayfinder.release!.variants.first,
              intent: installIntentInstall,
              stage: InstallTaskStage.awaitingConfirm,
              progress: 1,
            ),
            selectedVariant: wayfinder.release!.variants.first,
            unmetCapabilities: const <String>[],
          ),
          catalog,
          compact: false,
        );
        expect(confirmChips.last.label, 'Confirm in Library');
        expect(confirmChips.last.tone, TshopChipTone.good);

        final failedState = ResolvedAppState(
          entry: wayfinder,
          status: AppCatalogStatus.failed,
          installedPackage: null,
          activeTask: InstallTask(
            packageName: wayfinder.packageName,
            appName: 'Wayfinder',
            variant: wayfinder.release!.variants.first,
            intent: installIntentInstall,
            stage: InstallTaskStage.failed,
            errorMessage: 'Publisher host unreachable.',
          ),
          selectedVariant: wayfinder.release!.variants.first,
          unmetCapabilities: const <String>[],
        );
        final failedChips = buildBrowseInfoChips(
          failedState,
          catalog,
          compact: false,
        );
        expect(failedChips.last.label, 'Install failed');
        expect(failedChips.last.tone, TshopChipTone.bad);
        expect(
          buildBrowseInfoSummary(failedState),
          'Publisher host unreachable.',
        );
      },
    );
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}

TshopInfoStrip _infoStrip(WidgetTester tester) {
  return tester.widget<TshopInfoStrip>(find.byType(TshopInfoStrip));
}

Future<GoRouter> _pumpBrowseApp(
  WidgetTester tester, {
  required _FakeCatalogNotifier catalogNotifier,
  Map<String, InstalledPackage> installedPackages =
      const <String, InstalledPackage>{},
  InstallQueueState? installQueueState,
  Set<String> metCapabilities = const <String>{},
}) async {
  final services = _FakeAppServices(
    installed: installedPackages.values.toList(),
    capabilities: metCapabilities,
  );
  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const BrowsePage(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Route: /library'))),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Route: /settings'))),
      ),
      GoRoute(
        path: '/app/:packageName',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('Detail: ${state.pathParameters['packageName']}'),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        tshopConfigProvider.overrideWithValue(
          TshopConfig(catalogBaseUrl: Uri.parse(_testServerUrl)),
        ),
        appServicesProvider.overrideWithValue(services),
        catalogProvider.overrideWith(() => catalogNotifier),
        installedPackagesProvider.overrideWith(
          () => _FakeInstalledPackagesNotifier(installedPackages),
        ),
        installQueueProvider.overrideWith(
          () => _FakeInstallQueueNotifier(
            installQueueState ?? InstallQueueState(),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: buildTshopTheme(Brightness.light),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return router;
}

CatalogState _catalogState(
  CatalogDocument catalog, {
  bool isOffline = false,
}) {
  return CatalogState(
    catalog: catalog,
    pointer: CatalogPointer(
      schemaVersion: 1,
      minClientVersionCode: 1,
      generatedAt: DateTime.utc(2026, 11, 27),
      generatedAtRaw: '2026-11-27T00:00:00Z',
      keyId: 'test-key',
      catalogUrl: '/catalog/test.json',
      catalogSha256: 'a' * 64,
      catalogSize: 1024,
      statsUrl: 'https://stats.tshop.example',
      signature: 'sig',
    ),
    isOffline: isOffline,
    isRefreshing: false,
    lastCheckedAt: DateTime.utc(2026, 11, 27),
  );
}

CatalogDocument _buildSampleCatalog() {
  return CatalogDocument(
    schemaVersion: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    apkBaseUrl: '/apk',
    capabilityTags: <CatalogCapabilityTag>[
      CatalogCapabilityTag(
        tag: 'vulkan-1.1',
        label: LocalizedText(const <String, String>{
          'en': 'Vulkan 1.1 GPU driver',
        }),
      ),
    ],
    categories: <CatalogCategoryFrame>[
      CatalogCategoryFrame(
        id: 'Emulators',
        name: LocalizedText(const <String, String>{'en': 'Emulators'}),
        entries: const <String>[
          'org.dolphinemu.dolphinemu',
          'org.ppsspp.ppsspp',
        ],
      ),
      CatalogCategoryFrame(
        id: 'Utilities',
        name: LocalizedText(const <String, String>{'en': 'Utilities'}),
        entries: const <String>['app.wayfinder'],
      ),
    ],
    entries: <CatalogEntry>[
      CatalogEntry(
        packageName: 'org.dolphinemu.dolphinemu',
        slug: 'dolphin',
        rank: 1,
        name: LocalizedText(const <String, String>{'en': 'Dolphin'}),
        publisher: 'Dolphin Team',
        category: 'Emulators',
        searchTags: const <String>['gamecube', 'wii'],
        summary: LocalizedText(const <String, String>{
          'en': 'GameCube and Wii games in HD, with netplay and save states.',
        }),
        description: LocalizedStringList(const <String, List<String>>{
          'en': <String>['Runs GameCube and Wii titles smoothly.'],
        }),
        homepageUrl: 'https://dolphin-emu.org',
        rehostMode: RehostMode.rehost,
        allowedSigningCerts: const <String>['cert-dolphin'],
        capabilities: const <String>[],
        tile: CatalogTile(
          iconUrl: '',
          backdropColors: const <String>['#0F3B6E', '#082447'],
          backdropAngle: 160,
          iconScale: 0.82,
        ),
        screenshots: const <CatalogScreenshot>[],
        release: CatalogRelease(
          versionCode: 2509,
          versionName: '2509',
          releasedAt: DateTime.utc(2026, 11, 2),
          variantsAreUserChoice: false,
          variants: <CatalogVariant>[
            CatalogVariant(
              sha256: '1' * 64,
              sizeBytes: 19 * 1024 * 1024,
              abis: const <String>['arm64-v8a'],
              minSdk: 29,
              targetSdk: 35,
              upstreamUrl: 'https://dolphin.example/dolphin.apk',
            ),
          ],
        ),
        changelogs: const <CatalogChangelog>[],
      ),
      CatalogEntry(
        packageName: 'org.ppsspp.ppsspp',
        slug: 'ppsspp',
        rank: 2,
        name: LocalizedText(const <String, String>{'en': 'PPSSPP'}),
        publisher: 'Henrik Rydgård',
        category: 'Emulators',
        searchTags: const <String>['psp', 'sony'],
        summary: LocalizedText(const <String, String>{
          'en': 'PSP games at up to 4× resolution, with controller remapping.',
        }),
        description: LocalizedStringList(const <String, List<String>>{
          'en': <String>['Fast and portable PSP emulator.'],
        }),
        homepageUrl: 'https://www.ppsspp.org',
        rehostMode: RehostMode.rehost,
        allowedSigningCerts: const <String>['cert-ppsspp'],
        capabilities: const <String>[],
        tile: CatalogTile(
          iconUrl: '',
          backdropColors: const <String>['#35505F', '#24363F'],
          backdropAngle: 160,
          iconScale: 1.14,
        ),
        screenshots: const <CatalogScreenshot>[],
        release: CatalogRelease(
          versionCode: 1181,
          versionName: '1.18.1',
          releasedAt: DateTime.utc(2026, 11, 10),
          variantsAreUserChoice: false,
          variants: <CatalogVariant>[
            CatalogVariant(
              sha256: '2' * 64,
              sizeBytes: 41 * 1024 * 1024,
              abis: const <String>['arm64-v8a'],
              minSdk: 29,
              targetSdk: 35,
              upstreamUrl: 'https://ppsspp.example/ppsspp.apk',
            ),
          ],
        ),
        changelogs: <CatalogChangelog>[
          CatalogChangelog(
            versionCode: 1181,
            versionName: '1.18.1',
            releasedAt: DateTime.utc(2026, 11, 10),
            notes: LocalizedStringList(const <String, List<String>>{
              'en': <String>['Performance fixes'],
            }),
          ),
          CatalogChangelog(
            versionCode: 1171,
            versionName: '1.17.1',
            releasedAt: DateTime.utc(2026, 10, 2),
            notes: LocalizedStringList(const <String, List<String>>{
              'en': <String>['Previous release'],
            }),
          ),
        ],
      ),
      CatalogEntry(
        packageName: 'app.wayfinder',
        slug: 'wayfinder',
        rank: 3,
        name: LocalizedText(const <String, String>{'en': 'Wayfinder'}),
        publisher: 'Anais Betts',
        category: 'Utilities',
        searchTags: const <String>['launcher', 'thor', 'dual-screen'],
        summary: LocalizedText(const <String, String>{
          'en': 'Dual-screen handheld launcher for AYN Thor.',
        }),
        description: LocalizedStringList(const <String, List<String>>{
          'en': <String>[
            'Organize apps and games across both Thor displays.',
          ],
        }),
        homepageUrl: 'https://github.com/anaisbetts/wayfinder',
        rehostMode: RehostMode.rehost,
        allowedSigningCerts: const <String>['cert-wayfinder'],
        capabilities: const <String>[],
        tile: CatalogTile(
          iconUrl: '',
          backdropColors: const <String>['#1A365D', '#0B192C'],
          backdropAngle: 160,
          iconScale: 0.88,
        ),
        screenshots: const <CatalogScreenshot>[],
        release: CatalogRelease(
          versionCode: 42,
          versionName: '2.1.0',
          releasedAt: DateTime.utc(2026, 11, 20),
          variantsAreUserChoice: false,
          variants: <CatalogVariant>[
            CatalogVariant(
              sha256: '3' * 64,
              sizeBytes: 8 * 1024 * 1024,
              abis: const <String>['arm64-v8a'],
              minSdk: 29,
              targetSdk: 35,
              upstreamUrl: 'https://wayfinder.example/wayfinder.apk',
            ),
          ],
        ),
        changelogs: const <CatalogChangelog>[],
      ),
    ],
  );
}

final class _FakeCatalogNotifier extends CatalogNotifier {
  _FakeCatalogNotifier(this._initial);

  final AsyncValue<CatalogState> _initial;
  int _refreshCalls = 0;

  int refreshCallCount() => _refreshCalls;

  @override
  Future<CatalogState> build() async {
    return switch (_initial) {
      AsyncData<CatalogState>(:final value) => value,
      AsyncError<CatalogState>(:final error, :final stackTrace) =>
        Error.throwWithStackTrace(error, stackTrace),
      AsyncLoading<CatalogState>() => Completer<CatalogState>().future,
    };
  }

  @override
  Future<void> refresh({bool forceRefresh = false}) async {
    _refreshCalls++;
  }
}

final class _FakeInstalledPackagesNotifier extends InstalledPackagesNotifier {
  _FakeInstalledPackagesNotifier(this._packages);

  final Map<String, InstalledPackage> _packages;

  @override
  Future<Map<String, InstalledPackage>> build() async => _packages;
}

final class _FakeInstallQueueNotifier extends InstallQueueNotifier {
  _FakeInstallQueueNotifier(this._initialState);

  final InstallQueueState _initialState;

  @override
  InstallQueueState build() => _initialState;
}

final class _FakeAppServices implements AppServices {
  _FakeAppServices({
    required this.installed,
    required this.capabilities,
  }) : _delegate = StubAppServices(talker: Talker());

  final List<InstalledPackage> installed;
  final Set<String> capabilities;
  final StubAppServices _delegate;

  @override
  bool get canInstall => false;

  @override
  Future<DeviceInfo> deviceInfo() async => const DeviceInfo(
    supportedAbis: <String>['arm64-v8a'],
    sdkInt: 34,
    hasPServiceBridge: false,
  );

  @override
  Future<List<InstalledPackage>> scanInstalled() async => installed;

  @override
  Future<Set<String>> metCapabilities() async => capabilities;

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
  Stream<InstallEvent> get installEvents => const Stream<InstallEvent>.empty();

  @override
  Stream<GamepadHatEvent> get gamepadHatEvents =>
      const Stream<GamepadHatEvent>.empty();

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
