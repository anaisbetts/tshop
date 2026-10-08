import 'package:flutter/material.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';

/// A physical control on the handheld.
enum PadButton {
  /// Face button A (confirm).
  a('A'),

  /// Face button B (back).
  b('B'),

  /// Face button X.
  x('X'),

  /// Face button Y.
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

  /// Letter drawn in the glyph.
  final String label;
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
  });

  /// Which control to draw.
  final PadButton button;

  /// Glyph height in dp.
  final double size;

  /// Background override (e.g. white inside a primary button).
  final Color? fill;

  /// Letter colour override.
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    if (button == PadButton.dpad) {
      return CustomPaint(
        size: Size.square(size),
        painter: _DpadPainter(fill ?? tokens.padNeutral),
      );
    }
    final (background, foreground) = _colours(tokens);
    final isFace = switch (button) {
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
          button.label,
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

  (Color, Color) _colours(TshopTokens tokens) {
    switch (button) {
      case PadButton.a:
        return (TshopBrand.padA, Colors.white);
      case PadButton.b:
        return (TshopBrand.padB, TshopBrand.padBInk);
      case PadButton.x:
        return (TshopBrand.padX, Colors.white);
      case PadButton.y:
        return (TshopBrand.padY, Colors.white);
      case PadButton.l:
      case PadButton.r:
      case PadButton.plus:
      case PadButton.dpad:
        return (tokens.padNeutral, Colors.white);
    }
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
