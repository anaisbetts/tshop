import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/theme/widgets/tshop_chip.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';

/// Viewport width below which Browse switches to the 4-row square shelf layout.
const double browseCompactWidthBreakpoint = 660;

/// Number of tile rows per column on landscape handheld screens.
const int browseLandscapeRows = 3;

/// Number of tile rows per column on compact / square handheld screens.
const int browseCompactRows = 4;

/// Tile edge length in dp on compact / square handheld screens.
const double browseCompactTileSize = 70;

/// Gap between tiles in dp on compact / square handheld screens.
const double browseCompactTileGap = 7;

/// Tile corner radius in dp on compact / square handheld screens.
const double browseCompactTileRadius = 16;

const List<Color> _defaultTileBackdropColors = <Color>[
  Color(0xFF3A4152),
  Color(0xFF232733),
];

/// Valid 1×1 transparent PNG used when a remote tile icon cannot be loaded.
final Uint8List _transparentPixelPng = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

/// A single visible category shelf on the Browse screen.
@immutable
final class BrowseCategoryShelf {
  /// Creates a [BrowseCategoryShelf].
  BrowseCategoryShelf({
    required this.id,
    required this.label,
    required List<CatalogEntry> entries,
  }) : entries = List<CatalogEntry>.unmodifiable(entries);

  /// Stable category identifier.
  final String id;

  /// Localized heading shown at the top of the shelf frame.
  final String label;

  /// Ordered entries visible inside this shelf.
  final List<CatalogEntry> entries;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BrowseCategoryShelf &&
            other.id == id &&
            other.label == label &&
            listEquals(other.entries, entries);
  }

  @override
  int get hashCode => Object.hash(id, label, Object.hashAll(entries));
}

/// Summary data displayed inside the footer `TshopDownloadsPill`.
@immutable
final class BrowseDownloadSummary {
  /// Creates a [BrowseDownloadSummary].
  const BrowseDownloadSummary({
    required this.label,
    required this.progress,
    required this.go,
  });

  /// Lead task progress label, e.g. `"melonDS 62%"` or `"2 active"`.
  final String label;

  /// Normalized `0.0..1.0` fill progress.
  final double progress;

  /// Trailing Library link hint, e.g. `"+1 · Library"` or `"Library"`.
  final String go;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BrowseDownloadSummary &&
            other.label == label &&
            other.progress == progress &&
            other.go == go;
  }

  @override
  int get hashCode => Object.hash(label, progress, go);
}

/// Network tile icon provider backed by [CachedNetworkImageProvider] that
/// silently resolves to a transparent fallback when offline or unreachable.
///
/// This keeps `TshopTile` free of uncaught `Image` stream exceptions in offline
/// mode and headless widget tests while preserving disk/HTTP caching at
/// runtime.
@immutable
final class ResilientTileIconProvider
    extends ImageProvider<ResilientTileIconProvider> {
  /// Creates a resilient tile icon provider for [url].
  const ResilientTileIconProvider(this.url, {this.cacheManager});

  /// Remote or relative icon URL.
  final String url;

  /// Optional [BaseCacheManager] wired to the shared Dio client.
  final BaseCacheManager? cacheManager;

  @override
  Future<ResilientTileIconProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<ResilientTileIconProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    ResilientTileIconProvider key,
    ImageDecoderCallback decode,
  ) {
    final trimmed = key.url.trim();
    if (trimmed.isEmpty) {
      return _TransparentFallbackCompleter(decode);
    }
    return _ResilientImageStreamCompleter(
      url: trimmed,
      cacheManager: key.cacheManager,
      decode: decode,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ResilientTileIconProvider &&
            other.url == url &&
            other.cacheManager == cacheManager;
  }

  @override
  int get hashCode => Object.hash(url, cacheManager);

  @override
  String toString() => 'ResilientTileIconProvider("$url")';
}

/// Groups [catalog] entries into non-empty [BrowseCategoryShelf]s in catalog
/// order, optionally filtered by [query].
List<BrowseCategoryShelf> buildBrowseShelves(
  CatalogDocument catalog, {
  String? query,
  String locale = defaultCatalogLocale,
}) {
  final needle = query?.trim() ?? '';
  final entryByPackage = <String, CatalogEntry>{
    for (final entry in catalog.entries) entry.packageName: entry,
  };
  final assigned = <String>{};
  final shelves = <BrowseCategoryShelf>[];

  for (final frame in catalog.categories) {
    final matched = <CatalogEntry>[];
    if (frame.entries.isNotEmpty) {
      for (final packageName in frame.entries) {
        final entry = entryByPackage[packageName];
        if (entry == null || !assigned.add(packageName)) {
          continue;
        }
        if (needle.isEmpty ||
            matchesBrowseQuery(entry, needle, locale: locale)) {
          matched.add(entry);
        }
      }
    } else {
      for (final entry in catalog.entries) {
        if (entry.category != frame.id || !assigned.add(entry.packageName)) {
          continue;
        }
        if (needle.isEmpty ||
            matchesBrowseQuery(entry, needle, locale: locale)) {
          matched.add(entry);
        }
      }
    }

    if (matched.isNotEmpty) {
      shelves.add(
        BrowseCategoryShelf(
          id: frame.id,
          label: frame.name.resolve(locale),
          entries: matched,
        ),
      );
    }
  }

  // Include any entries whose category was not listed in catalog.categories.
  final leftoversByCategory = <String, List<CatalogEntry>>{};
  for (final entry in catalog.entries) {
    if (!assigned.add(entry.packageName)) {
      continue;
    }
    if (needle.isNotEmpty &&
        !matchesBrowseQuery(entry, needle, locale: locale)) {
      continue;
    }
    leftoversByCategory
        .putIfAbsent(entry.category, () => <CatalogEntry>[])
        .add(entry);
  }
  for (final group in leftoversByCategory.entries) {
    shelves.add(
      BrowseCategoryShelf(
        id: group.key,
        label: group.key,
        entries: group.value,
      ),
    );
  }

  return shelves;
}

/// Returns `true` when [entry] matches the user's search [query].
bool matchesBrowseQuery(
  CatalogEntry entry,
  String query, {
  String locale = defaultCatalogLocale,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  final haystack = <String>[
    entry.name.resolve(locale),
    entry.summary.resolve(locale),
    ...entry.description.resolve(locale),
    ...entry.searchTags,
    entry.publisher,
    entry.category,
    entry.packageName,
  ].join(' ').toLowerCase();
  return haystack.contains(needle);
}

/// Maps [AppCatalogStatus] to the visual [TileStatus] used by `TshopTile`.
TileStatus tileStatusForCatalogStatus(AppCatalogStatus status) {
  return switch (status) {
    AppCatalogStatus.available ||
    AppCatalogStatus.landing => TileStatus.available,
    AppCatalogStatus.installed => TileStatus.installed,
    AppCatalogStatus.updateAvailable => TileStatus.update,
    AppCatalogStatus.otherSource => TileStatus.otherSource,
    AppCatalogStatus.queued ||
    AppCatalogStatus.downloading ||
    AppCatalogStatus.verifying ||
    AppCatalogStatus.installing => TileStatus.downloading,
    AppCatalogStatus.awaitingConfirm => TileStatus.confirm,
    AppCatalogStatus.failed => TileStatus.failed,
  };
}

/// Computes the `0.0..1.0` progress fill rendered on a busy `TshopTile`.
double tileProgressForState(ResolvedAppState state) {
  return switch (state.status) {
    AppCatalogStatus.downloading => (state.activeTask?.progress ?? 0).clamp(
      0.0,
      1.0,
    ),
    AppCatalogStatus.verifying ||
    AppCatalogStatus.installing ||
    AppCatalogStatus.awaitingConfirm => 1.0,
    AppCatalogStatus.available ||
    AppCatalogStatus.landing ||
    AppCatalogStatus.installed ||
    AppCatalogStatus.updateAvailable ||
    AppCatalogStatus.otherSource ||
    AppCatalogStatus.queued ||
    AppCatalogStatus.failed => 0.0,
  };
}

/// Builds the 1–2 [TshopChip] pills displayed in the Browse info strip.
///
/// On [compact] widths, omits the category chip when a status chip is also
/// present to preserve title/summary legibility.
List<TshopChip> buildBrowseInfoChips(
  ResolvedAppState state,
  CatalogDocument catalog, {
  required bool compact,
  String locale = defaultCatalogLocale,
}) {
  final categoryLabel = _resolveCategoryLabel(
    state.entry.category,
    catalog,
    locale: locale,
  );
  final categoryChip = TshopChip(categoryLabel);
  final statusChip = _buildStatusChip(state, catalog, locale: locale);

  if (statusChip == null) {
    return <TshopChip>[categoryChip];
  }
  if (compact) {
    return <TshopChip>[statusChip];
  }
  return <TshopChip>[categoryChip, statusChip];
}

/// Builds the one-line summary shown in the Browse info strip for [state].
String buildBrowseInfoSummary(
  ResolvedAppState state, {
  String locale = defaultCatalogLocale,
}) {
  if (state.status == AppCatalogStatus.failed) {
    final failure = state.activeTask?.errorMessage?.trim();
    if (failure != null && failure.isNotEmpty) {
      return failure;
    }
  }
  return state.entry.summary.resolve(locale);
}

/// Computes the footer downloads-pill summary for active queue tasks, or `null`
/// when no downloads or pending confirmations are active.
BrowseDownloadSummary? buildDownloadSummary(
  InstallQueueState queue, {
  required bool compact,
}) {
  final active = <InstallTask>[
    for (final task in queue.orderedTasks)
      if (task.stage.isInProgress ||
          task.stage == InstallTaskStage.awaitingConfirm)
        task,
  ];
  if (active.isEmpty) {
    return null;
  }

  final lead = _selectLeadTask(active);
  final progress = switch (lead.stage) {
    InstallTaskStage.queued => 0.0,
    InstallTaskStage.downloading => lead.progress.clamp(0.0, 1.0),
    InstallTaskStage.verifying ||
    InstallTaskStage.installing ||
    InstallTaskStage.awaitingConfirm => 1.0,
    InstallTaskStage.failed => 0.0,
  };

  final label = compact
      ? '${active.length} active'
      : switch (lead.stage) {
          InstallTaskStage.queued => '${lead.appName} Queued',
          InstallTaskStage.downloading =>
            '${lead.appName} ${(progress * 100).round()}%',
          InstallTaskStage.verifying => '${lead.appName} Verifying',
          InstallTaskStage.installing => '${lead.appName} Installing',
          InstallTaskStage.awaitingConfirm => '${lead.appName} Ready',
          InstallTaskStage.failed => '${lead.appName} Failed',
        };

  final go = compact || active.length <= 1
      ? 'Library'
      : '+${active.length - 1} · Library';

  return BrowseDownloadSummary(label: label, progress: progress, go: go);
}

/// Converts [CatalogTile] backdrop hex colors and CSS angle into a
/// [LinearGradient] for `TshopTile`.
LinearGradient parseTileBackdrop(CatalogTile tile) {
  final parsed = <Color>[
    for (final raw in tile.backdropColors) ?parseHexColor(raw),
  ];
  final colors = switch (parsed.length) {
    0 => _defaultTileBackdropColors,
    1 => <Color>[parsed.first, parsed.first],
    _ => parsed,
  };

  final radians = tile.backdropAngle * math.pi / 180;
  final direction = Alignment(math.sin(radians), -math.cos(radians));
  return LinearGradient(begin: -direction, end: direction, colors: colors);
}

/// Safely parses a CSS hex color string (`#RGB`, `#RRGGBB`, or `#AARRGGBB`)
/// into a [Color], returning `null` when malformed.
Color? parseHexColor(String value) {
  var hex = value.trim();
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }
  if (hex.length == 3) {
    hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  }
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  if (hex.length != 8) {
    return null;
  }
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}

final class _ResilientImageStreamCompleter extends ImageStreamCompleter {
  _ResilientImageStreamCompleter({
    required String url,
    required BaseCacheManager? cacheManager,
    required ImageDecoderCallback decode,
  }) : _decode = decode {
    try {
      final delegate = CachedNetworkImageProvider(
        url,
        cacheManager: cacheManager,
      );
      _inner = delegate.loadImage(delegate, decode);
      _innerListener = ImageStreamListener(
        _handleInnerImage,
        onError: _handleInnerError,
      );
      _inner!.addListener(_innerListener!);
      addOnLastListenerRemovedCallback(_detachInner);
    } on Object {
      unawaited(_emitFallback());
    }
  }

  final ImageDecoderCallback _decode;
  ImageStreamCompleter? _inner;
  ImageStreamListener? _innerListener;
  bool _resolved = false;

  void _handleInnerImage(ImageInfo image, bool synchronousCall) {
    _resolved = true;
    setImage(image.clone());
  }

  void _handleInnerError(Object error, StackTrace? stackTrace) {
    if (_resolved) {
      return;
    }
    _resolved = true;
    _detachInner();
    unawaited(_emitFallback());
  }

  void _detachInner() {
    final inner = _inner;
    final listener = _innerListener;
    if (inner != null && listener != null) {
      inner.removeListener(listener);
    }
    _inner = null;
    _innerListener = null;
  }

  Future<void> _emitFallback() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        _transparentPixelPng,
      );
      final codec = await _decode(buffer);
      final frame = await codec.getNextFrame();
      codec.dispose();
      setImage(ImageInfo(image: frame.image));
    } on Object {
      // Nothing else to report if the test binding is already torn down.
    }
  }
}

final class _TransparentFallbackCompleter extends ImageStreamCompleter {
  _TransparentFallbackCompleter(ImageDecoderCallback decode) {
    unawaited(_load(decode));
  }

  Future<void> _load(ImageDecoderCallback decode) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        _transparentPixelPng,
      );
      final codec = await decode(buffer);
      final frame = await codec.getNextFrame();
      codec.dispose();
      setImage(ImageInfo(image: frame.image));
    } on Object {
      // Ignore shutdown races during teardown.
    }
  }
}

TshopChip? _buildStatusChip(
  ResolvedAppState state,
  CatalogDocument catalog, {
  required String locale,
}) {
  if (state.unmetCapabilities.isNotEmpty) {
    final labels = <String>[
      for (final tag in state.unmetCapabilities)
        _resolveCapabilityLabel(tag, catalog, locale: locale),
    ];
    return TshopChip('Needs ${labels.join(', ')}', tone: TshopChipTone.bad);
  }

  return switch (state.status) {
    AppCatalogStatus.installed => const TshopChip(
      'Installed',
      tone: TshopChipTone.good,
    ),
    AppCatalogStatus.updateAvailable => TshopChip(
      _formatUpdateChipLabel(state),
      tone: TshopChipTone.accent,
    ),
    AppCatalogStatus.otherSource => const TshopChip('Other source'),
    AppCatalogStatus.landing => const TshopChip('From the publisher'),
    AppCatalogStatus.queued => const TshopChip(
      'Queued',
      tone: TshopChipTone.accent,
    ),
    AppCatalogStatus.downloading => TshopChip(
      'Downloading '
      '${((state.activeTask?.progress ?? 0).clamp(0.0, 1.0) * 100).round()}%',
      tone: TshopChipTone.accent,
    ),
    AppCatalogStatus.verifying => const TshopChip(
      'Verifying…',
      tone: TshopChipTone.accent,
    ),
    AppCatalogStatus.installing => const TshopChip(
      'Installing…',
      tone: TshopChipTone.accent,
    ),
    AppCatalogStatus.awaitingConfirm => const TshopChip(
      'Confirm in Library',
      tone: TshopChipTone.good,
    ),
    AppCatalogStatus.failed => const TshopChip(
      'Install failed',
      tone: TshopChipTone.bad,
    ),
    AppCatalogStatus.available => _buildSizeChip(state),
  };
}

TshopChip? _buildSizeChip(ResolvedAppState state) {
  final variant =
      state.selectedVariant ??
      (state.entry.release != null && state.entry.release!.variants.isNotEmpty
          ? state.entry.release!.variants.first
          : null);
  if (variant == null) {
    return null;
  }
  return TshopChip(formatByteSize(variant.sizeBytes));
}

String _formatUpdateChipLabel(ResolvedAppState state) {
  final latestVersion = state.entry.release?.versionName;
  final installedCode = state.installedPackage?.versionCode;
  String? installedVersion;
  if (installedCode != null) {
    for (final changelog in state.entry.changelogs) {
      if (changelog.versionCode == installedCode) {
        installedVersion = changelog.versionName;
        break;
      }
    }
  }
  if (installedVersion != null && latestVersion != null) {
    return 'Update $installedVersion → $latestVersion';
  }
  if (latestVersion != null && latestVersion.isNotEmpty) {
    return 'Update to $latestVersion';
  }
  return 'Update available';
}

String _resolveCategoryLabel(
  String categoryId,
  CatalogDocument catalog, {
  required String locale,
}) {
  for (final frame in catalog.categories) {
    if (frame.id == categoryId) {
      return frame.name.resolve(locale);
    }
  }
  return categoryId;
}

String _resolveCapabilityLabel(
  String tag,
  CatalogDocument catalog, {
  required String locale,
}) {
  for (final def in catalog.capabilityTags) {
    if (def.tag == tag) {
      return def.label.resolve(locale);
    }
  }
  return tag;
}

InstallTask _selectLeadTask(List<InstallTask> active) {
  for (final task in active) {
    if (task.stage == InstallTaskStage.downloading) {
      return task;
    }
  }
  for (final task in active) {
    if (task.stage.isInProgress) {
      return task;
    }
  }
  return active.first;
}
