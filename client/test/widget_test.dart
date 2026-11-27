import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/app.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/features/browse/browse_page.dart';
import 'package:tshop/src/features/detail/detail_page.dart';
import 'package:tshop/src/features/detail/screenshot_viewer_page.dart';
import 'package:tshop/src/features/library/library_page.dart';
import 'package:tshop/src/gallery/theme_gallery_page.dart';
import 'package:tshop/src/images/app_image_cache.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/platform/app_services.dart';
import 'package:tshop/src/routing/app_router.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';

const Size _testViewport = Size(837, 471);
const String _testCatalogBaseUrl = 'http://127.0.0.1:8787';
const String _samplePackageName = 'app.wayfinder';

final class _FixedCatalogNotifier extends CatalogNotifier {
  _FixedCatalogNotifier(this._state);

  final CatalogState _state;

  @override
  Future<CatalogState> build() async => _state;
}

final class _FixedInstalledPackagesNotifier extends InstalledPackagesNotifier {
  _FixedInstalledPackagesNotifier(this._packages);

  final Map<String, InstalledPackage> _packages;

  @override
  Future<Map<String, InstalledPackage>> build() async => _packages;
}

final class _NoOpCacheManager extends Fake
    implements CacheManager, ImageCacheManager {
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('TshopApp mounts BrowsePage cleanly at /', (tester) async {
    await _pumpTshopApp(tester);

    expect(find.byType(BrowsePage), findsOneWidget);
    expect(find.text('Utilities'), findsWidgets);
    expect(find.text('Wayfinder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'app router switches between Browse, Library, Settings, and Gallery',
    (tester) async {
      await _pumpTshopApp(tester);

      // Tap Library tab -> LibraryPage.
      await tester.tap(find.text('Library'));
      await _pumpRouteTransition(tester);
      expect(find.byType(LibraryPage), findsOneWidget);

      // Tap Settings tab -> SettingsStubPage with active catalogBaseUrl.
      await tester.tap(find.text('Settings'));
      await _pumpRouteTransition(tester);
      expect(find.byType(SettingsStubPage), findsOneWidget);
      expect(find.text(_testCatalogBaseUrl), findsOneWidget);
      expect(find.text('Open Theme Gallery'), findsOneWidget);

      // Tap Open Theme Gallery -> pushes ThemeGalleryPage.
      await tester.tap(find.text('Open Theme Gallery'));
      await _pumpRouteTransition(tester);
      expect(find.byType(ThemeGalleryPage), findsOneWidget);

      // Pop back to Settings, then tap [A] Open in the footer legend ->
      // pushes ThemeGalleryPage again.
      _routerOf(tester).pop();
      await _pumpRouteTransition(tester);
      expect(find.byType(SettingsStubPage), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(TshopLegend),
          matching: find.text('Open'),
        ),
      );
      await _pumpRouteTransition(tester);
      expect(find.byType(ThemeGalleryPage), findsOneWidget);

      // Pop back to Settings, then use [L] to return to Library and [R] ->
      // Settings -> [R] -> Browse.
      _routerOf(tester).pop();
      await _pumpRouteTransition(tester);
      expect(find.byType(SettingsStubPage), findsOneWidget);

      await _pressKey(tester, LogicalKeyboardKey.bracketLeft);
      await _pumpRouteTransition(tester);
      expect(find.byType(LibraryPage), findsOneWidget);

      await _pressKey(tester, LogicalKeyboardKey.bracketRight);
      await _pumpRouteTransition(tester);
      expect(find.byType(SettingsStubPage), findsOneWidget);

      await _pressKey(tester, LogicalKeyboardKey.bracketRight);
      await _pumpRouteTransition(tester);
      expect(find.byType(BrowsePage), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('app router opens DetailPage and ScreenshotViewerPage', (
    tester,
  ) async {
    await _pumpTshopApp(tester);

    final router = _routerOf(tester)..go('/app/$_samplePackageName');
    await _pumpRouteTransition(tester);

    expect(find.byType(DetailPage), findsOneWidget);
    expect(find.text('Wayfinder'), findsOneWidget);

    router.go('/app/$_samplePackageName/screenshots/0');
    await _pumpRouteTransition(tester);

    expect(find.byType(ScreenshotViewerPage), findsOneWidget);
    expect(find.text('No screenshots available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> _pumpTshopApp(WidgetTester tester) async {
  tester.view.physicalSize = _testViewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final catalogState = _buildCatalogState();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tshopConfigProvider.overrideWithValue(
          TshopConfig(catalogBaseUrl: Uri.parse(_testCatalogBaseUrl)),
        ),
        appServicesProvider.overrideWithValue(
          StubAppServices(talker: Talker()),
        ),
        imageCacheProvider.overrideWithValue(_NoOpCacheManager()),
        catalogProvider.overrideWith(() => _FixedCatalogNotifier(catalogState)),
        installedPackagesProvider.overrideWith(
          () => _FixedInstalledPackagesNotifier(
            const <String, InstalledPackage>{},
          ),
        ),
        deviceInfoProvider.overrideWith(
          (ref) async => const DeviceInfo(
            supportedAbis: <String>['arm64-v8a'],
            sdkInt: 34,
            hasPServiceBridge: false,
          ),
        ),
        metCapabilitiesProvider.overrideWith((ref) async => const <String>{}),
      ],
      child: const TshopApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

GoRouter _routerOf(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TshopApp)),
  );
  return container.read(appRouterProvider);
}

Future<void> _pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}

CatalogState _buildCatalogState() {
  final entry = CatalogEntry(
    packageName: _samplePackageName,
    slug: 'wayfinder',
    rank: 1,
    name: LocalizedText(const <String, String>{'en': 'Wayfinder'}),
    publisher: 'Anais Betts',
    category: 'Utilities',
    searchTags: const <String>['launcher'],
    summary: LocalizedText(const <String, String>{
      'en': 'Dual-screen handheld launcher for AYN Thor.',
    }),
    description: LocalizedStringList(const <String, List<String>>{
      'en': <String>['Organize apps and games across both Thor displays.'],
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
  );

  final document = CatalogDocument(
    schemaVersion: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    apkBaseUrl: '/apk',
    capabilityTags: const <CatalogCapabilityTag>[],
    categories: <CatalogCategoryFrame>[
      CatalogCategoryFrame(
        id: 'Utilities',
        name: LocalizedText(const <String, String>{'en': 'Utilities'}),
        entries: const <String>[_samplePackageName],
      ),
    ],
    entries: <CatalogEntry>[entry],
  );

  return CatalogState(
    catalog: document,
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
    isOffline: false,
    isRefreshing: false,
    lastCheckedAt: DateTime.utc(2026, 11, 27),
  );
}
