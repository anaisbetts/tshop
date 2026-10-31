import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';

/// Cool pinstriped wallpaper behind every screen.
class TshopWallpaper extends StatelessWidget {
  /// Paints the wallpaper behind [child].
  const TshopWallpaper({required this.child, super.key});

  /// Screen content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: tokens.wallpaper),
      child: CustomPaint(
        painter: _PinstripePainter(tokens.wallStripe),
        child: child,
      ),
    );
  }
}

/// 2 dp stripes every 9 dp at 135°, like the CSS `repeating-linear-gradient`.
class _PinstripePainter extends CustomPainter {
  _PinstripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const step = 9 * math.sqrt2;
    for (var c = 0.0; c < size.width + size.height; c += step) {
      canvas.drawLine(Offset(c, 0), Offset(0, c), paint);
    }
  }

  @override
  bool shouldRepaint(_PinstripePainter oldDelegate) =>
      oldDelegate.color != color;
}
