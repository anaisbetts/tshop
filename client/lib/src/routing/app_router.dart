import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/features/browse/browse_page.dart';
import 'package:tshop/src/features/detail/detail_page.dart';
import 'package:tshop/src/features/detail/screenshot_viewer_page.dart';
import 'package:tshop/src/features/library/library_page.dart';
import 'package:tshop/src/gallery/theme_gallery_page.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/input/gamepad_scope.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/routing/app_routes.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_button.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';
import 'package:tshop/src/theme/widgets/tshop_surfaces.dart';
import 'package:tshop/src/theme/widgets/tshop_wallpaper.dart';

const String _libraryPath = '/library';
const String _settingsPath = '/settings';
const String _detailPath = '/app/:packageName';
const String _screenshotsPath = '/app/:packageName/screenshots/:index';
const double _settingsCardMaxWidth = 620;

/// App [GoRouter] with a Talker navigator observer.
final appRouterProvider = Provider<GoRouter>((ref) {
  final talker = ref.watch(talkerProvider);
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    observers: [TalkerRouteObserver(talker)],
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'browse',
        builder: (context, state) => const BrowsePage(),
      ),
      GoRoute(
        path: _libraryPath,
        name: 'library',
        builder: (context, state) => const LibraryPage(),
      ),
      GoRoute(
        path: _settingsPath,
        name: 'settings',
        builder: (context, state) => const SettingsStubPage(),
      ),
      GoRoute(
        path: AppRoutes.gallery,
        name: 'gallery',
        builder: (context, state) => const ThemeGalleryPage(),
      ),
      GoRoute(
        path: _detailPath,
        name: 'detail',
        builder: (context, state) => DetailPage(
          packageName: state.pathParameters['packageName']!,
        ),
      ),
      GoRoute(
        path: _screenshotsPath,
        name: 'screenshots',
        builder: (context, state) => ScreenshotViewerPage(
          packageName: state.pathParameters['packageName']!,
          initialIndex: int.tryParse(state.pathParameters['index'] ?? '0') ?? 0,
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Lightweight Settings stub displaying the active catalog origin and a
/// shortcut to the Theme Gallery.
class SettingsStubPage extends ConsumerWidget {
  /// Creates the Settings stub page.
  const SettingsStubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tshopConfigProvider);
    final libraryCount = ref.watch(libraryBadgeCountProvider);
    final isOnline = ref.watch(
      catalogProvider.select(
        (asyncState) => asyncState.value != null
            ? !asyncState.value!.isOffline
            : !asyncState.hasError,
      ),
    );

    void openGallery() {
      unawaited(context.push(AppRoutes.gallery));
    }

    void handleAction(GamepadAction action) {
      switch (action) {
        case GamepadAction.tabPrev:
          context.go(_libraryPath);
        case GamepadAction.tabNext:
          context.go(AppRoutes.home);
        case GamepadAction.confirm:
          openGallery();
        case GamepadAction.up:
        case GamepadAction.down:
        case GamepadAction.left:
        case GamepadAction.right:
        case GamepadAction.back:
        case GamepadAction.secondary:
        case GamepadAction.searchOrRetry:
        case GamepadAction.menu:
          break;
      }
    }

    return TshopGamepadScope(
      onAction: handleAction,
      child: Scaffold(
        body: TshopWallpaper(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  TshopTopBar(
                    destination: TshopDestination.settings,
                    libraryCount: libraryCount,
                    online: isOnline,
                    onDestination: (dest) =>
                        _navigateToDestination(context, dest),
                  ),
                  const TshopInfoStrip(
                    title: 'Settings',
                    summary: 'Catalog configuration and developer tools.',
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _settingsCardMaxWidth,
                          ),
                          child: TshopCard(
                            heading: 'Catalog',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              spacing: 12,
                              children: [
                                TshopFacts(<(String, String)>[
                                  (
                                    'Catalog URL',
                                    config.catalogBaseUrl.toString(),
                                  ),
                                ]),
                                TshopButton(
                                  label: 'Open Theme Gallery',
                                  focused: true,
                                  onPressed: openGallery,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  TshopLegend(
                    left: <LegendItem>[
                      LegendItem(
                        button: PadButton.a,
                        label: 'Open',
                        onTap: openGallery,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _navigateToDestination(
  BuildContext context,
  TshopDestination destination,
) {
  switch (destination) {
    case TshopDestination.browse:
      context.go(AppRoutes.home);
    case TshopDestination.library:
      context.go(_libraryPath);
    case TshopDestination.settings:
      context.go(_settingsPath);
  }
}
