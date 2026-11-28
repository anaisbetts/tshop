import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/images/app_image_cache.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/input/gamepad_scope.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';

const Color _viewerBackground = Color(0xFF05070B);
const Color _blurDimColor = Color(0x73000000);
const Color _dayPillBackground = Color(0xD1FFFFFF);
const Color _nightPillBackground = Color(0xC7181B24);
const Color _arrowFill = Color(0xD1FFFFFF);
const Color _dotsBackground = Color(0x730A0E18);
const Color _dotInactiveColor = Color(0x73FFFFFF);
const double _blurSigma = 36;
const double _pillBlurSigma = 14;
const double _swipeVelocityThreshold = 200;
const String _defaultStatusTime = '9:41';

const BoxShadow _arrowShadow = BoxShadow(
  color: Color(0x59000000),
  offset: Offset(0, 4),
  blurRadius: 14,
);

/// Fullscreen screenshot viewer opened from the app detail screen.
///
/// Supports paging via `[L]`/`[R]`, D-pad Left/Right, circular edge buttons,
/// dot indicators, and horizontal swipes; `[B]` returns to Detail.
class ScreenshotViewerPage extends HookConsumerWidget {
  /// Creates a screenshot viewer for [packageName] starting at [initialIndex].
  const ScreenshotViewerPage({
    required this.packageName,
    required this.initialIndex,
    super.key,
    this.time = _defaultStatusTime,
  });

  /// Android package name of the catalog entry whose screenshots are shown.
  final String packageName;

  /// Initial zero-based screenshot index (clamped to valid bounds).
  final int initialIndex;

  /// Clock label shown in the floating status pill.
  final String time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(catalogEntryProvider(packageName));
    final isOffline = ref.watch(
      catalogProvider.select(
        (asyncState) => asyncState.value?.isOffline ?? false,
      ),
    );
    final cacheManager = ref.watch(imageCacheProvider);

    final shots = entry?.screenshots ?? const <CatalogScreenshot>[];
    final selectedIndex = useState<int?>(null);

    final activeIndex = shots.isEmpty
        ? 0
        : (selectedIndex.value ?? initialIndex).clamp(0, shots.length - 1);

    void page(int step) {
      if (shots.isEmpty) {
        return;
      }
      selectedIndex.value = (activeIndex + step).clamp(0, shots.length - 1);
    }

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/app/$packageName');
      }
    }

    void handleAction(GamepadAction action) {
      switch (action) {
        case GamepadAction.left:
        case GamepadAction.tabPrev:
          page(-1);
        case GamepadAction.right:
        case GamepadAction.tabNext:
          page(1);
        case GamepadAction.back:
          goBack();
        case GamepadAction.up:
        case GamepadAction.down:
        case GamepadAction.confirm:
        case GamepadAction.secondary:
        case GamepadAction.searchOrRetry:
        case GamepadAction.menu:
          break;
      }
    }

    final appName = entry?.name.resolve() ?? packageName;
    final activeShot = shots.isEmpty ? null : shots[activeIndex];
    final canPrev = activeIndex > 0;
    final canNext = shots.isNotEmpty && activeIndex < shots.length - 1;
    final countText = shots.isEmpty
        ? '0 / 0'
        : '${activeIndex + 1} / ${shots.length}';

    return TshopGamepadScope(
      onAction: handleAction,
      child: Scaffold(
        backgroundColor: _viewerBackground,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -_swipeVelocityThreshold) {
              page(1);
            } else if (velocity > _swipeVelocityThreshold) {
              page(-1);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (activeShot != null)
                _BlurredBackdrop(
                  imageUrl: activeShot.fullUrl,
                  cacheManager: cacheManager,
                ),
              if (activeShot != null)
                Positioned.fill(
                  child: Semantics(
                    image: true,
                    label: '$appName screenshot ${activeIndex + 1}',
                    child: CachedNetworkImage(
                      key: ValueKey<String>(activeShot.fullUrl),
                      imageUrl: activeShot.fullUrl,
                      cacheManager: cacheManager,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox.shrink(),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Center(
                  child: Text(
                    'No screenshots available',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: _ViewerFrostedPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 10,
                          children: [
                            Flexible(
                              child: Text(
                                appName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: context.tshop.ink,
                                    ),
                              ),
                            ),
                            Text(
                              countText,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: context.tshop.ink3,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ViewerFrostedPill(
                      horizontalPadding: 10,
                      child: _ViewerStatusCluster(
                        online: !isOffline,
                        time: time,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ViewerArrowButton(
                    button: PadButton.l,
                    semanticLabel: 'Previous screenshot',
                    enabled: canPrev,
                    onTap: () => page(-1),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ViewerArrowButton(
                    button: PadButton.r,
                    semanticLabel: 'Next screenshot',
                    enabled: canNext,
                    onTap: () => page(1),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (shots.isNotEmpty)
                      _ViewerDotPager(
                        count: shots.length,
                        activeIndex: activeIndex,
                        onSelect: (index) => selectedIndex.value = index,
                      )
                    else
                      const SizedBox.shrink(),
                    _ViewerFrostedPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          const TshopLegendHint(
                            item: LegendItem(
                              button: PadButton.dpad,
                              label: 'Page',
                            ),
                          ),
                          TshopLegendHint(
                            item: LegendItem(
                              button: PadButton.b,
                              label: 'Back',
                              onTap: goBack,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlurredBackdrop extends StatelessWidget {
  const _BlurredBackdrop({
    required this.imageUrl,
    required this.cacheManager,
  });

  final String imageUrl;
  final BaseCacheManager cacheManager;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: Transform.scale(
          scale: 1.18,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _blurSigma,
              sigmaY: _blurSigma,
            ),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                _blurDimColor,
                BlendMode.darken,
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                cacheManager: cacheManager,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const ColoredBox(color: _viewerBackground),
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: _viewerBackground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerFrostedPill extends StatelessWidget {
  const _ViewerFrostedPill({
    required this.child,
    this.horizontalPadding = 12,
  });

  final Widget child;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final radius = BorderRadius.circular(TshopMetrics.pillRadius);
    final background = tokens.brightness == Brightness.dark
        ? _nightPillBackground
        : _dayPillBackground;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.shelfShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _pillBlurSigma,
            sigmaY: _pillBlurSigma,
          ),
          child: Container(
            height: 32,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            alignment: Alignment.center,
            color: background,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ViewerStatusCluster extends StatelessWidget {
  const _ViewerStatusCluster({
    required this.online,
    required this.time,
  });

  final bool online;
  final String time;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final style = Theme.of(context).textTheme.labelMedium;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        TshopWifiGlyph(online: online),
        Text(
          time,
          style: style?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        CustomPaint(
          size: const Size(22, 12),
          painter: _ViewerBatteryPainter(tokens.ink2),
        ),
      ],
    );
  }
}

class _ViewerArrowButton extends StatelessWidget {
  const _ViewerArrowButton({
    required this.button,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final PadButton button;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.25,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _arrowFill,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[_arrowShadow],
              ),
              child: PadGlyph(button),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerDotPager extends StatelessWidget {
  const _ViewerDotPager({
    required this.count,
    required this.activeIndex,
    required this.onSelect,
  });

  final int count;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final pillRadius = BorderRadius.circular(TshopMetrics.pillRadius);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _dotsBackground,
        borderRadius: pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          for (var i = 0; i < count; i++)
            GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                key: ValueKey<String>('viewer-dot-$i'),
                duration: const Duration(milliseconds: 140),
                width: i == activeIndex ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == activeIndex
                      ? TshopBrand.accent
                      : _dotInactiveColor,
                  borderRadius: pillRadius,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewerBatteryPainter extends CustomPainter {
  _ViewerBatteryPainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = ink;
    canvas
      ..drawRRect(
        RRect.fromLTRBR(0.75, 1.25, 18.75, 10.75, const Radius.circular(3)),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawRRect(
        RRect.fromLTRBR(19.5, 4, 21.5, 8, const Radius.circular(1)),
        fill,
      )
      ..drawRRect(
        RRect.fromLTRBR(3, 3.5, 14, 8.5, const Radius.circular(1.5)),
        fill,
      );
  }

  @override
  bool shouldRepaint(_ViewerBatteryPainter oldDelegate) =>
      oldDelegate.ink != ink;
}
