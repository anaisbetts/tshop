import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/features/browse/browse_catalog_helpers.dart';
import 'package:tshop/src/features/browse/browse_widgets.dart';
import 'package:tshop/src/images/app_image_cache.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/input/gamepad_scope.dart';
import 'package:tshop/src/input/shelf_focus_controller.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/platform/app_services.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_button.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';
import 'package:tshop/src/theme/widgets/tshop_surfaces.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';
import 'package:tshop/src/theme/widgets/tshop_wallpaper.dart';

const double _minTileSize = 44;
const double _stripHorizontalPadding = 14;
const double _scrollRevealPadding = 24;
const DeviceInfo _fallbackDeviceInfo = DeviceInfo(
  supportedAbis: <String>[],
  sdkInt: 0,
  hasPServiceBridge: false,
);

/// Primary storefront Browse screen displaying horizontally scrolling,
/// column-major category shelves with gamepad and touch navigation.
class BrowsePage extends HookConsumerWidget {
  /// Creates the Browse screen.
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final installedMap = ref.watch(
      installedPackagesProvider.select(
        (asyncState) => asyncState.value ?? const <String, InstalledPackage>{},
      ),
    );
    final installQueue = ref.watch(installQueueProvider);
    final deviceInfo = ref.watch(
      deviceInfoProvider.select(
        (asyncState) => asyncState.value ?? _fallbackDeviceInfo,
      ),
    );
    final metCapabilities = ref.watch(
      metCapabilitiesProvider.select(
        (asyncState) => asyncState.value ?? const <String>{},
      ),
    );
    final libraryBadgeCount = ref.watch(libraryBadgeCountProvider);
    final config = ref.watch(tshopConfigProvider);

    final searchQuery = useState('');
    final isSearchOpen = useState(false);
    final scrollController = useScrollController();
    final stripKey = useMemoized(GlobalKey.new);
    final tileKeysRef = useRef<Map<String, GlobalKey>>(<String, GlobalKey>{});
    final focusController = useMemoized(ShelfFocusController.new);
    useEffect(() => focusController.dispose, <Object?>[focusController]);
    useListenable(focusController);

    final clockText = _useClockText();
    final locale = _localeTagOf(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compact = viewportWidth < browseCompactWidthBreakpoint;
    final rows = compact ? browseCompactRows : browseLandscapeRows;
    final baseTileSize = compact ? browseCompactTileSize : TshopMetrics.tile;
    final gap = compact ? browseCompactTileGap : TshopMetrics.gap;
    final tileRadius = compact
        ? browseCompactTileRadius
        : TshopMetrics.tileRadius;

    final catalogState = catalogAsync.value;
    final isOfflineEmpty = catalogAsync.hasError && catalogState == null;
    final isInitialLoading =
        catalogAsync.isLoading && catalogState == null && !isOfflineEmpty;
    final isOffline = isOfflineEmpty || (catalogState?.isOffline ?? false);
    final activeQuery = searchQuery.value.trim();
    final hasActiveQuery = activeQuery.isNotEmpty;

    final shelves = catalogState == null
        ? const <BrowseCategoryShelf>[]
        : buildBrowseShelves(
            catalogState.catalog,
            query: activeQuery,
            locale: locale,
          );
    final hasRemoteIcons = shelves.any(
      (shelf) =>
          shelf.entries.any((entry) => entry.tile.iconUrl.trim().isNotEmpty),
    );
    final cacheManager = hasRemoteIcons ? ref.watch(imageCacheProvider) : null;

    final sections = <ShelfSection>[
      for (final shelf in shelves)
        ShelfSection(
          id: shelf.id,
          itemIds: <String>[
            for (final entry in shelf.entries) entry.packageName,
          ],
          rows: rows,
        ),
    ];

    final entryByPackage = <String, CatalogEntry>{
      for (final shelf in shelves)
        for (final entry in shelf.entries) entry.packageName: entry,
    };

    // Prune stale GlobalKeys while preserving live tile keys across rebuilds.
    tileKeysRef.value.removeWhere(
      (packageName, _) => !entryByPackage.containsKey(packageName),
    );
    GlobalKey keyForPackage(String packageName) {
      return tileKeysRef.value.putIfAbsent(packageName, GlobalKey.new);
    }

    final latestSections = useRef<List<ShelfSection>>(sections)
      ..value = sections;
    final sectionsSignature = _sectionsSignature(sections);
    useEffect(() {
      if (listEquals(focusController.sections, sections)) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          focusController.updateSections(latestSections.value);
        }
      });
      return null;
    }, <Object?>[sectionsSignature, focusController]);

    final effectiveFocusedId =
        focusController.focusedId != null &&
            entryByPackage.containsKey(focusController.focusedId)
        ? focusController.focusedId
        : (shelves.isNotEmpty ? shelves.first.entries.first.packageName : null);

    useEffect(() {
      if (effectiveFocusedId == null) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        _ensureTileVisible(
          tileKey: tileKeysRef.value[effectiveFocusedId],
          stripKey: stripKey,
        );
      });
      return null;
    }, <Object?>[effectiveFocusedId, sectionsSignature]);

    final focusedEntry = effectiveFocusedId == null
        ? null
        : entryByPackage[effectiveFocusedId];
    final focusedResolved = focusedEntry == null
        ? null
        : resolveAppInstallState(
            entry: focusedEntry,
            installedPackages: installedMap,
            activeTask: installQueue.taskFor(focusedEntry.packageName),
            metCapabilities: metCapabilities,
            deviceInfo: deviceInfo,
          );

    void navigateToDestination(TshopDestination destination) {
      switch (destination) {
        case TshopDestination.browse:
          context.go('/');
        case TshopDestination.library:
          context.go('/library');
        case TshopDestination.settings:
          context.go('/settings');
      }
    }

    void openEntryDetail(CatalogEntry entry) {
      focusController.focus(entry.packageName);
      unawaited(context.push('/app/${entry.packageName}'));
    }

    void retryCatalog() {
      unawaited(ref.read(catalogProvider.notifier).refresh(forceRefresh: true));
    }

    void openSearch() {
      if (catalogState == null) {
        return;
      }
      isSearchOpen.value = true;
    }

    void clearSearch() {
      searchQuery.value = '';
    }

    void handleGamepadAction(GamepadAction action) {
      switch (action) {
        case GamepadAction.up:
        case GamepadAction.down:
        case GamepadAction.left:
        case GamepadAction.right:
          if (!listEquals(focusController.sections, latestSections.value)) {
            focusController.updateSections(latestSections.value);
          }
          focusController.move(action);
        case GamepadAction.confirm:
          if (isOfflineEmpty) {
            retryCatalog();
          } else if (focusedEntry != null) {
            openEntryDetail(focusedEntry);
          }
        case GamepadAction.back:
          if (hasActiveQuery) {
            clearSearch();
          }
        case GamepadAction.secondary:
          if (hasActiveQuery) {
            clearSearch();
          }
        case GamepadAction.searchOrRetry:
          if (isOfflineEmpty) {
            retryCatalog();
          } else if (catalogState != null) {
            openSearch();
          }
        case GamepadAction.tabPrev:
          navigateToDestination(TshopDestination.settings);
        case GamepadAction.tabNext:
          navigateToDestination(TshopDestination.library);
        case GamepadAction.menu:
          break;
      }
    }

    final downloadSummary = buildDownloadSummary(
      installQueue,
      compact: compact,
    );
    final infoStrip = _buildInfoStrip(
      isInitialLoading: isInitialLoading,
      isOfflineEmpty: isOfflineEmpty,
      activeQuery: activeQuery,
      catalog: catalogState?.catalog,
      focusedResolved: focusedResolved,
      compact: compact,
      locale: locale,
    );
    final leftHints = _buildLegendHints(
      isInitialLoading: isInitialLoading,
      isOfflineEmpty: isOfflineEmpty,
      hasShelves: shelves.isNotEmpty,
      hasActiveQuery: hasActiveQuery,
      onOpenFocused: focusedEntry == null
          ? null
          : () => openEntryDetail(focusedEntry),
      onClearSearch: clearSearch,
      onRetry: retryCatalog,
    );

    return TshopGamepadScope(
      enabled: !isSearchOpen.value,
      onAction: handleGamepadAction,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            TshopWallpaper(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _stripHorizontalPadding,
                        ),
                        child: BrowseTopBar(
                          libraryCount: libraryBadgeCount,
                          online: !isOffline,
                          showSearch: catalogState != null,
                          compact: compact,
                          query: activeQuery,
                          time: clockText,
                          onDestination: navigateToDestination,
                          onOpenSearch: openSearch,
                          onClearSearch: clearSearch,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _stripHorizontalPadding,
                        ),
                        child: infoStrip,
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final tileSize = _fitTileSize(
                              availableHeight: constraints.maxHeight,
                              rows: rows,
                              baseTileSize: baseTileSize,
                              gap: gap,
                            );

                            if (isInitialLoading) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _stripHorizontalPadding,
                                ),
                                child: BrowseEmptyFrame(
                                  rows: rows,
                                  tileSize: tileSize,
                                  gap: gap,
                                  tileRadius: tileRadius,
                                  child: const _LoadingStateContent(),
                                ),
                              );
                            }

                            if (isOfflineEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _stripHorizontalPadding,
                                ),
                                child: BrowseEmptyFrame(
                                  rows: rows,
                                  tileSize: tileSize,
                                  gap: gap,
                                  tileRadius: tileRadius,
                                  child: _OfflineEmptyContent(
                                    serverUrl: config.catalogBaseUrl.toString(),
                                    onRetry: retryCatalog,
                                  ),
                                ),
                              );
                            }

                            if (shelves.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _stripHorizontalPadding,
                                ),
                                child: BrowseEmptyFrame(
                                  rows: rows,
                                  tileSize: tileSize,
                                  gap: gap,
                                  tileRadius: tileRadius,
                                  child: _NoResultsContent(
                                    hasActiveQuery: hasActiveQuery,
                                    onClearSearch: clearSearch,
                                  ),
                                ),
                              );
                            }

                            return SingleChildScrollView(
                              key: stripKey,
                              controller: scrollController,
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: _stripHorizontalPadding,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 10,
                                children: [
                                  for (final shelf in shelves)
                                    TshopFrame(
                                      label: shelf.label,
                                      count: shelf.entries.length,
                                      rows: rows,
                                      tileSize: tileSize,
                                      gap: gap,
                                      tiles: <Widget>[
                                        for (final entry in shelf.entries)
                                          _buildEntryTile(
                                            entry: entry,
                                            tileKey: keyForPackage(
                                              entry.packageName,
                                            ),
                                            state: resolveAppInstallState(
                                              entry: entry,
                                              installedPackages: installedMap,
                                              activeTask: installQueue.taskFor(
                                                entry.packageName,
                                              ),
                                              metCapabilities: metCapabilities,
                                              deviceInfo: deviceInfo,
                                            ),
                                            focused:
                                                effectiveFocusedId ==
                                                entry.packageName,
                                            tileSize: tileSize,
                                            tileRadius: tileRadius,
                                            locale: locale,
                                            iconProvider:
                                                ResilientTileIconProvider(
                                                  entry.tile.iconUrl,
                                                  cacheManager: cacheManager,
                                                ),
                                            onTap: () => openEntryDetail(entry),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _stripHorizontalPadding,
                        ),
                        child: TshopLegend(
                          left: leftHints,
                          middle: downloadSummary == null
                              ? null
                              : _TappableDownloadsPill(
                                  summary: downloadSummary,
                                  onTap: () => navigateToDestination(
                                    TshopDestination.library,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isSearchOpen.value)
              BrowseSearchOverlay(
                initialQuery: searchQuery.value,
                onCommit: (value) {
                  searchQuery.value = value;
                  isSearchOpen.value = false;
                },
                onCancel: () => isSearchOpen.value = false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTile({
    required CatalogEntry entry,
    required GlobalKey tileKey,
    required ResolvedAppState state,
    required bool focused,
    required double tileSize,
    required double tileRadius,
    required String locale,
    required ImageProvider iconProvider,
    required VoidCallback onTap,
  }) {
    return KeyedSubtree(
      key: tileKey,
      child: TshopTile(
        icon: iconProvider,
        backdrop: parseTileBackdrop(entry.tile),
        iconScale: entry.tile.iconScale,
        status: tileStatusForCatalogStatus(state.status),
        progress: tileProgressForState(state),
        needsHardware: state.hasUnmetCapabilities,
        focused: focused,
        size: tileSize,
        radius: tileRadius,
        semanticLabel: entry.name.resolve(locale),
        onTap: onTap,
      ),
    );
  }
}

class _LoadingStateContent extends StatelessWidget {
  const _LoadingStateContent();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: TshopBrand.accent,
          ),
        ),
        Text(
          'Loading catalog…',
          style: text.titleSmall?.copyWith(color: tokens.ink2),
        ),
      ],
    );
  }
}

class _OfflineEmptyContent extends StatelessWidget {
  const _OfflineEmptyContent({
    required this.serverUrl,
    required this.onRetry,
  });

  final String serverUrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        Text(
          "Can't reach the catalog server.",
          textAlign: TextAlign.center,
          style: text.titleSmall?.copyWith(color: tokens.ink),
        ),
        Text(
          serverUrl,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.labelMedium?.copyWith(color: tokens.ink3),
        ),
        const SizedBox(height: 2),
        TshopButton(
          label: 'Retry',
          focused: true,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _NoResultsContent extends StatelessWidget {
  const _NoResultsContent({
    required this.hasActiveQuery,
    required this.onClearSearch,
  });

  final bool hasActiveQuery;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        Text(
          'Nothing in the catalog matches.',
          textAlign: TextAlign.center,
          style: text.titleSmall?.copyWith(color: tokens.ink2),
        ),
        if (hasActiveQuery)
          Semantics(
            button: true,
            label: 'Clear search',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onClearSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      const PadGlyph(PadButton.x),
                      Text(
                        'Clear search',
                        style: text.labelMedium?.copyWith(color: tokens.ink3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TappableDownloadsPill extends StatelessWidget {
  const _TappableDownloadsPill({
    required this.summary,
    required this.onTap,
  });

  final BrowseDownloadSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${summary.label}, open Library',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: TshopDownloadsPill(
            label: summary.label,
            progress: summary.progress,
            go: summary.go,
          ),
        ),
      ),
    );
  }
}

TshopInfoStrip _buildInfoStrip({
  required bool isInitialLoading,
  required bool isOfflineEmpty,
  required String activeQuery,
  required CatalogDocument? catalog,
  required ResolvedAppState? focusedResolved,
  required bool compact,
  required String locale,
}) {
  if (isInitialLoading) {
    return const TshopInfoStrip(
      title: 'Browse',
      summary: 'Loading the latest catalog…',
    );
  }
  if (isOfflineEmpty) {
    return const TshopInfoStrip(
      title: 'Offline',
      summary: 'Check your connection and retry to fetch the catalog.',
    );
  }
  if (focusedResolved == null || catalog == null) {
    return TshopInfoStrip(
      title: activeQuery.isNotEmpty ? 'No apps match “$activeQuery”' : 'Browse',
      summary: activeQuery.isNotEmpty
          ? 'Try a shorter word, or clear the search.'
          : 'No apps are currently available in this catalog.',
    );
  }

  return TshopInfoStrip(
    title: focusedResolved.entry.name.resolve(locale),
    summary: buildBrowseInfoSummary(focusedResolved, locale: locale),
    chips: buildBrowseInfoChips(
      focusedResolved,
      catalog,
      compact: compact,
      locale: locale,
    ),
  );
}

List<LegendItem> _buildLegendHints({
  required bool isInitialLoading,
  required bool isOfflineEmpty,
  required bool hasShelves,
  required bool hasActiveQuery,
  required VoidCallback? onOpenFocused,
  required VoidCallback onClearSearch,
  required VoidCallback onRetry,
}) {
  if (isInitialLoading) {
    return const <LegendItem>[];
  }
  if (isOfflineEmpty) {
    return <LegendItem>[
      LegendItem(button: PadButton.y, label: 'Retry', onTap: onRetry),
    ];
  }
  if (!hasShelves) {
    return hasActiveQuery
        ? <LegendItem>[
            LegendItem(
              button: PadButton.x,
              label: 'Clear search',
              onTap: onClearSearch,
            ),
          ]
        : const <LegendItem>[];
  }
  return <LegendItem>[
    const LegendItem(button: PadButton.dpad, label: 'Move'),
    LegendItem(button: PadButton.a, label: 'Open', onTap: onOpenFocused),
    if (hasActiveQuery)
      LegendItem(
        button: PadButton.x,
        label: 'Clear search',
        onTap: onClearSearch,
      ),
  ];
}

double _fitTileSize({
  required double availableHeight,
  required int rows,
  required double baseTileSize,
  required double gap,
}) {
  if (!availableHeight.isFinite || availableHeight <= 0) {
    return baseTileSize;
  }
  final needed =
      TshopFrame.chromeHeight + rows * baseTileSize + (rows - 1) * gap;
  if (needed <= availableHeight) {
    return baseTileSize;
  }
  final fitted =
      (availableHeight - TshopFrame.chromeHeight - (rows - 1) * gap) / rows;
  return math.max(_minTileSize, fitted);
}

void _ensureTileVisible({
  required GlobalKey? tileKey,
  required GlobalKey stripKey,
}) {
  final tileContext = tileKey?.currentContext;
  final stripContext = stripKey.currentContext;
  if (tileContext == null || stripContext == null) {
    return;
  }
  final tileBox = tileContext.findRenderObject();
  final stripBox = stripContext.findRenderObject();
  if (tileBox is! RenderBox || stripBox is! RenderBox) {
    return;
  }

  final topLeft = tileBox.localToGlobal(Offset.zero, ancestor: stripBox);
  final leftEdge = topLeft.dx;
  final rightEdge = leftEdge + tileBox.size.width;
  final stripWidth = stripBox.size.width;

  if (leftEdge < _scrollRevealPadding) {
    Scrollable.ensureVisible(
      tileContext,
      alignment: 0.08,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
  } else if (rightEdge > stripWidth - _scrollRevealPadding) {
    Scrollable.ensureVisible(
      tileContext,
      alignment: 0.92,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
  }
}

String _sectionsSignature(List<ShelfSection> sections) {
  final buffer = StringBuffer();
  for (final section in sections) {
    buffer
      ..write(section.id)
      ..write(':')
      ..write(section.rows)
      ..write('=')
      ..write(section.itemIds.join(','))
      ..write(';');
  }
  return buffer.toString();
}

String _localeTagOf(BuildContext context) {
  final locale = Localizations.maybeLocaleOf(context);
  return locale?.toLanguageTag() ?? defaultCatalogLocale;
}

String _useClockText() {
  final formatted = useState<String>(_formatClock(DateTime.now()));
  useEffect(() {
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final next = _formatClock(DateTime.now());
      if (next != formatted.value) {
        formatted.value = next;
      }
    });
    return timer.cancel;
  }, const <Object?>[]);
  return formatted.value;
}

String _formatClock(DateTime now) {
  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
