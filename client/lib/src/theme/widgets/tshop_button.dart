import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';

/// Visual role of a [TshopButton].
enum TshopButtonTone {
  /// Orange: Install, Update, Go to Publisher.
  primary,

  /// Green: Open.
  open,

  /// Red: Retry.
  retry,

  /// Card-coloured: Installed from another source.
  quiet,

  /// Card-coloured and muted: Install when online.
  disabled,

  /// No fill: secondary actions.
  ghost,
}

/// Pill button with a leading [PadGlyph], as on Detail.
class TshopButton extends HookWidget {
  /// Creates a button.
  const TshopButton({
    required this.label,
    super.key,
    this.sub,
    this.pad = PadButton.a,
    this.tone = TshopButtonTone.primary,
    this.small = false,
    this.focused = false,
    this.onPressed,
  });

  /// Main label.
  final String label;

  /// Muted trailing detail, e.g. size or target version.
  final String? sub;

  /// Glyph shown before the label; null for none.
  final PadButton? pad;

  /// Colour role.
  final TshopButtonTone tone;

  /// 26 dp tall compact variant.
  final bool small;

  /// Whether the d-pad cursor is on this button.
  final bool focused;

  /// Called on tap / A. Ignored for [TshopButtonTone.disabled].
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final pressed = useState(false);
    final style = _ToneStyle.of(tone, tokens);
    final enabled = tone != TshopButtonTone.disabled && onPressed != null;
    final fontSize = small ? 12.0 : 14.0;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: small ? 6 : 8,
      children: [
        if (pad != null)
          PadGlyph(
            pad!,
            size: small ? 16 : 18,
            fill: style.padFill,
            ink: style.padInk,
          ),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: style.ink,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (sub != null)
          Opacity(
            opacity: 0.75,
            child: Text(
              sub!,
              maxLines: 1,
              style: TextStyle(
                color: style.ink,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      selected: focused,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTapDown: enabled ? (_) => pressed.value = true : null,
          onTapUp: enabled ? (_) => pressed.value = false : null,
          onTapCancel: enabled ? () => pressed.value = false : null,
          onTap: enabled ? onPressed : null,
          child: AnimatedScale(
            scale: pressed.value ? 0.97 : (focused ? 1.04 : 1),
            duration: const Duration(milliseconds: 120),
            child: Container(
              height: small ? 26 : 40,
              constraints: BoxConstraints(minWidth: small ? 0 : 132),
              padding: pad == null
                  ? EdgeInsets.symmetric(horizontal: small ? 10 : 18)
                  : EdgeInsets.only(
                      left: small ? 5 : 12,
                      right: small ? 10 : 18,
                    ),
              decoration: BoxDecoration(
                color: style.fill,
                borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
                boxShadow: focused ? tokens.focusRing() : style.shadow,
              ),
              child: Center(widthFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark pill that fills with orange while a download runs.
class TshopProgressButton extends StatelessWidget {
  /// Creates a progress button.
  const TshopProgressButton({
    required this.value,
    required this.label,
    super.key,
    this.focused = false,
  });

  /// 0–1 fill.
  final double value;

  /// e.g. "Downloading 62%".
  final String label;

  /// Whether the d-pad cursor is on this button.
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final radius = BorderRadius.circular(TshopMetrics.pillRadius);
    return Semantics(
      label: label,
      value: '${(value * 100).round()}%',
      child: AnimatedScale(
        scale: focused ? 1.04 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 40,
          constraints: const BoxConstraints(minWidth: 132),
          decoration: BoxDecoration(
            color: tokens.ink,
            borderRadius: radius,
            boxShadow: focused ? tokens.focusRing() : tokens.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0, 1),
                    child: const ColoredBox(color: TshopBrand.accent),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.card,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
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

class _ToneStyle {
  const _ToneStyle({
    required this.fill,
    required this.ink,
    required this.shadow,
    this.padFill,
    this.padInk,
  });

  factory _ToneStyle.of(TshopButtonTone tone, TshopTokens tokens) {
    switch (tone) {
      case TshopButtonTone.primary:
        return _ToneStyle.raised(TshopBrand.accent, TshopBrand.accentSoft);
      case TshopButtonTone.open:
        return _ToneStyle.raised(TshopBrand.good, const Color(0x4D22B573));
      case TshopButtonTone.retry:
        return _ToneStyle.raised(TshopBrand.bad, const Color(0x4DEC4D4D));
      case TshopButtonTone.quiet:
        return _ToneStyle(
          fill: tokens.card,
          ink: tokens.ink,
          shadow: tokens.cardShadow,
        );
      case TshopButtonTone.disabled:
        return _ToneStyle(
          fill: tokens.card,
          ink: tokens.ink3,
          shadow: tokens.cardShadow,
          padFill: tokens.chip,
          padInk: tokens.ink3,
        );
      case TshopButtonTone.ghost:
        return _ToneStyle(
          fill: Colors.transparent,
          ink: tokens.ink2,
          shadow: const [],
        );
    }
  }

  factory _ToneStyle.raised(Color fill, Color glow) => _ToneStyle(
    fill: fill,
    ink: TshopBrand.accentInk,
    shadow: [
      BoxShadow(color: glow, offset: const Offset(0, 4), blurRadius: 12),
    ],
    padFill: const Color(0xF2FFFFFF),
    padInk: fill,
  );

  final Color fill;
  final Color ink;
  final List<BoxShadow> shadow;
  final Color? padFill;
  final Color? padInk;
}
