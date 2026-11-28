import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';

/// A physical control on the handheld.
///
/// Face-button names are semantic Xbox/Android slots (`a` is confirm). [PadGlyph]
/// remaps the printed letter to the active [PadButtonLayout].
enum PadButton {
  /// Confirm / OK.
  a('A'),

  /// Back / cancel.
  b('B'),

  /// Secondary contextual action.
  x('X'),

  /// Search / retry.
  y('Y'),

  /// Left shoulder.
  l('L'),

  /// Right shoulder.
  r('R'),

  /// Start / plus.
  plus('+'),

  /// Directional pad.
  dpad('');

  const PadButton(this.label);

  /// Xbox/Android letter for this slot. Prefer [visualPadButton] for HUD text.
  final String label;
}

/// Provides the active [PadButtonLayout] to [PadGlyph]s below.
class PadLayoutScope extends InheritedWidget {
  /// Creates a layout scope. Defaults to Nintendo when no scope is present.
  const PadLayoutScope({
    required this.layout,
    required super.child,
    super.key,
  });

  /// Active glyph layout.
  final PadButtonLayout layout;

  /// Layout from the nearest scope, or Nintendo when absent.
  static PadButtonLayout of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PadLayoutScope>()
            ?.layout ??
        PadButtonLayout.nintendo;
  }

  @override
  bool updateShouldNotify(PadLayoutScope oldWidget) =>
      layout != oldWidget.layout;
}

/// Coloured controller glyph used in legends, buttons and the top bar.
class PadGlyph extends StatelessWidget {
  /// Creates a glyph. [fill] and [ink] override the default face colours.
  const PadGlyph(
    this.button, {
    super.key,
    this.size = 18,
    this.fill,
    this.ink,
    this.layout,
  });

  /// Which control to draw (semantic Xbox/Android slot).
  final PadButton button;

  /// Glyph height in dp.
  final double size;

  /// Background override (e.g. white inside a primary button).
  final Color? fill;

  /// Letter colour override.
  final Color? ink;

  /// Layout override. When null, uses [PadLayoutScope] (Nintendo by default).
  final PadButtonLayout? layout;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    if (button == PadButton.dpad) {
      return CustomPaint(
        size: Size.square(size),
        painter: _DpadPainter(fill ?? tokens.padNeutral),
      );
    }
    final visual = visualPadButton(
      button,
      layout ?? PadLayoutScope.of(context),
    );
    final (background, foreground) = _colours(visual, tokens);
    final isFace = switch (visual) {
      PadButton.a || PadButton.b || PadButton.x || PadButton.y => true,
      PadButton.l || PadButton.r || PadButton.plus || PadButton.dpad => false,
    };
    return Container(
      height: size,
      constraints: BoxConstraints(minWidth: size),
      width: isFace ? size : null,
      padding: isFace ? null : EdgeInsets.symmetric(horizontal: size * 0.28),
      decoration: BoxDecoration(
        color: fill ?? background,
        borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          visual.label,
          style: TextStyle(
            color: ink ?? foreground,
            fontSize: size * 0.56,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Maps a semantic [PadButton] to the letter printed on the handheld.
///
/// Nintendo / AYN Thor: B confirms, A cancels, Y is left, X is top.
/// Xbox: A confirms, B cancels, X is left, Y is top.
PadButton visualPadButton(PadButton button, PadButtonLayout layout) {
  switch (layout) {
    case PadButtonLayout.xbox:
      return button;
    case PadButtonLayout.nintendo:
      return switch (button) {
        PadButton.a => PadButton.b,
        PadButton.b => PadButton.a,
        PadButton.x => PadButton.y,
        PadButton.y => PadButton.x,
        PadButton.l ||
        PadButton.r ||
        PadButton.plus ||
        PadButton.dpad => button,
      };
  }
}

(Color, Color) _colours(PadButton button, TshopTokens tokens) {
  switch (button) {
    case PadButton.a:
      return (TshopBrand.padA, Colors.white);
    case PadButton.b:
      return (TshopBrand.padB, Colors.white);
    case PadButton.x:
      return (TshopBrand.padX, TshopBrand.padXInk);
    case PadButton.y:
      return (TshopBrand.padY, Colors.white);
    case PadButton.l:
    case PadButton.r:
    case PadButton.plus:
    case PadButton.dpad:
      return (tokens.padNeutral, Colors.white);
  }
}

class _DpadPainter extends CustomPainter {
  _DpadPainter(this.fill);

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 18;
    final cross = Path()
      ..moveTo(6.5 * u, 1.5 * u)
      ..lineTo(11.5 * u, 1.5 * u)
      ..lineTo(11.5 * u, 6.5 * u)
      ..lineTo(16.5 * u, 6.5 * u)
      ..lineTo(16.5 * u, 11.5 * u)
      ..lineTo(11.5 * u, 11.5 * u)
      ..lineTo(11.5 * u, 16.5 * u)
      ..lineTo(6.5 * u, 16.5 * u)
      ..lineTo(6.5 * u, 11.5 * u)
      ..lineTo(1.5 * u, 11.5 * u)
      ..lineTo(1.5 * u, 6.5 * u)
      ..lineTo(6.5 * u, 6.5 * u)
      ..close();
    canvas
      ..drawPath(cross, Paint()..color = fill)
      ..drawPath(
        cross,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = u
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(
        Offset(9 * u, 9 * u),
        1.6 * u,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
  }

  @override
  bool shouldRepaint(_DpadPainter oldDelegate) => oldDelegate.fill != fill;
}
