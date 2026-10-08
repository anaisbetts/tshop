import 'package:flutter/material.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/tshop_chip.dart';

/// Frosted shelf panel: a labelled, column-major grid of tiles.
class TshopFrame extends StatelessWidget {
  /// Creates a frame. [count] defaults to the number of [tiles].
  const TshopFrame({
    required this.label,
    required this.tiles,
    super.key,
    this.count,
    this.rows = 3,
    this.tileSize = TshopMetrics.tile,
    this.gap = TshopMetrics.gap,
  });

  /// Category or state name.
  final String label;

  /// Tiles, filled top-to-bottom then left-to-right.
  final List<Widget> tiles;

  /// Number shown next to the label.
  final int? count;

  /// Tiles per column: 3 on Thor, 4 on square panels.
  final int rows;

  /// Tile edge in dp.
  final double tileSize;

  /// Gap between tiles.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final text = Theme.of(context).textTheme;
    final columns = <Widget>[
      for (var start = 0; start < tiles.length; start += rows)
        Column(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: [
            for (final tile in tiles.skip(start).take(rows))
              SizedBox.square(dimension: tileSize, child: tile),
          ],
        ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
      decoration: BoxDecoration(
        color: tokens.shelf,
        borderRadius: BorderRadius.circular(TshopMetrics.shelfRadius),
        boxShadow: tokens.shelfShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          SizedBox(
            height: 22,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Text(label, style: text.titleMedium),
                  Text(
                    '${count ?? tiles.length}',
                    style: text.labelMedium?.copyWith(color: tokens.ink3),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: rows * tileSize + (rows - 1) * gap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: gap,
              children: columns,
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid card with an uppercase heading (About, New in, Details).
class TshopCard extends StatelessWidget {
  /// Creates a card.
  const TshopCard({required this.heading, required this.child, super.key});

  /// Uppercased section title.
  final String heading;

  /// Card body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(TshopMetrics.cardRadius),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            heading.toUpperCase(),
            style: text.labelMedium?.copyWith(
              color: tokens.ink3,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.48,
            ),
          ),
          DefaultTextStyle.merge(style: text.bodyMedium, child: child),
        ],
      ),
    );
  }
}

/// Two-column term / value list inside a [TshopCard].
class TshopFacts extends StatelessWidget {
  /// Creates a facts list.
  const TshopFacts(this.facts, {super.key});

  /// Term and value pairs.
  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final style = Theme.of(context).textTheme.labelMedium;
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const {1: FlexColumnWidth()},
      children: [
        for (final (term, value) in facts)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: Text(term, style: style?.copyWith(color: tokens.ink3)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(value, style: style?.copyWith(color: tokens.ink)),
              ),
            ],
          ),
      ],
    );
  }
}

/// Top-screen strip naming the focused app, its summary and state chips.
class TshopInfoStrip extends StatelessWidget {
  /// Creates an info strip.
  const TshopInfoStrip({
    required this.title,
    required this.summary,
    super.key,
    this.chips = const [],
  });

  /// App name (or screen title when nothing is focused).
  final String title;

  /// One line: why it matters, or the failure.
  final String summary;

  /// Category and status chips, right-aligned.
  final List<TshopChip> chips;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 16,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineSmall,
                  ),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: context.tshop.ink2,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: chips,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
