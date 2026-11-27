import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/features/detail/detail_art.dart';
import 'package:tshop/src/features/detail/detail_page.dart';
import 'package:tshop/src/features/detail/screenshot_viewer_page.dart';
import 'package:tshop/src/features/detail/variant_choice_dialog.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/platform/app_services.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';

import 'test_helpers.dart';

void main() {
  group('DetailPage', () {
    testWidgets(
      'renders Wayfinder hero, title, metadata, screenshots, and info cards',
      (tester) async {
        final entry = buildWayfinderEntry();
        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
        );

        expect(find.byType(DetailHeroBanner), findsOneWidget);
        expect(find.text('Wayfinder'), findsOneWidget);
        expect(find.text('Northstar Labs'), findsOneWidget);
        expect(find.text('Games'), findsOneWidget);
        expect(find.text('v3.2.0'), findsOneWidget);

        // Primary Install button with size.
        expect(find.text('Install'), findsOneWidget);
        expect(find.text('24.0 MB'), findsAtLeastNWidgets(1));

        // 4 screenshot thumbnails.
        expect(find.bySemanticsLabel('Screenshot 1'), findsOneWidget);
        expect(find.bySemanticsLabel('Screenshot 4'), findsOneWidget);

        // About, New in, Details cards.
        expect(find.text('ABOUT'), findsOneWidget);
        expect(
          find.text('Chart procedural handheld ruins on every expedition.'),
          findsOneWidget,
        );
        expect(find.text('NEW IN 3.2.0'), findsOneWidget);
        expect(
          find.text('New boss behaviour on depth 20'),
          findsOneWidget,
        );
        expect(find.text('DETAILS'), findsOneWidget);
        expect(find.text('24 Sep 2026'), findsOneWidget);
        expect(find.text('✓ Nothing special'), findsOneWidget);

        // Footer legend.
        expect(find.text('Select'), findsOneWidget);
        expect(find.text('Screenshots'), findsOneWidget);
        expect(find.text('Upstream page'), findsOneWidget);
        expect(find.text('Back'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'pressing [A] on Install enqueues download',
      (tester) async {
        final downloadCompleter = Completer<String>();
        final downloader = FakeApkDownloader(
          onDownload: (request) => downloadCompleter.future,
        );
        final entry = buildWayfinderEntry();
        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          downloader: downloader,
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(downloader.requests, hasLength(1));
        expect(
          downloader.requests.single.expectedSha256,
          entry.release!.variants.single.sha256,
        );
        expect(find.text('Downloading 0%'), findsOneWidget);

        downloadCompleter.complete('/tmp/wayfinder.apk');
        await tester.pump();
      },
    );

    testWidgets(
      'tapping Install enqueues download',
      (tester) async {
        final downloadCompleter = Completer<String>();
        final downloader = FakeApkDownloader(
          onDownload: (request) => downloadCompleter.future,
        );
        final entry = buildWayfinderEntry();
        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          downloader: downloader,
        );

        await tester.tap(find.text('Install'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(downloader.requests, hasLength(1));
        downloadCompleter.complete('/tmp/wayfinder.apk');
        await tester.pump();
      },
    );

    testWidgets(
      'shows Downloading <pct>% progress button',
      (tester) async {
        final entry = buildWayfinderEntry(
          featureUrl: null,
          screenshots: const <CatalogScreenshot>[],
        );
        final variant = entry.release!.variants.single;
        final queueState = InstallQueueState(
          tasks: <String, InstallTask>{
            entry.packageName: InstallTask(
              packageName: entry.packageName,
              appName: 'Wayfinder',
              variant: variant,
              intent: installIntentInstall,
              stage: InstallTaskStage.downloading,
              progress: 0.62,
              bytesReceived: (variant.sizeBytes * 0.62).round(),
              totalBytes: variant.sizeBytes,
            ),
          },
          order: <String>[entry.packageName],
        );

        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          initialQueueState: queueState,
        );

        expect(find.text('Downloading 62%'), findsOneWidget);
        expect(find.byType(DetailBackdropWash), findsOneWidget);
        expect(find.text('Screenshot'), findsNWidgets(4));
      },
    );

    testWidgets(
      'shows Ready · confirm in Library and tapping navigates to /library',
      (tester) async {
        final entry = buildWayfinderEntry();
        final variant = entry.release!.variants.single;
        final queueState = InstallQueueState(
          tasks: <String, InstallTask>{
            entry.packageName: InstallTask(
              packageName: entry.packageName,
              appName: 'Wayfinder',
              variant: variant,
              intent: installIntentInstall,
              stage: InstallTaskStage.awaitingConfirm,
              progress: 1,
              totalBytes: variant.sizeBytes,
              sessionId: 42,
            ),
          },
          order: <String>[entry.packageName],
        );

        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          initialQueueState: queueState,
        );

        expect(find.text('Ready · confirm in Library'), findsOneWidget);

        await tester.tap(find.text('Ready · confirm in Library'));
        await tester.pumpAndSettle();

        expect(find.text('Library Route'), findsOneWidget);
      },
    );

    testWidgets(
      'shows Open when installed and launches or uninstalls app',
      (tester) async {
        final entry = buildWayfinderEntry();
        final services = FakeAppServices(
          installedPackages: <InstalledPackage>[
            InstalledPackage(
              packageName: entry.packageName,
              versionCode: 320,
              signingSha256: 'aabbccdd',
            ),
          ],
        );

        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          services: services,
        );

        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Uninstall'), findsOneWidget);

        await tester.tap(find.text('Open'));
        await tester.pump();
        expect(services.openedPackages, <String>[entry.packageName]);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButtonStart);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.gameButtonStart);
        await tester.pump();
        expect(services.uninstalledPackages, <String>[entry.packageName]);
      },
    );

    testWidgets(
      'shows Open Settings when needsInstallPermission is true',
      (tester) async {
        final entry = buildWayfinderEntry();
        final variant = entry.release!.variants.single;
        final services = FakeAppServices(canRequestInstalls: false);
        final queueState = InstallQueueState(
          tasks: <String, InstallTask>{
            entry.packageName: InstallTask(
              packageName: entry.packageName,
              appName: 'Wayfinder',
              variant: variant,
              intent: installIntentInstall,
              stage: InstallTaskStage.failed,
              errorMessage: 'Permission needed',
              needsInstallPermission: true,
            ),
          },
          order: <String>[entry.packageName],
        );

        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          services: services,
          initialQueueState: queueState,
        );

        expect(find.text('Open Settings'), findsOneWidget);
        expect(
          find.text('Allow tShop to install unknown apps, then retry.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Open Settings'));
        await tester.pump();

        expect(services.openInstallPermissionSettingsCount, 1);
        // Failed task is dismissed so Install is ready upon return.
        expect(find.text('Install'), findsOneWidget);
      },
    );

    testWidgets(
      'shows Retry on failure and re-enqueues download when activated',
      (tester) async {
        final downloadCompleter = Completer<String>();
        final downloader = FakeApkDownloader(
          onDownload: (request) => downloadCompleter.future,
        );
        final entry = buildWayfinderEntry();
        final variant = entry.release!.variants.single;
        final queueState = InstallQueueState(
          tasks: <String, InstallTask>{
            entry.packageName: InstallTask(
              packageName: entry.packageName,
              appName: 'Wayfinder',
              variant: variant,
              intent: installIntentInstall,
              stage: InstallTaskStage.failed,
              errorMessage: 'Publisher host unreachable.',
            ),
          },
          order: <String>[entry.packageName],
        );

        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          downloader: downloader,
          initialQueueState: queueState,
        );

        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Publisher host unreachable.'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(downloader.requests, hasLength(1));
        downloadCompleter.complete('/tmp/wayfinder.apk');
        await tester.pump();
      },
    );

    testWidgets(
      'opens VariantChoiceDialog when variantsAreUserChoice is true and '
      'enqueues chosen variant',
      (tester) async {
        final downloadCompleter = Completer<String>();
        final downloader = FakeApkDownloader(
          onDownload: (request) => downloadCompleter.future,
        );
        final vulkanVariant = CatalogVariant(
          sha256: '1' * 64,
          sizeBytes: 16 * 1024 * 1024,
          abis: const <String>['arm64-v8a'],
          minSdk: 24,
          targetSdk: 35,
          label: LocalizedText(const <String, String>{'en': 'Vulkan renderer'}),
          note: LocalizedText(const <String, String>{
            'en': 'Faster on most current handhelds',
          }),
          upstreamUrl: 'https://wayfinder.example.com/vulkan.apk',
        );
        final glesVariant = CatalogVariant(
          sha256: '2' * 64,
          sizeBytes: 15 * 1024 * 1024,
          abis: const <String>['arm64-v8a'],
          minSdk: 24,
          targetSdk: 35,
          label: LocalizedText(const <String, String>{
            'en': 'OpenGL ES renderer',
          }),
          note: LocalizedText(const <String, String>{
            'en': 'For older or unusual GPU drivers',
          }),
          upstreamUrl: 'https://wayfinder.example.com/gles.apk',
        );
        final entry = buildWayfinderEntry(
          name: 'Flycast',
          variantsAreUserChoice: true,
          variants: <CatalogVariant>[vulkanVariant, glesVariant],
        );

        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          downloader: downloader,
        );

        // Press [A] on Install -> opens VariantChoiceDialog without queueing.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(find.byType(VariantChoiceDialog), findsOneWidget);
        expect(find.text('INSTALL FLYCAST'), findsOneWidget);
        expect(find.text('Which build?'), findsOneWidget);
        expect(find.text('Vulkan renderer'), findsOneWidget);
        expect(find.text('OpenGL ES renderer'), findsOneWidget);
        expect(downloader.requests, isEmpty);

        // Move Down to OpenGL ES renderer and press [A] to install it.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(VariantChoiceDialog), findsNothing);
        expect(downloader.requests, hasLength(1));
        expect(downloader.requests.single.expectedSha256, glesVariant.sha256);

        downloadCompleter.complete('/tmp/flycast-gles.apk');
        await tester.pump();
      },
    );

    testWidgets(
      'Down focuses screenshot strip and [A] opens ScreenshotViewerPage',
      (tester) async {
        final entry = buildWayfinderEntry();
        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
        );

        expect(find.text('Select'), findsOneWidget);

        // Down -> focuses screenshot 0, legend changes to View.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(find.text('View'), findsOneWidget);

        // Right -> focuses screenshot 1.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        // [A] -> pushes ScreenshotViewerPage at index 1 (2 / 4).
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(ScreenshotViewerPage), findsOneWidget);
        expect(find.text('2 / 4'), findsOneWidget);
      },
    );

    testWidgets(
      'shows unmet capability warning and [X] opens upstream URL',
      (tester) async {
        final entry = buildWayfinderEntry(
          capabilities: const <String>['vulkan-1.1'],
        );
        final harness = await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          capabilityTags: <CatalogCapabilityTag>[
            CatalogCapabilityTag(
              tag: 'vulkan-1.1',
              label: LocalizedText(const <String, String>{
                'en': 'Vulkan 1.1 GPU driver',
              }),
            ),
          ],
        );

        expect(
          find.text(
            "Needs Vulkan 1.1 GPU driver. This device doesn't report it.",
          ),
          findsOneWidget,
        );
        expect(find.text('✕ Vulkan 1.1 GPU driver'), findsOneWidget);

        // Press [X] -> launches homepageUrl.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyX);
        await tester.pump();

        expect(
          harness.launchedUrls,
          <Uri>[Uri.parse('https://wayfinder.example.com')],
        );
      },
    );

    testWidgets(
      'shows offline state and landing publisher CTA cleanly',
      (tester) async {
        final entry = buildWayfinderEntry();
        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          isOffline: true,
        );

        expect(find.text('Install when online'), findsOneWidget);
        expect(
          find.text(
            "You're offline. Browsing still works from the saved catalog.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'landing entry hides version tag and opens publisher URL',
      (tester) async {
        final entry = buildWayfinderEntry(
          rehostMode: RehostMode.landing,
          landing: CatalogLanding(
            reason: LocalizedText(const <String, String>{
              'en': 'Distributed directly by the publisher.',
            }),
            url: 'https://publisher.example.com/download',
          ),
        );
        final harness = await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
        );

        expect(find.byType(DetailPage), findsOneWidget);
        expect(find.text('v3.2.0'), findsNothing);
        expect(find.text('Go to Publisher'), findsOneWidget);
        expect(
          find.text('Distributed directly by the publisher.'),
          findsOneWidget,
        );
        expect(find.text('From the publisher'), findsOneWidget);

        await tester.tap(find.text('Go to Publisher'));
        await tester.pump();

        expect(
          harness.launchedUrls,
          <Uri>[Uri.parse('https://publisher.example.com/download')],
        );
      },
    );

    testWidgets(
      'shows Update to <ver> with installed version and otherSource CTA',
      (tester) async {
        final entry = buildWayfinderEntry();
        final services = FakeAppServices(
          installedPackages: <InstalledPackage>[
            InstalledPackage(
              packageName: entry.packageName,
              versionCode: 310,
              signingSha256: 'aabbccdd',
            ),
          ],
        );

        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          services: services,
        );

        expect(find.text('Update'), findsOneWidget);
        expect(find.text('to 3.2.0'), findsOneWidget);
        expect(find.text('Installed 3.1.0'), findsOneWidget);

        // Other-source signing cert shows uninstall guidance.
        final foreignServices = FakeAppServices(
          installedPackages: <InstalledPackage>[
            InstalledPackage(
              packageName: entry.packageName,
              versionCode: 320,
              signingSha256: 'deadbeef',
            ),
          ],
        );
        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          services: foreignServices,
        );

        expect(find.text('Installed from another source'), findsOneWidget);
        await tester.tap(find.text('Installed from another source'));
        await tester.pump();
        expect(foreignServices.uninstalledPackages, <String>[
          entry.packageName,
        ]);
      },
    );

    testWidgets(
      'renders compact square viewport in Night mode without overflow',
      (tester) async {
        final entry = buildWayfinderEntry();
        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          brightness: Brightness.dark,
          surfaceSize: const Size(640, 516),
        );

        expect(find.text('Wayfinder'), findsOneWidget);
        expect(find.text('ABOUT'), findsOneWidget);
        expect(find.text('DETAILS'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping actionable footer legend items launches upstream URL, triggers '
      'primary/view/uninstall actions, and pops back while Screenshots stays '
      'non-interactive',
      (tester) async {
        final entry = buildWayfinderEntry();
        final services = FakeAppServices(
          installedPackages: <InstalledPackage>[
            InstalledPackage(
              packageName: entry.packageName,
              versionCode: 320,
              signingSha256: 'aabbccdd',
            ),
          ],
        );
        final harness = await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/',
          services: services,
        );

        // Push DetailPage from Browse so [B] Back can pop cleanly.
        unawaited(harness.router.push('/app/${entry.packageName}'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final legendFinder = find.byType(TshopLegend);
        final screenshotsHint = tester.widget<TshopLegendHint>(
          find.ancestor(
            of: find.text('Screenshots'),
            matching: find.byType(TshopLegendHint),
          ),
        );
        expect(screenshotsHint.item.onTap, isNull);

        // Tap [X] Upstream page -> launches homepageUrl.
        await tester.tap(
          find.descendant(
            of: legendFinder,
            matching: find.text('Upstream page'),
          ),
        );
        await tester.pump();
        expect(
          harness.launchedUrls,
          <Uri>[Uri.parse('https://wayfinder.example.com')],
        );

        // Tap [A] Select -> activates primary Open action.
        await tester.tap(
          find.descendant(of: legendFinder, matching: find.text('Select')),
        );
        await tester.pump();
        expect(services.openedPackages, <String>[entry.packageName]);

        // Tap [+] Uninstall -> triggers uninstall.
        await tester.tap(
          find.descendant(of: legendFinder, matching: find.text('Uninstall')),
        );
        await tester.pump();
        expect(services.uninstalledPackages, <String>[entry.packageName]);

        // Focus first screenshot, then tap [A] View -> opens ScreenshotViewer.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.tap(
          find.descendant(of: legendFinder, matching: find.text('View')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(ScreenshotViewerPage), findsOneWidget);

        // Pop back to DetailPage, then tap [B] Back -> pops back to Browse.
        harness.router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        await tester.tap(
          find.descendant(of: legendFinder, matching: find.text('Back')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.text('Browse Route'), findsOneWidget);
      },
    );

    testWidgets(
      'VariantChoiceDialog footer legend [A] Install and [B] Cancel are '
      'tappable',
      (tester) async {
        final downloadCompleter = Completer<String>();
        final downloader = FakeApkDownloader(
          onDownload: (request) => downloadCompleter.future,
        );
        final vulkanVariant = CatalogVariant(
          sha256: '1' * 64,
          sizeBytes: 16 * 1024 * 1024,
          abis: const <String>['arm64-v8a'],
          minSdk: 24,
          targetSdk: 35,
          label: LocalizedText(const <String, String>{'en': 'Vulkan renderer'}),
          upstreamUrl: 'https://wayfinder.example.com/vulkan.apk',
        );
        final glesVariant = CatalogVariant(
          sha256: '2' * 64,
          sizeBytes: 15 * 1024 * 1024,
          abis: const <String>['arm64-v8a'],
          minSdk: 24,
          targetSdk: 35,
          label: LocalizedText(const <String, String>{
            'en': 'OpenGL ES renderer',
          }),
          upstreamUrl: 'https://wayfinder.example.com/gles.apk',
        );
        final entry = buildWayfinderEntry(
          name: 'Flycast',
          variantsAreUserChoice: true,
          variants: <CatalogVariant>[vulkanVariant, glesVariant],
        );

        await pumpDetailApp(
          tester,
          entries: <CatalogEntry>[entry],
          initialLocation: '/app/${entry.packageName}',
          downloader: downloader,
        );

        // Open dialog, then tap [B] Cancel in its legend.
        await tester.tap(find.text('Install'));
        await tester.pump();
        expect(find.byType(VariantChoiceDialog), findsOneWidget);

        final dialogLegend = find.descendant(
          of: find.byType(VariantChoiceDialog),
          matching: find.byType(TshopLegend),
        );
        await tester.tap(
          find.descendant(of: dialogLegend, matching: find.text('Cancel')),
        );
        await tester.pump();
        expect(find.byType(VariantChoiceDialog), findsNothing);
        expect(downloader.requests, isEmpty);

        // Re-open dialog, move down to second variant, tap [A] Install legend.
        await tester.tap(find.text('Install'));
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.tap(
          find.descendant(of: dialogLegend, matching: find.text('Install')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(VariantChoiceDialog), findsNothing);
        expect(downloader.requests, hasLength(1));
        expect(downloader.requests.single.expectedSha256, glesVariant.sha256);

        downloadCompleter.complete('/tmp/flycast-gles.apk');
        await tester.pump();
      },
    );
  });
}
