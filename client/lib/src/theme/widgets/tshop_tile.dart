import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/focus_breath.dart';

const _tileShadow = [
  BoxShadow(color: Color(0x29141C30), offset: Offset(0, 3), blurRadius: 8),
];

/// Glossy top sheen every tile shares: the one 3DS-ism.
const tileSheen = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x38FFFFFF), Color(0x0AFFFFFF), Color(0x00FFFFFF)],
  stops: [0, 0.46, 0.47],
);

/// What the client knows about one package on this device.
enum TileStatus {
  /// In the catalog, not installed.
  available,

  /// Installed and current.
  installed,

  /// Installed, newer version in the catalog.
  update,

  /// Download in progress.
  downloading,

  /// Downloaded; waiting for the Android install prompt.
  confirm,

  /// Download or install failed.
  failed,

  /// Installed but signed by someone else.
  otherSource,
}

/// Where a tile is shown. Library hides marks its frames already convey.
enum TileContext {
  /// Browse shelves.
  browse,

  /// Library frames.
  library,
}

/// Unlabelled square app tile with a status mark, focus ring and lift.
class TshopTile extends HookWidget {
  /// Creates a tile.
  const TshopTile({
    required this.icon,
    required this.backdrop,
    super.key,
    this.iconScale = 1,
    this.status = TileStatus.available,
    this.context = TileContext.browse,
    this.progress = 0,
    this.needsHardware = false,
    this.focused = false,
    this.size = TshopMetrics.tile,
    this.radius = TshopMetrics.tileRadius,
    this.semanticLabel,
    this.onTap,
  });

  /// App icon art.
  final ImageProvider icon;

  /// Square backdrop behind the icon.
  final Gradient backdrop;

  /// >1 crops an icon's own rounded corners.
  final double iconScale;

  /// Install state.
  final TileStatus status;

  /// Browse or Library.
  final TileContext context;

  /// 0–1, used while [TileStatus.downloading].
  final double progress;

  /// The device doesn't report something this app requires.
  final bool needsHardware;

  /// Whether the d-pad cursor is on this tile.
  final bool focused;

  /// Edge length in dp.
  final double size;

  /// Corner radius in dp.
  final double radius;

  /// App name for screen readers.
  final String? semanticLabel;

  /// Called on tap / A.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final breath = useFocusBreath(focused: focused);
    final dim =
        needsHardware ||
        (this.context == TileContext.library &&
            status == TileStatus.otherSource);
    final busy =
        status == TileStatus.downloading || status == TileStatus.confirm;
    final borderRadius = BorderRadius.circular(radius);

    Widget art = Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scale: iconScale,
          child: Image(image: icon, fit: BoxFit.contain),
        ),
        const DecoratedBox(decoration: BoxDecoration(gradient: tileSheen)),
      ],
    );
    if (dim) {
      art = Opacity(
        opacity: 0.42,
        child: ColorFiltered(
          colorFilter: _saturate(0),
          child: art,
        ),
      );
    } else if (busy) {
      art = ColorFiltered(colorFilter: _saturate(0.7, 0.82), child: art);
    }

    return Semantics(
      button: true,
      selected: focused,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedSlide(
          offset: Offset(0, focused ? -2 / size : 0),
          duration: const Duration(milliseconds: 120),
          curve: focusLiftCurve,
          child: AnimatedScale(
            scale: focused ? 1.07 : 1,
            duration: const Duration(milliseconds: 120),
            curve: focusLiftCurve,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: breath,
                      builder: (context, child) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: backdrop,
                          borderRadius: borderRadius,
                          boxShadow: focused
                              ? tokens.focusRing(breath: breath.value)
                              : _tileShadow,
                        ),
                        child: child,
                      ),
                      child: ClipRRect(borderRadius: borderRadius, child: art),
                    ),
                  ),
                  ..._overlay(tokens),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _overlay(TshopTokens tokens) {
    switch (status) {
      case TileStatus.available:
        return const [];
      case TileStatus.installed:
        return context == TileContext.library
            ? const []
            : [_mark(tokens, _Mark.installed)];
      case TileStatus.update:
        return [_mark(tokens, _Mark.update)];
      case TileStatus.downloading:
        return [_TileProgress(value: progress)];
      case TileStatus.confirm:
        return const [_TileProgress(value: 1, done: true)];
      case TileStatus.failed:
        return [_mark(tokens, _Mark.failed)];
      case TileStatus.otherSource:
        return context == TileContext.library
            ? const []
            : [_mark(tokens, _Mark.foreign)];
    }
  }

  Widget _mark(TshopTokens tokens, _Mark kind) {
    final (color, glyph, topRight) = switch (kind) {
      _Mark.installed => (TshopBrand.good, Icons.check_rounded, false),
      _Mark.foreign => (tokens.ink3, Icons.check_rounded, false),
      _Mark.update => (TshopBrand.accent, Icons.arrow_upward_rounded, true),
      _Mark.failed => (TshopBrand.bad, Icons.priority_high_rounded, true),
    };
    final badge = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          const BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
          BoxShadow(color: tokens.focusGap, spreadRadius: 2),
        ],
      ),
      child: Icon(glyph, size: 14, color: Colors.white),
    );
    return topRight
        ? Positioned(top: -5, right: -5, child: badge)
        : Positioned(bottom: -4, right: -4, child: badge);
  }
}

/// Square orange tile for an action that lives in the grid (Update All).
class TshopActionTile extends HookWidget {
  /// Creates an action tile.
  const TshopActionTile({
    required this.icon,
    required this.label,
    super.key,
    this.focused = false,
    this.size = TshopMetrics.tile,
    this.onTap,
  });

  /// Glyph above the label.
  final IconData icon;

  /// Short label, e.g. "Update All".
  final String label;

  /// Whether the d-pad cursor is on this tile.
  final bool focused;

  /// Edge length in dp.
  final double size;

  /// Called on tap / A.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final breath = useFocusBreath(focused: focused);
    final borderRadius = BorderRadius.circular(TshopMetrics.tileRadius);
    return Semantics(
      button: true,
      selected: focused,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: focused ? 1.07 : 1,
          duration: const Duration(milliseconds: 120),
          curve: focusLiftCurve,
          child: AnimatedBuilder(
            animation: breath,
            builder: (context, child) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: TshopBrand.accentGradient,
                borderRadius: borderRadius,
                boxShadow: focused
                    ? tokens.focusRing(breath: breath.value)
                    : _tileShadow,
              ),
              foregroundDecoration: BoxDecoration(
                gradient: tileSheen,
                borderRadius: borderRadius,
              ),
              child: child,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                Icon(icon, size: 30, color: Colors.white),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Mark { installed, foreign, update, failed }

class _TileProgress extends StatelessWidget {
  const _TileProgress({required this.value, this.done = false});

  final double value;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      height: 7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x8C0A0E18),
          borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
          border: Border.all(
            color: const Color(0xD9FFFFFF),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              heightFactor: 1,
              child: ColoredBox(
                color: done ? TshopBrand.good : TshopBrand.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CSS `saturate(s) brightness(b)` as a colour matrix.
ColorFilter _saturate(double s, [double b = 1]) {
  return ColorFilter.matrix([
    (0.213 + 0.787 * s) * b,
    (0.715 - 0.715 * s) * b,
    (0.072 - 0.072 * s) * b,
    0,
    0, //
    (0.213 - 0.213 * s) * b,
    (0.715 + 0.285 * s) * b,
    (0.072 - 0.072 * s) * b,
    0,
    0, //
    (0.213 - 0.213 * s) * b,
    (0.715 - 0.715 * s) * b,
    (0.072 + 0.928 * s) * b,
    0,
    0, //
    0, 0, 0, 1, 0,
  ]);
}
