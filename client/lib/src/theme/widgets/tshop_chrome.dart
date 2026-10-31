import 'package:flutter/material.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_chip.dart';

/// 3DS-style bitmapped Wi-Fi: 9 × 7 pixel fan.
const _wifiPixels = [
  '..#####..',
  '.#.....#.',
  '#..###..#',
  '..#...#..',
  '...###...',
  '.........',
  '....#....',
];

const _wifiOfflineX = [(6, 4), (8, 4), (7, 5), (6, 6), (8, 6)];

/// Top-level destinations in the top bar.
enum TshopDestination {
  /// Catalog shelves.
  browse('Browse'),

  /// Installed / updating apps.
  library('Library'),

  /// Preferences.
  settings('Settings');

  const TshopDestination(this.label);

  /// Tab label.
  final String label;
}

/// One controller hint in a [TshopLegend].
typedef LegendItem = ({PadButton button, String label});

/// Frosted pill across the top: logo, L / tabs / R, search, status.
class TshopTopBar extends StatelessWidget {
  /// Creates a top bar.
  const TshopTopBar({
    required this.destination,
    super.key,
    this.libraryCount = 0,
    this.online = true,
    this.showSearch = false,
    this.query,
    this.time = '9:41',
    this.onDestination,
  });

  /// Active tab.
  final TshopDestination destination;

  /// Badge on the Library tab; hidden when 0.
  final int libraryCount;

  /// Drives the Wi-Fi glyph.
  final bool online;

  /// Show the Y-to-search pill.
  final bool showSearch;

  /// Active search query; turns the pill dark.
  final String? query;

  /// Clock text.
  final String time;

  /// Called when a tab is tapped.
  final ValueChanged<TshopDestination>? onDestination;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final ui = Theme.of(context).textTheme.labelMedium;
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 5, right: 6),
      decoration: BoxDecoration(
        color: tokens.shelf,
        borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
        boxShadow: tokens.shelfShadow,
      ),
      child: Row(
        spacing: 8,
        children: [
          const TshopLogo(),
          const PadGlyph(PadButton.l),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              for (final item in TshopDestination.values)
                _Tab(
                  label: item.label,
                  active: item == destination,
                  count: item == TshopDestination.library ? libraryCount : 0,
                  onTap: onDestination == null
                      ? null
                      : () => onDestination!(item),
                ),
            ],
          ),
          const PadGlyph(PadButton.r),
          const Spacer(),
          if (showSearch) _SearchPill(query: query),
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                TshopWifiGlyph(online: online),
                Text(
                  time,
                  style: ui?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                CustomPaint(
                  size: const Size(22, 12),
                  painter: _BatteryPainter(tokens.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom row of controller hints, with an optional centre slot.
class TshopLegend extends StatelessWidget {
  /// Creates a legend.
  const TshopLegend({
    required this.left,
    super.key,
    this.right = const [],
    this.middle,
  });

  /// Hints on the left.
  final List<LegendItem> left;

  /// Hints on the right.
  final List<LegendItem> right;

  /// Centre content, e.g. [TshopDownloadsPill].
  final Widget? middle;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    Widget group(List<LegendItem> items) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              PadGlyph(item.button),
              Text(item.label, style: style),
            ],
          ),
      ],
    );
    return SizedBox(
      height: 26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            group(left),
            const Spacer(),
            ?middle,
            const Spacer(),
            group(right),
          ],
        ),
      ),
    );
  }
}

/// Legend-centre pill showing download progress and a jump to Library.
class TshopDownloadsPill extends StatelessWidget {
  /// Creates a downloads pill.
  const TshopDownloadsPill({
    required this.label,
    required this.progress,
    required this.go,
    super.key,
  });

  /// e.g. "melonDS 62%".
  final String label;

  /// 0–1 bar fill.
  final double progress;

  /// Trailing hint, e.g. "+1 · Library".
  final String go;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final text = Theme.of(context).textTheme;
    final pill = BorderRadius.circular(TshopMetrics.pillRadius);
    return Container(
      height: 24,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: pill,
        boxShadow: tokens.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 7,
        children: [
          Text(label, style: text.labelMedium?.copyWith(color: tokens.ink)),
          ClipRRect(
            borderRadius: pill,
            child: SizedBox(
              width: 46,
              height: 5,
              child: ColoredBox(
                color: tokens.chip,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0, 1),
                  child: const ColoredBox(color: TshopBrand.accent),
                ),
              ),
            ),
          ),
          Container(
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: tokens.chip, borderRadius: pill),
            child: Center(
              widthFactor: 1,
              child: Text(go, style: text.labelSmall),
            ),
          ),
        ],
      ),
    );
  }
}

/// Orange rounded-square "t" brand mark.
class TshopLogo extends StatelessWidget {
  /// Creates the logo at [size] dp.
  const TshopLogo({super.key, this.size = 28});

  /// Edge length.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'tShop',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: TshopBrand.accentGradient,
          borderRadius: BorderRadius.circular(size * 9 / 28),
          boxShadow: const [
            BoxShadow(
              color: TshopBrand.accentSoft,
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          't',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 17 / 28,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Pixel Wi-Fi fan; greys out and gains a red × when offline.
class TshopWifiGlyph extends StatelessWidget {
  /// Creates the glyph.
  const TshopWifiGlyph({required this.online, super.key});

  /// Connection state.
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: online ? 'Online' : 'Offline',
      child: CustomPaint(
        size: const Size(18, 14),
        painter: _WifiPainter(online: online, ink: context.tshop.ink2),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.count,
    this.onTap,
  });

  final String label;
  final bool active;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? tokens.tabActive : Colors.transparent,
          borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x1F141C30),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: active ? tokens.ink : tokens.ink2,
              ),
            ),
            if (count > 0) TshopCountBadge(count),
          ],
        ),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({this.query});

  final String? query;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final active = query != null && query!.isNotEmpty;
    final ink = active ? tokens.card : tokens.ink2;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: ink,
    );
    return Container(
      height: 28,
      padding: EdgeInsets.only(left: 5, right: active ? 4 : 6),
      decoration: BoxDecoration(
        color: active ? tokens.ink : tokens.chip,
        borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: active
            ? [
                Icon(Icons.search_rounded, size: 16, color: ink),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    query!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                const PadGlyph(PadButton.x),
              ]
            : [
                const PadGlyph(PadButton.y),
                Text('Search', style: style),
              ],
      ),
    );
  }
}

class _WifiPainter extends CustomPainter {
  _WifiPainter({required this.online, required this.ink});

  final bool online;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 9;
    final on = Paint()..color = ink;
    final off = Paint()..color = ink.withValues(alpha: 0.22);
    for (var y = 0; y < _wifiPixels.length; y++) {
      for (var x = 0; x < _wifiPixels[y].length; x++) {
        if (_wifiPixels[y][x] != '#') continue;
        canvas.drawRect(
          Rect.fromLTWH(x * px, y * px, px, px),
          online || y >= 6 ? on : off,
        );
      }
    }
    if (online) return;
    final x = Paint()..color = TshopBrand.bad;
    for (final (cx, cy) in _wifiOfflineX) {
      canvas.drawRect(Rect.fromLTWH(cx * px, cy * px, px, px), x);
    }
  }

  @override
  bool shouldRepaint(_WifiPainter oldDelegate) =>
      oldDelegate.online != online || oldDelegate.ink != ink;
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter(this.ink);

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
  bool shouldRepaint(_BatteryPainter oldDelegate) => oldDelegate.ink != ink;
}
