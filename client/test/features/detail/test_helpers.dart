import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:talker/talker.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/features/detail/detail_page.dart';
import 'package:tshop/src/features/detail/screenshot_viewer_page.dart';
import 'package:tshop/src/images/app_image_cache.dart';
import 'package:tshop/src/install/apk_downloader.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/platform/app_services.dart';
import 'package:tshop/src/theme/tshop_theme.dart';

/// Standard Thor handheld screen size used across widget tests.
const Size thorTestSize = Size(837, 471);

/// Minimal valid 1x1 transparent PNG payload for fake image cache responses.
final Uint8List transparentPngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // RGBA
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
  0x42, 0x60, 0x82,
]);

/// Default Wayfinder package name matching the fixture catalog.
const String wayfinderPackageName = 'dev.anais.wayfinder';

/// Recorded APK download request made through [FakeApkDownloader].
class FakeDownloadRequest {
  /// Creates a recorded request.
  const FakeDownloadRequest({
    required this.uri,
    required this.expectedSha256,
    required this.expectedSizeBytes,
    this.onProgress,
    this.onVerifying,
    this.cancelToken,
  });

  /// Requested download URI.
  final Uri uri;

  /// Expected lowercase hex SHA-256 digest.
  final String expectedSha256;

  /// Expected APK size in bytes.
  final int expectedSizeBytes;

  /// Optional progress callback.
  final ApkDownloadProgressCallback? onProgress;

  /// Optional verifying callback.
  final VoidCallback? onVerifying;

  /// Optional cancel token.
  final CancelToken? cancelToken;
}

/// Test harness bundling Riverpod providers, fake services, and a [GoRouter].
class DetailTestHarness {
  /// Creates a test harness.
  DetailTestHarness({
    required this.router,
    required this.services,
    required this.downloader,
    required this.cacheManager,
    required this.launchedUrls,
    required this.overrides,
  });

  /// Router mounted for navigation assertions.
  final GoRouter router;

  /// Fake platform services recording calls and emitting events.
  final FakeAppServices services;

  /// Fake APK downloader recording requests.
  final FakeApkDownloader downloader;

  /// In-memory-backed image cache returning [transparentPngBytes].
  final CacheManager cacheManager;

  /// External URLs passed to `DetailPage.onLaunchUrl`.
  final List<Uri> launchedUrls;

  /// Provider overrides for [ProviderScope].
  final List<dynamic> overrides;

  /// Disposes router, streams, and cache manager.
  Future<void> dispose() async {
    router.dispose();
    await services.close();
    await cacheManager.dispose();
  }
}

/// Fake [AppServices] implementation for detail and viewer widget tests.
final class FakeAppServices implements AppServices {
  /// Creates fake services.
  FakeAppServices({
    this.device = const DeviceInfo(
      supportedAbis: <String>['arm64-v8a'],
      sdkInt: 35,
      hasPServiceBridge: false,
    ),
    this.canInstall = true,
    this.canRequestInstalls = true,
    this.installedPackages = const <InstalledPackage>[],
    this.capabilities = const <String>{},
  });

  /// Simulated host device info.
  final DeviceInfo device;

  @override
  final bool canInstall;

  /// Whether Android install-unknown-apps permission is granted.
  bool canRequestInstalls;

  /// Currently installed packages returned by [scanInstalled].
  List<InstalledPackage> installedPackages;

  /// Capability tags satisfied by the simulated device.
  Set<String> capabilities;

  /// Packages passed to [openInstalled].
  final List<String> openedPackages = <String>[];

  /// Packages passed to [enqueueUninstall].
  final List<String> uninstalledPackages = <String>[];

  /// Packages passed to [installApkFile].
  final List<String> installedApkPackages = <String>[];

  /// Count of calls to [openInstallPermissionSettings].
  int openInstallPermissionSettingsCount = 0;

  final StreamController<InstallEvent> _installEventsController =
      StreamController<InstallEvent>.broadcast();
  final StreamController<GamepadHatEvent> _hatEventsController =
      StreamController<GamepadHatEvent>.broadcast();

  /// Emits an [InstallEvent] on [installEvents].
  void emitInstallEvent(InstallEvent event) {
    _installEventsController.add(event);
  }

  /// Emits a [GamepadHatEvent] on [gamepadHatEvents].
  void emitHatEvent(GamepadHatEvent event) {
    _hatEventsController.add(event);
  }

  /// Closes backing stream controllers.
  Future<void> close() async {
    await _installEventsController.close();
    await _hatEventsController.close();
  }

  @override
  Future<DeviceInfo> deviceInfo() async => device;

  @override
  Future<List<InstalledPackage>> scanInstalled() async => installedPackages;

  @override
  Future<Set<String>> metCapabilities() async => capabilities;

  @override
  Future<bool> canRequestPackageInstalls() async => canRequestInstalls;

  @override
  Future<void> installApkFile({
    required String packageName,
    required String filePath,
  }) async {
    installedApkPackages.add(packageName);
  }

  @override
  Future<bool> launchPendingConfirmation({required String packageName}) async {
    return true;
  }

  @override
  Future<void> cancelPendingConfirmation({required String packageName}) async {}

  @override
  Stream<InstallEvent> get installEvents => _installEventsController.stream;

  @override
  Stream<GamepadHatEvent> get gamepadHatEvents => _hatEventsController.stream;

  @override
  Future<void> enqueueInstall({
    required String packageName,
    required Uri apk,
  }) async {}

  @override
  Future<void> enqueueUninstall({required String packageName}) async {
    uninstalledPackages.add(packageName);
  }

  @override
  Future<void> openInstalled({required String packageName}) async {
    openedPackages.add(packageName);
  }

  @override
  Future<void> notifyUpdates({required int count}) async {}

  @override
  Future<void> openInstallPermissionSettings() async {
    openInstallPermissionSettingsCount++;
  }

  @override
  Future<void> requestNotificationPermission() async {}
}

/// Fake [ApkDownloader] whose completion can be controlled per test.
final class FakeApkDownloader implements ApkDownloader {
  /// Creates a fake downloader using [onDownload].
  FakeApkDownloader({
    Future<String> Function(FakeDownloadRequest request)? onDownload,
  }) : _onDownload =
           onDownload ?? ((request) async => '/tmp/${request.expectedSha256}');

  final Future<String> Function(FakeDownloadRequest request) _onDownload;

  /// All requests submitted to [downloadAndVerify].
  final List<FakeDownloadRequest> requests = <FakeDownloadRequest>[];

  @override
  Future<String> downloadAndVerify({
    required Uri uri,
    required String expectedSha256,
    required int expectedSizeBytes,
    ApkDownloadProgressCallback? onProgress,
    VoidCallback? onVerifying,
    CancelToken? cancelToken,
  }) {
    final request = FakeDownloadRequest(
      uri: uri,
      expectedSha256: expectedSha256,
      expectedSizeBytes: expectedSizeBytes,
      onProgress: onProgress,
      onVerifying: onVerifying,
      cancelToken: cancelToken,
    );
    requests.add(request);
    return _onDownload(request);
  }

  @override
  Future<void> deleteCachedApk(String sha256) async {}
}

/// Builds a rich Wayfinder [CatalogEntry] suitable for Detail and Viewer tests.
CatalogEntry buildWayfinderEntry({
  String packageName = wayfinderPackageName,
  String name = 'Wayfinder',
  String publisher = 'Northstar Labs',
  String category = 'Games',
  RehostMode rehostMode = RehostMode.rehost,
  CatalogLanding? landing,
  String? featureUrl = 'https://cdn.tshop.test/art/wayfinder-feature.webp',
  List<String> capabilities = const <String>[],
  bool variantsAreUserChoice = false,
  List<CatalogVariant>? variants,
  List<CatalogScreenshot>? screenshots,
  List<CatalogChangelog>? changelogs,
  int versionCode = 320,
  String versionName = '3.2.0',
}) {
  return CatalogEntry(
    packageName: packageName,
    slug: 'wayfinder',
    rank: 1,
    name: LocalizedText(<String, String>{'en': name}),
    publisher: publisher,
    category: category,
    searchTags: const <String>['roguelike', 'adventure'],
    summary: LocalizedText(const <String, String>{
      'en': 'Chart procedural handheld ruins on every expedition.',
    }),
    description: LocalizedStringList(const <String, List<String>>{
      'en': <String>[
        'Wayfinder is built from the ground up for dual-stick handhelds.',
        'Explore handcrafted biomes, unlock gear, and share seeds offline.',
      ],
    }),
    homepageUrl: 'https://wayfinder.example.com',
    rehostMode: rehostMode,
    landing: landing,
    allowedSigningCerts: const <String>['aabbccdd'],
    capabilities: capabilities,
    tile: CatalogTile(
      iconUrl: 'https://cdn.tshop.test/art/wayfinder-icon.webp',
      backdropColors: const <String>['#233A7A', '#142453'],
      backdropAngle: 160,
      iconScale: 0.9,
    ),
    featureUrl: featureUrl,
    screenshots:
        screenshots ??
        const <CatalogScreenshot>[
          CatalogScreenshot(
            thumbUrl: 'https://cdn.tshop.test/art/shot-1-thumb.webp',
            fullUrl: 'https://cdn.tshop.test/art/shot-1-full.webp',
            width: 1280,
            height: 720,
          ),
          CatalogScreenshot(
            thumbUrl: 'https://cdn.tshop.test/art/shot-2-thumb.webp',
            fullUrl: 'https://cdn.tshop.test/art/shot-2-full.webp',
            width: 1280,
            height: 720,
          ),
          CatalogScreenshot(
            thumbUrl: 'https://cdn.tshop.test/art/shot-3-thumb.webp',
            fullUrl: 'https://cdn.tshop.test/art/shot-3-full.webp',
            width: 1280,
            height: 720,
          ),
          CatalogScreenshot(
            thumbUrl: 'https://cdn.tshop.test/art/shot-4-thumb.webp',
            fullUrl: 'https://cdn.tshop.test/art/shot-4-full.webp',
            width: 1280,
            height: 720,
          ),
        ],
    release: CatalogRelease(
      versionCode: versionCode,
      versionName: versionName,
      releasedAt: DateTime.utc(2026, 9, 24),
      variantsAreUserChoice: variantsAreUserChoice,
      variants:
          variants ??
          <CatalogVariant>[
            CatalogVariant(
              sha256: 'a' * 64,
              sizeBytes: 24 * 1024 * 1024,
              abis: const <String>['arm64-v8a'],
              minSdk: 24,
              targetSdk: 35,
              upstreamUrl: 'https://wayfinder.example.com/wayfinder.apk',
            ),
          ],
    ),
    changelogs:
        changelogs ??
        <CatalogChangelog>[
          CatalogChangelog(
            versionCode: versionCode,
            versionName: versionName,
            releasedAt: DateTime.utc(2026, 9, 24),
            notes: LocalizedStringList(const <String, List<String>>{
              'en': <String>[
                'New boss behaviour on depth 20',
                'Rebalanced the Explorer kit',
              ],
            }),
          ),
          CatalogChangelog(
            versionCode: 310,
            versionName: '3.1.0',
            releasedAt: DateTime.utc(2026, 8, 12),
            notes: LocalizedStringList(const <String, List<String>>{
              'en': <String>['Initial handheld layout'],
            }),
          ),
        ],
  );
}

/// Pumps a configured [MaterialApp.router] hosting [DetailPage] and
/// [ScreenshotViewerPage] with stubbed Library, Browse, and Settings routes.
Future<DetailTestHarness> pumpDetailApp(
  WidgetTester tester, {
  required List<CatalogEntry> entries,
  required String initialLocation,
  FakeAppServices? services,
  FakeApkDownloader? downloader,
  InstallQueueState? initialQueueState,
  bool isOffline = false,
  List<CatalogCapabilityTag> capabilityTags = const <CatalogCapabilityTag>[],
  Brightness brightness = Brightness.light,
  Size surfaceSize = thorTestSize,
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final effectiveServices = services ?? FakeAppServices();
  final effectiveDownloader = downloader ?? FakeApkDownloader();
  final launchedUrls = <Uri>[];
  final cacheManager = _NoTimerTestCacheManager();

  final catalogDocument = CatalogDocument(
    schemaVersion: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    apkBaseUrl: '/apk',
    capabilityTags: capabilityTags,
    categories: <CatalogCategoryFrame>[
      CatalogCategoryFrame(
        id: 'Games',
        name: LocalizedText(const <String, String>{'en': 'Games'}),
        entries: entries.map((e) => e.packageName).toList(),
      ),
    ],
    entries: entries,
  );

  final catalogState = CatalogState(
    catalog: catalogDocument,
    pointer: CatalogPointer(
      schemaVersion: 1,
      minClientVersionCode: 1,
      generatedAt: DateTime.utc(2026, 11, 27),
      generatedAtRaw: '2026-11-27T00:00:00Z',
      keyId: 'dev-v1',
      catalogUrl: '/catalog/catalog-test.json',
      catalogSha256: 'a' * 64,
      catalogSize: 100,
      statsUrl: 'https://stats.tshop.test/',
      signature: 'sig',
    ),
    isOffline: isOffline,
    isRefreshing: false,
    lastCheckedAt: DateTime.utc(2026, 11, 27),
  );

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Browse Route')),
        ),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Library Route')),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Settings Route')),
        ),
      ),
      GoRoute(
        path: '/app/:packageName',
        builder: (context, state) => DetailPage(
          packageName: state.pathParameters['packageName']!,
          onLaunchUrl: (uri) async {
            launchedUrls.add(uri);
            return true;
          },
        ),
      ),
      GoRoute(
        path: '/app/:packageName/screenshots/:index',
        builder: (context, state) => ScreenshotViewerPage(
          packageName: state.pathParameters['packageName']!,
          initialIndex: int.tryParse(state.pathParameters['index'] ?? '') ?? 0,
        ),
      ),
    ],
  );

  final harness = DetailTestHarness(
    router: router,
    services: effectiveServices,
    downloader: effectiveDownloader,
    cacheManager: cacheManager,
    launchedUrls: launchedUrls,
    overrides: <dynamic>[],
  );
  addTearDown(harness.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        talkerProvider.overrideWithValue(Talker()),
        tshopConfigProvider.overrideWithValue(
          TshopConfig(catalogBaseUrl: Uri.parse('http://127.0.0.1:8787')),
        ),
        appServicesProvider.overrideWithValue(effectiveServices),
        apkDownloaderProvider.overrideWithValue(effectiveDownloader),
        imageCacheProvider.overrideWithValue(cacheManager),
        catalogProvider.overrideWith(() => _FixedCatalogNotifier(catalogState)),
        if (initialQueueState != null)
          installQueueProvider.overrideWith(
            () => _SeededInstallQueueNotifier(initialQueueState),
          ),
      ],
      child: MaterialApp.router(
        theme: buildTshopTheme(brightness),
        routerConfig: router,
      ),
    ),
  );

  // Let async providers (catalog, installedPackages, deviceInfo) resolve.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return harness;
}

final class _FixedCatalogNotifier extends CatalogNotifier {
  _FixedCatalogNotifier(this._initialState);

  final CatalogState _initialState;

  @override
  Future<CatalogState> build() async => _initialState;
}

final class _SeededInstallQueueNotifier extends InstallQueueNotifier {
  _SeededInstallQueueNotifier(this._initialState);

  final InstallQueueState _initialState;

  @override
  InstallQueueState build() {
    super.build();
    return _initialState;
  }
}

final class _NoTimerTestCacheManager extends Fake
    implements CacheManager, ImageCacheManager {
  final IOFileSystem _fileSystem = IOFileSystem('tshopDetailTestImages');

  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) async* {
    final file = await _fileSystem.createFile('transparent.png');
    if (!file.existsSync()) {
      await file.writeAsBytes(transparentPngBytes);
    }
    yield FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(const Duration(days: 1)),
      url,
    );
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => getImageFile(
    url,
    key: key,
    headers: headers,
    withProgress: withProgress,
  );

  @override
  Future<void> dispose() async {}
}
