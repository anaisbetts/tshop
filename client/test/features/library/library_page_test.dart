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
import 'package:tshop/src/features/library/library_page.dart';
import 'package:tshop/src/features/library/library_shelf_model.dart';
import 'package:tshop/src/install/apk_downloader.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/platform/app_services.dart';
import 'package:tshop/src/theme/tshop_theme.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/tshop_chip.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';
import 'package:tshop/src/theme/widgets/tshop_surfaces.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';

const Size _thorSize = TshopMetrics.thorCanvas;
const String _trustedCert = 'aabbccdd';
const String _foreignCert = 'deadbeef';

final class _TestInstallQueueNotifier extends InstallQueueNotifier {
  _TestInstallQueueNotifier(this._seedState);

  final InstallQueueState _seedState;

  @override
  InstallQueueState build() {
    super.build();
    return _seedState;
  }
}

final class _FixedCatalogNotifier extends CatalogNotifier {
  _FixedCatalogNotifier(this._state);

  final CatalogState _state;

  @override
  Future<CatalogState> build() async => _state;
}

final class _FakeAppServices implements AppServices {
  _FakeAppServices({
    this.installedPackages = const <InstalledPackage>[],
    this.canRequestInstalls = true,
  });

  List<InstalledPackage> installedPackages;

  @override
  bool get canInstall => true;

  bool canRequestInstalls;

  final List<String> confirmedPackages = <String>[];
  final List<String> cancelledConfirmations = <String>[];
  int permissionSettingsOpens = 0;

  final StreamController<InstallEvent> _installEvents =
      StreamController<InstallEvent>.broadcast();
  final StreamController<GamepadHatEvent> _hatEvents =
      StreamController<GamepadHatEvent>.broadcast();

  Future<void> close() async {
    await _installEvents.close();
    await _hatEvents.close();
  }

  @override
  Future<DeviceInfo> deviceInfo() async => const DeviceInfo(
    supportedAbis: <String>['arm64-v8a'],
    sdkInt: 34,
    hasPServiceBridge: false,
  );

  @override
  Future<List<InstalledPackage>> scanInstalled() async => installedPackages;

  @override
  Future<Set<String>> metCapabilities() async => const <String>{};

  @override
  Future<bool> canRequestPackageInstalls() async => canRequestInstalls;

  @override
  Future<void> installApkFile({
    required String packageName,
    required String filePath,
  }) async {}

  @override
  Future<bool> launchPendingConfirmation({required String packageName}) async {
    confirmedPackages.add(packageName);
    return true;
  }

  @override
  Future<void> cancelPendingConfirmation({required String packageName}) async {
    cancelledConfirmations.add(packageName);
  }

  @override
  Stream<InstallEvent> get installEvents => _installEvents.stream;

  @override
  Stream<GamepadHatEvent> get gamepadHatEvents => _hatEvents.stream;

  @override
  Future<void> enqueueInstall({
    required String packageName,
    required Uri apk,
  }) async {}

  @override
  Future<void> enqueueUninstall({required String packageName}) async {}

  @override
  Future<void> openInstalled({required String packageName}) async {}

  @override
  Future<void> notifyUpdates({required int count}) async {}

  @override
  Future<void> openInstallPermissionSettings() async {
    permissionSettingsOpens++;
  }

  @override
  Future<void> requestNotificationPermission() async {}
}

final class _FakeApkDownloader implements ApkDownloader {
  final List<Uri> requestedUris = <Uri>[];
  final List<String> requestedSha256s = <String>[];

  @override
  Future<String> downloadAndVerify({
    required Uri uri,
    required String expectedSha256,
    required int expectedSizeBytes,
    ApkDownloadProgressCallback? onProgress,
    VoidCallback? onVerifying,
    Object? cancelToken,
  }) {
    requestedUris.add(uri);
    requestedSha256s.add(expectedSha256);
    return Completer<String>().future;
  }

  @override
  Future<void> deleteCachedApk(String sha256) async {}
}

void main() {
  group('LibraryPage', () {
    testWidgets(
      'empty state renders copy, ghost grid, and [L] navigates to /',
      (tester) async {
        _setThorViewport(tester);
        final services = _FakeAppServices();
        addTearDown(services.close);

        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: _FakeApkDownloader(),
            entries: <CatalogEntry>[
              _makeEntry(
                packageName: 'org.dolphinemu.dolphin',
                name: 'Dolphin',
                category: 'Emulators',
                iconAsset: 'assets/sample/icons/dolphin.png',
                versionCode: 200,
                sha256: '1' * 64,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nothing from the catalog yet'), findsOneWidget);
        expect(
          find.text(
            'Apps you install from Browse, and catalog apps already on this '
            'device, show up here.',
          ),
          findsOneWidget,
        );
        expect(find.text('Library fills in as you install.'), findsOneWidget);
        expect(find.byType(TshopFrame), findsNothing);
        expect(find.byType(TshopTile), findsNothing);
        expect(find.byType(TshopCountBadge), findsNothing);

        // Press [L] (bracketLeft) to switch to Browse (`/`).
        await _pressKey(tester, LogicalKeyboardKey.bracketLeft);
        await tester.pumpAndSettle();

        expect(find.text('BROWSE_ROUTE'), findsOneWidget);
      },
    );

    testWidgets(
      'groups Queue, Updates available (Update All uncounted), Up to date, '
      'and Other source in exact order',
      (tester) async {
        _setThorViewport(tester);

        final melonds = _makeEntry(
          packageName: 'me.magnum.melonds',
          name: 'melonDS',
          category: 'Emulators',
          iconAsset: 'assets/sample/icons/melonds.png',
          versionCode: 100,
          sha256: 'a' * 64,
        );
        final unciv = _makeEntry(
          packageName: 'com.unciv.app',
          name: 'Unciv',
          category: 'Games',
          summary:
              'An open-source take on Civilization V, made for small screens.',
          iconAsset: 'assets/sample/icons/unciv.png',
          versionCode: 417,
          sha256: 'b' * 64,
        );
        final amaze = _makeEntry(
          packageName: 'com.amaze.filemanager',
          name: 'Amaze',
          category: 'Utilities',
          iconAsset: 'assets/sample/icons/amaze.png',
          versionCode: 310,
          sha256: 'c' * 64,
        );
        final ppsspp = _makeEntry(
          packageName: 'org.ppsspp.ppsspp',
          name: 'PPSSPP',
          category: 'Emulators',
          iconAsset: 'assets/sample/icons/ppsspp.png',
          versionCode: 118,
          sha256: 'd' * 64,
        );
        final lemuroid = _makeEntry(
          packageName: 'com.swordfish.lemuroid',
          name: 'Lemuroid',
          category: 'Frontends',
          iconAsset: 'assets/sample/icons/lemuroid.png',
          versionCode: 116,
          sha256: 'e' * 64,
        );
        final mindustry = _makeEntry(
          packageName: 'io.anuke.mindustry',
          name: 'Mindustry',
          category: 'Games',
          iconAsset: 'assets/sample/icons/mindustry.png',
          versionCode: 146,
          sha256: 'f' * 64,
        );
        final dolphin = _makeEntry(
          packageName: 'org.dolphinemu.dolphin',
          name: 'Dolphin',
          category: 'Emulators',
          iconAsset: 'assets/sample/icons/dolphin.png',
          versionCode: 250,
          sha256: '1' * 64,
        );
        final moonlight = _makeEntry(
          packageName: 'com.limelight',
          name: 'Moonlight',
          category: 'Utilities',
          iconAsset: 'assets/sample/icons/moonlight.png',
          versionCode: 121,
          sha256: '2' * 64,
        );

        final services = _FakeAppServices(
          installedPackages: <InstalledPackage>[
            const InstalledPackage(
              packageName: 'org.ppsspp.ppsspp',
              versionCode: 117,
              signingSha256: _trustedCert,
            ),
            const InstalledPackage(
              packageName: 'com.swordfish.lemuroid',
              versionCode: 115,
              signingSha256: _trustedCert,
            ),
            const InstalledPackage(
              packageName: 'io.anuke.mindustry',
              versionCode: 145,
              signingSha256: _trustedCert,
            ),
            const InstalledPackage(
              packageName: 'org.dolphinemu.dolphin',
              versionCode: 250,
              signingSha256: _trustedCert,
            ),
            const InstalledPackage(
              packageName: 'com.limelight',
              versionCode: 120,
              signingSha256: _foreignCert,
            ),
          ],
        );
        addTearDown(services.close);

        final seedQueue = InstallQueueState(
          tasks: <String, InstallTask>{
            melonds.packageName: InstallTask(
              packageName: melonds.packageName,
              appName: 'melonDS',
              variant: melonds.release!.variants.first,
              intent: installIntentInstall,
              stage: InstallTaskStage.downloading,
              progress: 0.62,
            ),
            unciv.packageName: InstallTask(
              packageName: unciv.packageName,
              appName: 'Unciv',
              variant: unciv.release!.variants.first,
              intent: installIntentInstall,
              stage: InstallTaskStage.awaitingConfirm,
              progress: 1,
              sessionId: 42,
            ),
            amaze.packageName: InstallTask(
              packageName: amaze.packageName,
              appName: 'Amaze',
              variant: amaze.release!.variants.first,
              intent: installIntentInstall,
              stage: InstallTaskStage.failed,
              errorMessage: 'Publisher host unreachable.',
            ),
          },
          order: <String>[
            melonds.packageName,
            unciv.packageName,
            amaze.packageName,
          ],
        );

        final router = _buildTestRouter(
          initialLocation: '/library',
          initialFocusedId: libraryUpdateAllFocusId,
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: _FakeApkDownloader(),
            entries: <CatalogEntry>[
              melonds,
              unciv,
              amaze,
              ppsspp,
              lemuroid,
              mindustry,
              dolphin,
              moonlight,
            ],
            initialQueue: seedQueue,
          ),
        );
        await tester.pump();
        await tester.pump();

        final frames = tester
            .widgetList<TshopFrame>(find.byType(TshopFrame))
            .toList();
        expect(
          frames.map((frame) => frame.label).toList(),
          <String>['Queue', 'Updates available', 'Up to date', 'Other source'],
        );
        expect(
          frames.map((frame) => frame.count).toList(),
          <int?>[3, 3, 1, 1],
        );
        // Updates available has 1 Update All lead tile + 3 app tiles.
        expect(frames[1].tiles, hasLength(4));
        expect(find.byType(TshopActionTile), findsOneWidget);

        // Library tab count badge = 3 queued + 3 updates available = 6.
        final topBar = tester.widget<TshopTopBar>(find.byType(TshopTopBar));
        expect(topBar.libraryCount, 6);
        expect(topBar.destination, TshopDestination.library);
        expect(topBar.showSearch, isFalse);

        // Up to date and Other source tiles use TileContext.library so they
        // omit bottom-right check marks (and Other source is dimmed).
        final allTiles = tester
            .widgetList<TshopTile>(find.byType(TshopTile))
            .toList();
        final dolphinTile = allTiles.firstWhere(
          (tile) => tile.semanticLabel == 'Dolphin',
        );
        expect(dolphinTile.context, TileContext.library);
        expect(dolphinTile.status, TileStatus.installed);

        final moonlightTile = allTiles.firstWhere(
          (tile) => tile.semanticLabel == 'Moonlight',
        );
        expect(moonlightTile.context, TileContext.library);
        expect(moonlightTile.status, TileStatus.otherSource);

        // Update All focus shows expected info strip and legend.
        expect(find.text('Update all 3 apps'), findsOneWidget);
        expect(
          find.text(
            'Downloads start now. The rest of the queue keeps going if one '
            'fails.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'activating Update All enqueues all available updates',
      (tester) async {
        _setThorViewport(tester);

        final ppsspp = _makeEntry(
          packageName: 'org.ppsspp.ppsspp',
          name: 'PPSSPP',
          category: 'Emulators',
          iconAsset: 'assets/sample/icons/ppsspp.png',
          versionCode: 118,
          sha256: 'd' * 64,
        );
        final lemuroid = _makeEntry(
          packageName: 'com.swordfish.lemuroid',
          name: 'Lemuroid',
          category: 'Frontends',
          iconAsset: 'assets/sample/icons/lemuroid.png',
          versionCode: 116,
          sha256: 'e' * 64,
        );

        final services = _FakeAppServices(
          installedPackages: const <InstalledPackage>[
            InstalledPackage(
              packageName: 'org.ppsspp.ppsspp',
              versionCode: 117,
              signingSha256: _trustedCert,
            ),
            InstalledPackage(
              packageName: 'com.swordfish.lemuroid',
              versionCode: 115,
              signingSha256: _trustedCert,
            ),
          ],
        );
        addTearDown(services.close);

        final downloader = _FakeApkDownloader();
        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: downloader,
            entries: <CatalogEntry>[ppsspp, lemuroid],
          ),
        );
        await tester.pump();
        await tester.pump();

        // Update All is slot 0 of the first shelf, so it starts focused.
        expect(find.text('Update all 2 apps'), findsOneWidget);

        // Press [A] (Enter) to trigger Update All.
        await _pressKey(tester, LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump();

        expect(
          downloader.requestedSha256s,
          containsAllInOrder(<String>['d' * 64, 'e' * 64]),
        );
        final frames = tester
            .widgetList<TshopFrame>(find.byType(TshopFrame))
            .toList();
        expect(frames.map((frame) => frame.label).toList(), <String>['Queue']);
        expect(frames.single.count, 2);
      },
    );

    testWidgets(
      'awaitingConfirm renders green bar, chip, footer note, auto-triggers '
      'confirmation once, and [X] cancels it',
      (tester) async {
        _setThorViewport(tester);

        final unciv = _makeEntry(
          packageName: 'com.unciv.app',
          name: 'Unciv',
          category: 'Games',
          summary:
              'An open-source take on Civilization V, made for small screens.',
          iconAsset: 'assets/sample/icons/unciv.png',
          versionCode: 417,
          sha256: 'b' * 64,
        );

        final services = _FakeAppServices();
        addTearDown(services.close);

        final seedQueue = InstallQueueState(
          tasks: <String, InstallTask>{
            unciv.packageName: InstallTask(
              packageName: unciv.packageName,
              appName: 'Unciv',
              variant: unciv.release!.variants.first,
              intent: installIntentInstall,
              stage: InstallTaskStage.awaitingConfirm,
              progress: 1,
              sessionId: 77,
            ),
          },
          order: <String>[unciv.packageName],
        );

        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: _FakeApkDownloader(),
            entries: <CatalogEntry>[unciv],
            initialQueue: seedQueue,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Tile renders confirm state (green bar).
        final tile = tester.widget<TshopTile>(find.byType(TshopTile));
        expect(tile.status, TileStatus.confirm);

        // Info strip shows "Confirm with Android" good chip.
        expect(find.text('Unciv'), findsOneWidget);
        final confirmChipFinder = find.widgetWithText(
          TshopChip,
          'Confirm with Android',
        );
        expect(confirmChipFinder, findsOneWidget);
        expect(
          tester.widget<TshopChip>(confirmChipFinder).tone,
          TshopChipTone.good,
        );

        // Footer displays muted confirmation note and [X] Cancel.
        expect(
          find.text(
            "Android asks to confirm each install while you're on Library",
          ),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);

        // Automatically prompted once on mount (no duplicate loop on pump).
        expect(services.confirmedPackages, <String>['com.unciv.app']);
        await tester.pump(const Duration(milliseconds: 200));
        expect(services.confirmedPackages, <String>['com.unciv.app']);

        // Pressing [A] re-triggers pending confirmation explicitly.
        await _pressKey(tester, LogicalKeyboardKey.enter);
        await tester.pump();
        expect(
          services.confirmedPackages,
          <String>['com.unciv.app', 'com.unciv.app'],
        );

        // Pressing [X] cancels the task and clears the queue.
        await _pressKey(tester, LogicalKeyboardKey.keyX);
        await tester.pump();
        await tester.pump();

        expect(services.cancelledConfirmations, <String>['com.unciv.app']);
        expect(find.text('Nothing from the catalog yet'), findsOneWidget);
      },
    );

    testWidgets(
      'failed task shows [Y] Retry and [X] Dismiss and calls notifier cleanly',
      (tester) async {
        _setThorViewport(tester);

        final amaze = _makeEntry(
          packageName: 'com.amaze.filemanager',
          name: 'Amaze',
          category: 'Utilities',
          iconAsset: 'assets/sample/icons/amaze.png',
          versionCode: 310,
          sha256: 'c' * 64,
        );

        final services = _FakeAppServices();
        addTearDown(services.close);

        final downloader = _FakeApkDownloader();
        final seedQueue = InstallQueueState(
          tasks: <String, InstallTask>{
            amaze.packageName: InstallTask(
              packageName: amaze.packageName,
              appName: 'Amaze',
              variant: amaze.release!.variants.first,
              intent: installIntentInstall,
              stage: InstallTaskStage.failed,
              errorMessage:
                  'Publisher host unreachable. Privacy Mode does not fall back '
                  'to tShop.',
            ),
          },
          order: <String>[amaze.packageName],
        );

        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: downloader,
            entries: <CatalogEntry>[amaze],
            initialQueue: seedQueue,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Amaze'), findsOneWidget);
        expect(
          find.text(
            'Publisher host unreachable. Privacy Mode does not fall back to '
            'tShop.',
          ),
          findsOneWidget,
        );
        expect(find.text('Download failed'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);

        // Press [Y] to retry -> downloader receives the variant SHA-256.
        await _pressKey(tester, LogicalKeyboardKey.keyY);
        await tester.pump();
        await tester.pump();

        expect(downloader.requestedSha256s, <String>['c' * 64]);
      },
    );

    testWidgets(
      'failed task [X] dismisses and unknown-sources [Y] opens settings',
      (tester) async {
        _setThorViewport(tester);

        final amaze = _makeEntry(
          packageName: 'com.amaze.filemanager',
          name: 'Amaze',
          category: 'Utilities',
          iconAsset: 'assets/sample/icons/amaze.png',
          versionCode: 310,
          sha256: 'c' * 64,
        );

        final services = _FakeAppServices(canRequestInstalls: false);
        addTearDown(services.close);

        final seedQueue = InstallQueueState(
          tasks: <String, InstallTask>{
            amaze.packageName: InstallTask(
              packageName: amaze.packageName,
              appName: 'Amaze',
              variant: amaze.release!.variants.first,
              intent: installIntentInstall,
              stage: InstallTaskStage.failed,
              needsInstallPermission: true,
            ),
          },
          order: <String>[amaze.packageName],
        );

        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: _FakeApkDownloader(),
            entries: <CatalogEntry>[amaze],
            initialQueue: seedQueue,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text(
            'Allow "Install unknown apps" for tShop in Android Settings to '
            'continue.',
          ),
          findsOneWidget,
        );

        // Press [Y] -> opens Android install-unknown-apps settings.
        await _pressKey(tester, LogicalKeyboardKey.keyY);
        await tester.pump();
        expect(services.permissionSettingsOpens, 1);

        // Press [X] -> dismisses the failed task.
        await _pressKey(tester, LogicalKeyboardKey.keyX);
        await tester.pump();
        await tester.pump();

        expect(find.text('Nothing from the catalog yet'), findsOneWidget);
      },
    );

    testWidgets(
      '[A] opens Detail on Up to date tile and [R] navigates to Settings',
      (tester) async {
        _setThorViewport(tester);

        final dolphin = _makeEntry(
          packageName: 'org.dolphinemu.dolphin',
          name: 'Dolphin',
          category: 'Emulators',
          iconAsset: 'assets/sample/icons/dolphin.png',
          versionCode: 250,
          sha256: '1' * 64,
        );

        final services = _FakeAppServices(
          installedPackages: const <InstalledPackage>[
            InstalledPackage(
              packageName: 'org.dolphinemu.dolphin',
              versionCode: 250,
              signingSha256: _trustedCert,
            ),
          ],
        );
        addTearDown(services.close);

        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: _FakeApkDownloader(),
            entries: <CatalogEntry>[dolphin],
          ),
        );
        await tester.pump();
        await tester.pump();

        // Press [A] -> opens Detail route for Dolphin.
        await _pressKey(tester, LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('DETAIL:org.dolphinemu.dolphin'), findsOneWidget);

        // Return to Library and press [R] -> switches to Settings.
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await _pressKey(tester, LogicalKeyboardKey.bracketRight);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('SETTINGS_ROUTE'), findsOneWidget);
      },
    );

    testWidgets(
      'D-pad moves across shelves and reflects offline catalog indicator',
      (tester) async {
        _setThorViewport(tester);

        final ppsspp = _makeEntry(
          packageName: 'org.ppsspp.ppsspp',
          name: 'PPSSPP',
          category: 'Emulators',
          iconAsset: 'assets/sample/icons/ppsspp.png',
          versionCode: 118,
          sha256: 'd' * 64,
        );
        final dolphin = _makeEntry(
          packageName: 'org.dolphinemu.dolphin',
          name: 'Dolphin',
          category: 'Emulators',
          iconAsset: 'assets/sample/icons/dolphin.png',
          versionCode: 250,
          sha256: '1' * 64,
        );

        final services = _FakeAppServices(
          installedPackages: const <InstalledPackage>[
            InstalledPackage(
              packageName: 'org.ppsspp.ppsspp',
              versionCode: 117,
              signingSha256: _trustedCert,
            ),
            InstalledPackage(
              packageName: 'org.dolphinemu.dolphin',
              versionCode: 250,
              signingSha256: _trustedCert,
            ),
          ],
        );
        addTearDown(services.close);

        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: _FakeApkDownloader(),
            entries: <CatalogEntry>[ppsspp, dolphin],
            isOffline: true,
          ),
        );
        await tester.pump();
        await tester.pump();

        final topBar = tester.widget<TshopTopBar>(find.byType(TshopTopBar));
        expect(topBar.online, isFalse);

        // Starts on Update All (slot 0 of Updates available).
        expect(find.text('Update all 1 apps'), findsOneWidget);

        // ArrowDown moves to PPSSPP inside Updates available.
        await _pressKey(tester, LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(find.text('PPSSPP'), findsOneWidget);
        expect(find.text('Update to 1.0.118'), findsOneWidget);

        // ArrowRight crosses into Up to date shelf (Dolphin).
        await _pressKey(tester, LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(find.text('Dolphin'), findsOneWidget);
        expect(find.text('Installed'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping [L] Browse in empty Library footer legend navigates to /',
      (tester) async {
        _setThorViewport(tester);

        final services = _FakeAppServices();
        addTearDown(services.close);
        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: _FakeApkDownloader(),
            entries: <CatalogEntry>[
              _makeEntry(
                packageName: 'org.dolphinemu.dolphin',
                name: 'Dolphin',
                category: 'Emulators',
                iconAsset: 'assets/sample/icons/dolphin.png',
                versionCode: 200,
                sha256: '1' * 64,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(TshopLegend),
            matching: find.text('Browse'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('BROWSE_ROUTE'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping [X] Cancel in Library footer legend cancels awaiting task '
      'while Move stays non-interactive',
      (tester) async {
        _setThorViewport(tester);

        final unciv = _makeEntry(
          packageName: 'com.unciv.app',
          name: 'Unciv',
          category: 'Games',
          iconAsset: 'assets/sample/icons/unciv.png',
          versionCode: 417,
          sha256: 'b' * 64,
        );
        final services = _FakeAppServices();
        addTearDown(services.close);
        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: _FakeApkDownloader(),
            entries: <CatalogEntry>[unciv],
            initialQueue: InstallQueueState(
              tasks: <String, InstallTask>{
                unciv.packageName: InstallTask(
                  packageName: unciv.packageName,
                  appName: 'Unciv',
                  variant: unciv.release!.variants.first,
                  intent: installIntentInstall,
                  stage: InstallTaskStage.awaitingConfirm,
                  progress: 1,
                  sessionId: 77,
                ),
              },
              order: <String>[unciv.packageName],
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final moveHint = tester.widget<TshopLegendHint>(
          find.ancestor(
            of: find.text('Move'),
            matching: find.byType(TshopLegendHint),
          ),
        );
        expect(moveHint.item.onTap, isNull);

        await tester.tap(
          find.descendant(
            of: find.byType(TshopLegend),
            matching: find.text('Cancel'),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(services.cancelledConfirmations, <String>['com.unciv.app']);
        expect(find.text('Nothing from the catalog yet'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping [Y] Retry in Library footer legend retries failed task',
      (tester) async {
        _setThorViewport(tester);

        final amaze = _makeEntry(
          packageName: 'com.amaze.filemanager',
          name: 'Amaze',
          category: 'Utilities',
          iconAsset: 'assets/sample/icons/amaze.png',
          versionCode: 310,
          sha256: 'c' * 64,
        );
        final services = _FakeAppServices();
        addTearDown(services.close);
        final downloader = _FakeApkDownloader();
        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: downloader,
            entries: <CatalogEntry>[amaze],
            initialQueue: InstallQueueState(
              tasks: <String, InstallTask>{
                amaze.packageName: InstallTask(
                  packageName: amaze.packageName,
                  appName: 'Amaze',
                  variant: amaze.release!.variants.first,
                  intent: installIntentInstall,
                  stage: InstallTaskStage.failed,
                  errorMessage: 'Network timeout',
                ),
              },
              order: <String>[amaze.packageName],
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(
          find.descendant(
            of: find.byType(TshopLegend),
            matching: find.text('Retry'),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(downloader.requestedSha256s, <String>['c' * 64]);
      },
    );

    testWidgets(
      'compact square viewport renders shelves cleanly and tapping [A] Update '
      'All in footer legend enqueues updates',
      (tester) async {
        tester.view.physicalSize = const Size(640, 516);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final services = _FakeAppServices(
          installedPackages: const <InstalledPackage>[
            InstalledPackage(
              packageName: 'org.ppsspp.ppsspp',
              versionCode: 117,
              signingSha256: _trustedCert,
            ),
          ],
        );
        addTearDown(services.close);
        final downloader = _FakeApkDownloader();
        final router = _buildTestRouter(initialLocation: '/library');
        addTearDown(router.dispose);
        final ppsspp = _makeEntry(
          packageName: 'org.ppsspp.ppsspp',
          name: 'PPSSPP',
          category: 'Emulators',
          iconAsset: 'assets/sample/icons/ppsspp.png',
          versionCode: 118,
          sha256: 'd' * 64,
        );

        await tester.pumpWidget(
          _wrapTestApp(
            router: router,
            services: services,
            downloader: downloader,
            entries: <CatalogEntry>[ppsspp],
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(
          find.descendant(
            of: find.byType(TshopLegend),
            matching: find.text('Update All'),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(downloader.requestedSha256s, <String>['d' * 64]);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

void _setThorViewport(WidgetTester tester) {
  tester.view.physicalSize = _thorSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
}

GoRouter _buildTestRouter({
  required String initialLocation,
  String? initialFocusedId,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('BROWSE_ROUTE')),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) =>
            LibraryPage(initialFocusedId: initialFocusedId),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Text('SETTINGS_ROUTE')),
      ),
      GoRoute(
        path: '/app/:packageName',
        builder: (context, state) => Scaffold(
          body: Text('DETAIL:${state.pathParameters['packageName']}'),
        ),
      ),
    ],
  );
}

Widget _wrapTestApp({
  required GoRouter router,
  required _FakeAppServices services,
  required _FakeApkDownloader downloader,
  required List<CatalogEntry> entries,
  InstallQueueState? initialQueue,
  bool isOffline = false,
}) {
  final doc = CatalogDocument(
    schemaVersion: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    apkBaseUrl: '/apk',
    capabilityTags: const <CatalogCapabilityTag>[],
    categories: <CatalogCategoryFrame>[
      CatalogCategoryFrame(
        id: 'Emulators',
        name: LocalizedText(const <String, String>{'en': 'Emulators'}),
        entries: const <String>[],
      ),
      CatalogCategoryFrame(
        id: 'Frontends',
        name: LocalizedText(const <String, String>{'en': 'Frontends'}),
        entries: const <String>[],
      ),
      CatalogCategoryFrame(
        id: 'Games',
        name: LocalizedText(const <String, String>{'en': 'Games'}),
        entries: const <String>[],
      ),
      CatalogCategoryFrame(
        id: 'Utilities',
        name: LocalizedText(const <String, String>{'en': 'Utilities'}),
        entries: const <String>[],
      ),
    ],
    entries: entries,
  );
  final pointer = CatalogPointer(
    schemaVersion: 1,
    minClientVersionCode: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    generatedAtRaw: '2026-11-27T00:00:00Z',
    keyId: 'dev-v1',
    catalogUrl: '/catalog/catalog-test.json',
    catalogSha256: 'a' * 64,
    catalogSize: 100,
    statsUrl: 'https://stats.tshop.example/',
    signature: 'sig',
  );
  final catalogState = CatalogState(
    catalog: doc,
    pointer: pointer,
    isOffline: isOffline,
    isRefreshing: false,
    lastCheckedAt: DateTime.utc(2026, 11, 27),
  );

  return ProviderScope(
    overrides: [
      talkerProvider.overrideWithValue(Talker()),
      tshopConfigProvider.overrideWithValue(
        TshopConfig(catalogBaseUrl: Uri.parse('http://127.0.0.1:8787')),
      ),
      appServicesProvider.overrideWithValue(services),
      apkDownloaderProvider.overrideWithValue(downloader),
      catalogProvider.overrideWith(() => _FixedCatalogNotifier(catalogState)),
      if (initialQueue != null)
        installQueueProvider.overrideWith(
          () => _TestInstallQueueNotifier(initialQueue),
        ),
    ],
    child: MaterialApp.router(
      theme: buildTshopTheme(Brightness.light),
      routerConfig: router,
    ),
  );
}

CatalogEntry _makeEntry({
  required String packageName,
  required String name,
  required String category,
  required String iconAsset,
  required int versionCode,
  required String sha256,
  String summary = 'A great handheld app.',
}) {
  return CatalogEntry(
    packageName: packageName,
    slug: packageName,
    rank: 1,
    name: LocalizedText(<String, String>{'en': name}),
    publisher: 'Publisher',
    category: category,
    searchTags: const <String>[],
    summary: LocalizedText(<String, String>{'en': summary}),
    description: LocalizedStringList(const <String, List<String>>{
      'en': <String>['Description paragraph.'],
    }),
    homepageUrl: 'https://example.com',
    rehostMode: RehostMode.rehost,
    allowedSigningCerts: const <String>[_trustedCert],
    capabilities: const <String>[],
    tile: CatalogTile(
      iconUrl: iconAsset,
      backdropColors: const <String>['#233A7A', '#142453'],
      backdropAngle: 160,
      iconScale: 0.86,
    ),
    screenshots: const <CatalogScreenshot>[],
    release: CatalogRelease(
      versionCode: versionCode,
      versionName: '1.0.$versionCode',
      releasedAt: DateTime.utc(2026, 11),
      variantsAreUserChoice: false,
      variants: <CatalogVariant>[
        CatalogVariant(
          sha256: sha256,
          sizeBytes: 1024 * 1024,
          abis: const <String>['arm64-v8a'],
          minSdk: 24,
          targetSdk: 35,
          upstreamUrl: 'https://upstream.example/$packageName.apk',
        ),
      ],
    ),
    changelogs: const <CatalogChangelog>[],
  );
}
