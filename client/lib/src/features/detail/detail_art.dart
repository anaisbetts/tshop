import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';

const Color _fallbackBackdropColor = Color(0xFF3A4152);
const double _washBlurSigma = 40;
const double _washIconOpacity = 0.85;
const double _washIconWidthFraction = 0.7;

const List<String> _monthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Full-bleed hero banner at the top of the app detail screen.
///
/// Renders [CatalogEntry.featureUrl] when available, or falls back to a
/// backdrop gradient wash behind a softly blurred enlargement of the app icon.
/// Always overlays the vertical scrim fading into [TshopTokens.scrim].
class DetailHeroBanner extends StatelessWidget {
  /// Creates a hero banner for [entry].
  const DetailHeroBanner({
    required this.entry,
    required this.cacheManager,
    super.key,
    this.height = 250,
  });

  /// Catalog entry whose banner or fallback wash is displayed.
  final CatalogEntry entry;

  /// Cache manager used to fetch remote artwork.
  final BaseCacheManager cacheManager;

  /// Banner height in logical pixels.
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final featureUrl = entry.featureUrl;
    final wash = DetailBackdropWash(
      tile: entry.tile,
      cacheManager: cacheManager,
    );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (featureUrl != null && featureUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: featureUrl,
                cacheManager: cacheManager,
                fit: BoxFit.cover,
                placeholder: (context, url) => wash,
                errorWidget: (context, url, error) => wash,
              )
            else
              wash,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    tokens.scrim.withValues(alpha: 0),
                    tokens.scrim.withValues(alpha: 0.78),
                    tokens.scrim,
                  ],
                  stops: const <double>[0.30, 0.68, 0.96],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backdrop gradient wash with an enlarged, blurred app icon used when an
/// entry has no feature graphic.
class DetailBackdropWash extends StatelessWidget {
  /// Creates a backdrop wash from [tile] metadata.
  const DetailBackdropWash({
    required this.tile,
    required this.cacheManager,
    super.key,
  });

  /// Tile metadata providing backdrop colors, angle, and icon URL.
  final CatalogTile tile;

  /// Cache manager used to fetch the app icon.
  final BaseCacheManager cacheManager;

  @override
  Widget build(BuildContext context) {
    final gradient = parseBackdropGradient(
      tile.backdropColors,
      tile.backdropAngle,
    );
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: tile.iconUrl.isEmpty
          ? null
          : LayoutBuilder(
              builder: (context, constraints) {
                final iconWidth = constraints.maxWidth * _washIconWidthFraction;
                return Center(
                  child: Opacity(
                    opacity: _washIconOpacity,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _washBlurSigma,
                        sigmaY: _washBlurSigma,
                      ),
                      child: SizedBox(
                        width: iconWidth,
                        child: CachedNetworkImage(
                          imageUrl: tile.iconUrl,
                          cacheManager: cacheManager,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const SizedBox.shrink(),
                          errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Parses catalog [hexColors] and CSS [angleDegrees] into a [LinearGradient].
LinearGradient parseBackdropGradient(
  List<String> hexColors,
  double angleDegrees,
) {
  final parsed = <Color>[
    for (final raw in hexColors) ?_parseHexColor(raw),
  ];
  final colors = switch (parsed.length) {
    0 => const <Color>[_fallbackBackdropColor, _fallbackBackdropColor],
    1 => <Color>[parsed.first, parsed.first],
    _ => parsed,
  };

  final radians = angleDegrees * math.pi / 180;
  final direction = Alignment(math.sin(radians), -math.cos(radians));
  return LinearGradient(
    begin: -direction,
    end: direction,
    colors: colors,
  );
}

/// Formats a UTC or local release [date] as `"24 Sep 2026"`.
String formatReleaseDate(DateTime date) {
  final month = _monthAbbreviations[date.month - 1];
  return '${date.day} $month ${date.year}';
}

/// Resolves machine-readable capability [tags] against catalog [definitions].
List<String> resolveCapabilityLabels(
  List<String> tags,
  List<CatalogCapabilityTag> definitions,
) {
  if (tags.isEmpty) {
    return const <String>[];
  }
  final byTag = <String, String>{
    for (final def in definitions) def.tag: def.label.resolve(),
  };
  return List<String>.unmodifiable(<String>[
    for (final tag in tags) byTag[tag] ?? tag,
  ]);
}

/// Resolves a human-readable installed version label for [versionCode] using
/// [changelogs] when a matching release note entry exists.
String formatInstalledVersion(
  int versionCode,
  List<CatalogChangelog> changelogs,
) {
  for (final changelog in changelogs) {
    if (changelog.versionCode == versionCode &&
        changelog.versionName.isNotEmpty) {
      return changelog.versionName;
    }
  }
  return 'v$versionCode';
}

Color? _parseHexColor(String raw) {
  final cleaned = raw.trim().replaceFirst('#', '');
  if (cleaned.length == 3) {
    final expanded = cleaned.split('').map((c) => '$c$c').join();
    final value = int.tryParse('FF$expanded', radix: 16);
    return value == null ? null : Color(value);
  }
  if (cleaned.length == 6) {
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value == null ? null : Color(value);
  }
  if (cleaned.length == 8) {
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(value);
  }
  return null;
}
