import 'package:flutter/material.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';

/// Colour role of a [TshopChip].
enum TshopChipTone {
  /// Neutral: category, size.
  plain,

  /// Green: Installed, ready to confirm.
  good,

  /// Orange: Update, downloading.
  accent,

  /// Red: failed, missing hardware.
  bad,
}

/// Small pill that states a fact about the focused app.
class TshopChip extends StatelessWidget {
  /// Creates a chip.
  const TshopChip(this.label, {super.key, this.tone = TshopChipTone.plain});

  /// Chip text.
  final String label;

  /// Colour role.
  final TshopChipTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final (fill, ink) = switch (tone) {
      TshopChipTone.plain => (tokens.chip, tokens.ink2),
      TshopChipTone.good => (
        TshopBrand.good.withValues(alpha: 0.14),
        tokens.goodInk,
      ),
      TshopChipTone.accent => (
        TshopBrand.accent.withValues(alpha: 0.16),
        tokens.accentInk,
      ),
      TshopChipTone.bad => (
        TshopBrand.bad.withValues(alpha: 0.14),
        tokens.badInk,
      ),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ink),
        ),
      ),
    );
  }
}

/// Orange count bubble, e.g. on the Library tab.
class TshopCountBadge extends StatelessWidget {
  /// Creates a badge showing [count].
  const TshopCountBadge(this.count, {super.key});

  /// Number to show.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: TshopBrand.accent,
        borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          '$count',
          style: const TextStyle(
            color: TshopBrand.accentInk,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}
