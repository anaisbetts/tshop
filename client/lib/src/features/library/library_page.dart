import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/config/tshop_config.dart';
import 'package:tshop/src/features/library/library_shelf_model.dart';
import 'package:tshop/src/images/app_image_cache.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/input/gamepad_scope.dart';
import 'package:tshop/src/input/shelf_focus_controller.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/platform/app_services.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_chip.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';
import 'package:tshop/src/theme/widgets/tshop_surfaces.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';
import 'package:tshop/src/theme/widgets/tshop_wallpaper.dart';

const String _browseRoute = '/';
const String _libraryRoute = '/library';
const String _settingsRoute = '/settings';

const int _emptyGridColumns = 9;
const double _minTileSize = 40;

const String _confirmNoteText =
    "Android asks to confirm each install while you're on Library";
const String _emptyTitle = 'Nothing from the catalog yet';
const String _emptySummary =
    'Apps you install from Browse, and catalog apps already on this device, '
    'show up here.';
const String _emptyGridMessage = 'Library fills in as you install.';
const String _updateAllSummary =
    'Downloads start now. The rest of the queue keeps going if one fails.';
const String _unknownSourcesFallbackMessage =
    'Allow "Install unknown apps" for tShop in Android Settings to continue.';
const String _genericFailureMessage = 'Download or installation failed.';

const DeviceInfo _fallbackDeviceInfo = DeviceInfo(
  supportedAbis: <String>[],
  sdkInt: 0,
  hasPServiceBridge: false,
);

/// 1×1 transparent PNG used when an entry omits a tile icon URL.
final Uint8List _transparentPixelPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Optional builder supplying the [ImageProvider] for a catalog tile icon.
typedef LibraryTileIconBuilder = ImageProvider Function(CatalogEntry entry);

@immutable
final class _ShelfLayoutMetrics {
  const _ShelfLayoutMetrics({
    required this.rows,
    required this.tileSize,
    required this.gap,
    required this.tileRadius,
    required this.isSquare,
  });

  final int rows;
  final double tileSize;
  final double gap;
  final double tileRadius;
  final bool isSquare;
}

/// Library tab showing active downloads, pending Android confirmations,
/// available updates, installed catalog apps, and other-source apps.
class LibraryPage extends HookConsumerWidget {
  /// Creates the Library screen.
  const LibraryPage({
    super.key,
    this.initialFocusedId,
    this.tileIconBuilder,
  });

  /// Optional cell id (`packageName` or [libraryUpdateAllFocusId]) to focus
  /// initially when present.
  final String? initialFocusedId;

  /// Optional custom icon resolver; defaults to bundled assets or cached
  /// network images backed by [imageCacheProvider].
  final LibraryTileIconBuilder? tileIconBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final installedAsync = ref.watch(installedPackagesProvider);
    final queue = ref.watch(installQueueProvider);
    final deviceInfoAsync = ref.watch(deviceInfoProvider);
    final metCapabilitiesAsync = ref.watch(metCapabilitiesProvider);
    final badgeCount = ref.watch(libraryBadgeCountProvider);
    final config = ref.watch(tshopConfigProvider);

    final catalogState = catalogAsync.value;
    final catalog = catalogState?.catalog;
    final isOnline = catalogState != null
        ? !catalogState.isOffline
        : !catalogAsync.hasError;
    final locale =
        Localizations.maybeLocaleOf(context)?.toLanguageTag() ??
        defaultCatalogLocale;

    final viewModel = buildLibraryViewModel(
      catalog: catalog,
      installedPackages:
          installedAsync.value ?? const <String, InstalledPackage>{},
      queue: queue,
      metCapabilities: metCapabilitiesAsync.value ?? const <String>{},
      deviceInfo: deviceInfoAsync.value ?? _fallbackDeviceInfo,
      locale: locale,
    );

    final metrics = _resolveShelfMetrics(MediaQuery.sizeOf(context));
    final sections = viewModel.toShelfSections(rows: metrics.rows);

    final focusController = useMemoized(
      () => ShelfFocusController(
        sections: sections,
        initialFocusedId: initialFocusedId,
      ),
    );
    useEffect(() => focusController.dispose, [focusController]);
    useListenable(focusController);

    final disposedRef = useRef(false);
    useEffect(() {
      disposedRef.value = false;
      return () {
        disposedRef.value = true;
      };
    }, const <Object?>[]);

    final appliedInitialFocus = useRef(
      initialFocusedId == null ||
          (sections.isNotEmpty &&
              focusController.focusedId == initialFocusedId),
    );

    final sectionsSignature = _sectionsSignature(sections);
    useEffect(() {
      if (listEquals(focusController.sections, sections)) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (disposedRef.value) {
          return;
        }
        focusController.updateSections(sections);
        final initial = initialFocusedId;
        if (!appliedInitialFocus.value &&
            initial != null &&
            sections.isNotEmpty) {
          appliedInitialFocus.value = true;
          focusController.focus(initial);
        }
      });
      return null;
    }, [sectionsSignature, focusController]);

    final focusedId = _resolveEffectiveFocusId(
      sections: sections,
      controllerFocusedId: focusController.focusedId,
      initialFocusedId: initialFocusedId,
    );
    final focusedItem = viewModel.itemForFocusId(focusedId);

    final stripScrollController = useScrollController();
    final tileKeys = useMemoized(() => <String, GlobalKey>{});
    GlobalKey keyFor(String id) => tileKeys.putIfAbsent(id, GlobalKey.new);

    useEffect(() {
      if (focusedId == null) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (disposedRef.value) {
          return;
        }
        final tileContext = tileKeys[focusedId]?.currentContext;
        if (tileContext == null || !tileContext.mounted) {
          return;
        }
        unawaited(
          Scrollable.ensureVisible(
            tileContext,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ).then((_) {
            if (disposedRef.value || !tileContext.mounted) {
              return Future<void>.value();
            }
            return Scrollable.ensureVisible(
              tileContext,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
            );
          }),
        );
      });
      return null;
    }, [focusedId]);

    // Auto-prompt Android's deferred PackageInstaller confirmation once per
    // awaiting session while Library is the active route.
    final awaitingKeys = <String>{
      for (final task in queue.orderedTasks)
        if (task.stage == InstallTaskStage.awaitingConfirm)
          _confirmationKey(task),
    };
    final nextAwaiting = queue.nextAwaitingConfirmation;
    final nextAwaitingKey = nextAwaiting == null
        ? null
        : _confirmationKey(nextAwaiting);
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final promptedKeys = useRef<Set<String>>(<String>{});

    useEffect(() {
      promptedKeys.value.removeWhere((key) => !awaitingKeys.contains(key));
      if (!routeIsCurrent || nextAwaiting == null || nextAwaitingKey == null) {
        return null;
      }
      if (promptedKeys.value.add(nextAwaitingKey)) {
        unawaited(
          ref
              .read(installQueueProvider.notifier)
              .confirmPendingInstall(nextAwaiting.packageName),
        );
      }
      return null;
    }, [routeIsCurrent, nextAwaitingKey, awaitingKeys.length]);

    void goToDestination(TshopDestination destination) {
      switch (destination) {
        case TshopDestination.browse:
          context.go(_browseRoute);
        case TshopDestination.library:
          context.go(_libraryRoute);
        case TshopDestination.settings:
          context.go(_settingsRoute);
      }
    }

    Future<void> activateUpdateAll() async {
      if (viewModel.updateEntries.isEmpty) {
        return;
      }
      await ref
          .read(installQueueProvider.notifier)
          .updateAll(viewModel.updateEntries);
    }

    Future<void> activateItem(LibraryEntryItem item) async {
      final packageName = item.entry.packageName;
      if (item.status == AppCatalogStatus.awaitingConfirm) {
        final launched = await ref
            .read(installQueueProvider.notifier)
            .confirmPendingInstall(packageName);
        if (!launched && context.mounted) {
          unawaited(context.push('/app/$packageName'));
        }
        return;
      }
      if (context.mounted) {
        unawaited(context.push('/app/$packageName'));
      }
    }

    void handleConfirm() {
      if (focusedId == libraryUpdateAllFocusId) {
        unawaited(activateUpdateAll());
      } else if (focusedItem != null) {
        unawaited(activateItem(focusedItem));
      }
    }

    void handleSecondary() {
      final item = focusedItem;
      if (item == null) {
        return;
      }
      switch (item.status) {
        case AppCatalogStatus.failed:
          ref
              .read(installQueueProvider.notifier)
              .dismissFailed(item.entry.packageName);
        case AppCatalogStatus.queued:
        case AppCatalogStatus.downloading:
        case AppCatalogStatus.verifying:
        case AppCatalogStatus.installing:
        case AppCatalogStatus.awaitingConfirm:
          unawaited(
            ref
                .read(installQueueProvider.notifier)
                .cancelTask(item.entry.packageName),
          );
        case AppCatalogStatus.available:
        case AppCatalogStatus.landing:
        case AppCatalogStatus.installed:
        case AppCatalogStatus.updateAvailable:
        case AppCatalogStatus.otherSource:
          break;
      }
    }

    void handleRetryOrSettings() {
      final item = focusedItem;
      if (item == null || item.status != AppCatalogStatus.failed) {
        return;
      }
      if (item.activeTask?.needsInstallPermission ?? false) {
        unawaited(
          ref
              .read(installQueueProvider.notifier)
              .openInstallPermissionSettings(),
        );
      } else {
        unawaited(
          ref.read(installQueueProvider.notifier).retryTask(item.entry),
        );
      }
    }

    void goToBrowse() {
      context.go(_browseRoute);
    }

    void handleAction(GamepadAction action) {
      switch (action) {
        case GamepadAction.up:
        case GamepadAction.down:
        case GamepadAction.left:
        case GamepadAction.right:
          if (!listEquals(focusController.sections, sections)) {
            focusController.updateSections(sections);
            final initial = initialFocusedId;
            if (!appliedInitialFocus.value &&
                initial != null &&
                sections.isNotEmpty) {
              appliedInitialFocus.value = true;
              focusController.focus(initial);
            }
          }
          focusController.move(action);
        case GamepadAction.confirm:
          handleConfirm();
        case GamepadAction.secondary:
          handleSecondary();
        case GamepadAction.searchOrRetry:
          handleRetryOrSettings();
        case GamepadAction.tabPrev:
          goToBrowse();
        case GamepadAction.tabNext:
          context.go(_settingsRoute);
        case GamepadAction.back:
        case GamepadAction.menu:
          break;
      }
    }

    ImageProvider resolveIcon(CatalogEntry entry) {
      if (tileIconBuilder != null) {
        return tileIconBuilder!(entry);
      }
      return _resolveTileIcon(
        entry: entry,
        catalogBaseUrl: config.catalogBaseUrl,
        readCacheManager: () => ref.read(imageCacheProvider),
      );
    }

    final showConfirmNote =
        queue.hasActiveWork || queue.hasAwaitingConfirmation;
    final infoStrip = _buildInfoStrip(
      viewModel: viewModel,
      focusedId: focusedId,
      focusedItem: focusedItem,
      locale: locale,
      isSquare: metrics.isSquare,
    );
    final legendItems = _legendForFocus(
      hasShelves: viewModel.isNotEmpty,
      focusedId: focusedId,
      focusedItem: focusedItem,
      onBrowse: goToBrowse,
      onConfirm: handleConfirm,
      onSecondary: handleSecondary,
      onRetryOrSettings: handleRetryOrSettings,
    );

    return TshopGamepadScope(
      onAction: handleAction,
      child: Scaffold(
        body: TshopWallpaper(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TshopTopBar(
                      destination: TshopDestination.library,
                      libraryCount: badgeCount,
                      online: isOnline,
                      onDestination: goToDestination,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: infoStrip,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fittedTileSize = _fitTileSize(
                          availableHeight: constraints.maxHeight,
                          metrics: metrics,
                        );
                        if (viewModel.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: _EmptyLibraryFrame(
                              rows: metrics.rows,
                              tileSize: fittedTileSize,
                              gap: metrics.gap,
                              tileRadius: metrics.tileRadius,
                              onBrowse: () => context.go(_browseRoute),
                            ),
                          );
                        }
                        return _LibraryShelvesStrip(
                          scrollController: stripScrollController,
                          shelves: viewModel.shelves,
                          focusedId: focusedId,
                          rows: metrics.rows,
                          tileSize: fittedTileSize,
                          gap: metrics.gap,
                          tileRadius: metrics.tileRadius,
                          locale: locale,
                          keyFor: keyFor,
                          resolveIcon: resolveIcon,
                          onFocus: focusController.focus,
                          onActivateUpdateAll: () {
                            focusController.focus(libraryUpdateAllFocusId);
                            unawaited(activateUpdateAll());
                          },
                          onActivateItem: (item) {
                            focusController.focus(item.entry.packageName);
                            unawaited(activateItem(item));
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TshopLegend(
                      left: legendItems,
                      middle: showConfirmNote
                          ? const Expanded(
                              flex: 100,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Align(
                                  child: _ConfirmNote(),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryShelvesStrip extends StatelessWidget {
  const _LibraryShelvesStrip({
    required this.scrollController,
    required this.shelves,
    required this.focusedId,
    required this.rows,
    required this.tileSize,
    required this.gap,
    required this.tileRadius,
    required this.locale,
    required this.keyFor,
    required this.resolveIcon,
    required this.onFocus,
    required this.onActivateUpdateAll,
    required this.onActivateItem,
  });

  final ScrollController scrollController;
  final List<LibraryShelfGroup> shelves;
  final String? focusedId;
  final int rows;
  final double tileSize;
  final double gap;
  final double tileRadius;
  final String locale;
  final GlobalKey Function(String id) keyFor;
  final ImageProvider Function(CatalogEntry entry) resolveIcon;
  final ValueChanged<String> onFocus;
  final VoidCallback onActivateUpdateAll;
  final ValueChanged<LibraryEntryItem> onActivateItem;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          for (final shelf in shelves)
            TshopFrame(
              label: shelf.label,
              count: shelf.headerCount,
              rows: rows,
              tileSize: tileSize,
              gap: gap,
              tiles: [
                if (shelf.hasUpdateAllLead)
                  KeyedSubtree(
                    key: keyFor(libraryUpdateAllFocusId),
                    child: MouseRegion(
                      onEnter: (_) => onFocus(libraryUpdateAllFocusId),
                      child: TshopActionTile(
                        icon: Icons.upgrade_rounded,
                        label: 'Update All',
                        focused: focusedId == libraryUpdateAllFocusId,
                        size: tileSize,
                        onTap: onActivateUpdateAll,
                      ),
                    ),
                  ),
                for (final item in shelf.items)
                  KeyedSubtree(
                    key: keyFor(item.entry.packageName),
                    child: MouseRegion(
                      onEnter: (_) => onFocus(item.entry.packageName),
                      child: TshopTile(
                        icon: resolveIcon(item.entry),
                        backdrop: _tileBackdropGradient(
                          item.entry.tile,
                          tokens,
                        ),
                        iconScale: item.entry.tile.iconScale,
                        status: libraryTileStatus(item.status),
                        context: TileContext.library,
                        progress: libraryTileProgress(item),
                        needsHardware: item.state.hasUnmetCapabilities,
                        focused: focusedId == item.entry.packageName,
                        size: tileSize,
                        radius: tileRadius,
                        semanticLabel: item.entry.name.resolve(locale),
                        onTap: () => onActivateItem(item),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyLibraryFrame extends StatelessWidget {
  const _EmptyLibraryFrame({
    required this.rows,
    required this.tileSize,
    required this.gap,
    required this.tileRadius,
    required this.onBrowse,
  });

  final int rows;
  final double tileSize;
  final double gap;
  final double tileRadius;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final text = Theme.of(context).textTheme;
    final washColor = tokens.brightness == Brightness.dark
        ? tokens.wallBottom
        : tokens.wallTop;

    return Container(
      decoration: BoxDecoration(
        color: tokens.shelf,
        borderRadius: BorderRadius.circular(TshopMetrics.shelfRadius),
        boxShadow: tokens.shelfShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TshopMetrics.shelfRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: gap,
                      children: [
                        for (var col = 0; col < _emptyGridColumns; col++)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: gap,
                            children: [
                              for (var row = 0; row < rows; row++)
                                _GhostTile(
                                  size: tileSize,
                                  radius: tileRadius,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    washColor,
                    washColor,
                    washColor.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.3, 1],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10,
                  children: [
                    Text(
                      _emptyGridMessage,
                      style: text.titleSmall?.copyWith(color: tokens.ink2),
                    ),
                    Semantics(
                      button: true,
                      label: 'Browse',
                      child: GestureDetector(
                        onTap: onBrowse,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 5,
                            children: [
                              const PadGlyph(PadButton.l),
                              Text(
                                'Browse',
                                style: text.labelMedium?.copyWith(
                                  color: tokens.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostTile extends StatelessWidget {
  const _GhostTile({required this.size, required this.radius});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.chip,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: tokens.hairline, width: 1.5),
        ),
      ),
    );
  }
}

class _ConfirmNote extends StatelessWidget {
  const _ConfirmNote();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return Text(
      _confirmNoteText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: tokens.ink3,
      ),
    );
  }
}

String? _resolveEffectiveFocusId({
  required List<ShelfSection> sections,
  required String? controllerFocusedId,
  required String? initialFocusedId,
}) {
  bool containsId(String? id) {
    if (id == null) {
      return false;
    }
    for (final section in sections) {
      if (section.itemIds.contains(id)) {
        return true;
      }
    }
    return false;
  }

  if (containsId(controllerFocusedId)) {
    return controllerFocusedId;
  }
  if (containsId(initialFocusedId)) {
    return initialFocusedId;
  }
  for (final section in sections) {
    if (section.isNotEmpty) {
      return section.itemIds.first;
    }
  }
  return null;
}

TshopInfoStrip _buildInfoStrip({
  required LibraryViewModel viewModel,
  required String? focusedId,
  required LibraryEntryItem? focusedItem,
  required String locale,
  required bool isSquare,
}) {
  if (viewModel.isEmpty) {
    return const TshopInfoStrip(
      title: _emptyTitle,
      summary: _emptySummary,
    );
  }

  if (focusedId == libraryUpdateAllFocusId || focusedItem == null) {
    final updatesCount = viewModel.updateEntries.length;
    return TshopInfoStrip(
      title: 'Update all $updatesCount apps',
      summary: _updateAllSummary,
    );
  }

  final entry = focusedItem.entry;
  final statusChip = _statusChipForItem(focusedItem);
  final chips = <TshopChip>[
    if (!isSquare || statusChip == null) TshopChip(focusedItem.categoryLabel),
    ?statusChip,
  ];

  return TshopInfoStrip(
    title: entry.name.resolve(locale),
    summary: _summaryLineForItem(focusedItem, locale),
    chips: chips,
  );
}

String _summaryLineForItem(LibraryEntryItem item, String locale) {
  if (item.status == AppCatalogStatus.failed) {
    final task = item.activeTask;
    final error = task?.errorMessage?.trim();
    if (error != null && error.isNotEmpty) {
      return error;
    }
    if (task?.needsInstallPermission ?? false) {
      return _unknownSourcesFallbackMessage;
    }
    return _genericFailureMessage;
  }
  return item.entry.summary.resolve(locale);
}

TshopChip? _statusChipForItem(LibraryEntryItem item) {
  if (item.unmetCapabilityLabels.isNotEmpty) {
    return TshopChip(
      'Needs ${item.unmetCapabilityLabels.join(', ')}',
      tone: TshopChipTone.bad,
    );
  }
  if (item.entry.rehostMode == RehostMode.landing) {
    return const TshopChip('From the publisher');
  }
  switch (item.status) {
    case AppCatalogStatus.available:
      final sizeBytes = item.state.selectedVariant?.sizeBytes;
      return sizeBytes == null ? null : TshopChip(formatByteSize(sizeBytes));
    case AppCatalogStatus.landing:
      return const TshopChip('From the publisher');
    case AppCatalogStatus.installed:
      return const TshopChip('Installed', tone: TshopChipTone.good);
    case AppCatalogStatus.updateAvailable:
      final targetVersion = item.entry.release?.versionName;
      final label = (targetVersion != null && targetVersion.isNotEmpty)
          ? 'Update to $targetVersion'
          : 'Update available';
      return TshopChip(label, tone: TshopChipTone.accent);
    case AppCatalogStatus.queued:
      return const TshopChip('Queued', tone: TshopChipTone.accent);
    case AppCatalogStatus.downloading:
      final percent = (libraryTileProgress(item) * 100).round();
      return TshopChip('Downloading $percent%', tone: TshopChipTone.accent);
    case AppCatalogStatus.verifying:
      return const TshopChip('Verifying', tone: TshopChipTone.accent);
    case AppCatalogStatus.installing:
      return const TshopChip('Installing', tone: TshopChipTone.accent);
    case AppCatalogStatus.awaitingConfirm:
      return const TshopChip('Confirm with Android', tone: TshopChipTone.good);
    case AppCatalogStatus.failed:
      final needsPermission = item.activeTask?.needsInstallPermission ?? false;
      return TshopChip(
        needsPermission ? 'Permission needed' : 'Download failed',
        tone: TshopChipTone.bad,
      );
    case AppCatalogStatus.otherSource:
      return const TshopChip('Installed from another source');
  }
}

List<LegendItem> _legendForFocus({
  required bool hasShelves,
  required String? focusedId,
  required LibraryEntryItem? focusedItem,
  required VoidCallback onBrowse,
  required VoidCallback onConfirm,
  required VoidCallback onSecondary,
  required VoidCallback onRetryOrSettings,
}) {
  if (!hasShelves) {
    return <LegendItem>[
      LegendItem(button: PadButton.l, label: 'Browse', onTap: onBrowse),
    ];
  }
  if (focusedId == libraryUpdateAllFocusId) {
    return <LegendItem>[
      const LegendItem(button: PadButton.dpad, label: 'Move'),
      LegendItem(
        button: PadButton.a,
        label: 'Update All',
        onTap: onConfirm,
      ),
    ];
  }

  final base = <LegendItem>[
    const LegendItem(button: PadButton.dpad, label: 'Move'),
    LegendItem(
      button: PadButton.a,
      label: 'Open',
      onTap: focusedItem == null ? null : onConfirm,
    ),
  ];
  final status = focusedItem?.status;
  if (status == null) {
    return base;
  }

  switch (status) {
    case AppCatalogStatus.failed:
      final needsPermission =
          focusedItem?.activeTask?.needsInstallPermission ?? false;
      return <LegendItem>[
        ...base,
        LegendItem(
          button: PadButton.y,
          label: needsPermission ? 'Settings' : 'Retry',
          onTap: onRetryOrSettings,
        ),
        LegendItem(
          button: PadButton.x,
          label: 'Dismiss',
          onTap: onSecondary,
        ),
      ];
    case AppCatalogStatus.queued:
    case AppCatalogStatus.downloading:
    case AppCatalogStatus.verifying:
    case AppCatalogStatus.installing:
    case AppCatalogStatus.awaitingConfirm:
      return <LegendItem>[
        ...base,
        LegendItem(
          button: PadButton.x,
          label: 'Cancel',
          onTap: onSecondary,
        ),
      ];
    case AppCatalogStatus.available:
    case AppCatalogStatus.landing:
    case AppCatalogStatus.installed:
    case AppCatalogStatus.updateAvailable:
    case AppCatalogStatus.otherSource:
      return base;
  }
}

_ShelfLayoutMetrics _resolveShelfMetrics(Size screenSize) {
  final isSquare = screenSize.width <= 640 && screenSize.height >= 490;
  if (isSquare) {
    return const _ShelfLayoutMetrics(
      rows: 4,
      tileSize: 70,
      gap: 7,
      tileRadius: 16,
      isSquare: true,
    );
  }
  return const _ShelfLayoutMetrics(
    rows: 3,
    tileSize: TshopMetrics.tile,
    gap: TshopMetrics.gap,
    tileRadius: TshopMetrics.tileRadius,
    isSquare: false,
  );
}

double _fitTileSize({
  required double availableHeight,
  required _ShelfLayoutMetrics metrics,
}) {
  if (!availableHeight.isFinite || availableHeight <= 0) {
    return metrics.tileSize;
  }
  final maxForHeight =
      (availableHeight -
          TshopFrame.chromeHeight -
          (metrics.rows - 1) * metrics.gap) /
      metrics.rows;
  return math
      .min(metrics.tileSize, maxForHeight)
      .clamp(_minTileSize, metrics.tileSize);
}

LinearGradient _tileBackdropGradient(CatalogTile tile, TshopTokens tokens) {
  final parsed = <Color>[
    for (final hex in tile.backdropColors) ?_parseHexColor(hex),
  ];
  final colors = switch (parsed.length) {
    0 => <Color>[tokens.chip, tokens.chip],
    1 => <Color>[parsed.first, parsed.first],
    _ => parsed,
  };
  final radians = tile.backdropAngle * math.pi / 180;
  final direction = Alignment(math.sin(radians), -math.cos(radians));
  return LinearGradient(
    begin: -direction,
    end: direction,
    colors: colors,
  );
}

Color? _parseHexColor(String raw) {
  var value = raw.trim();
  if (value.startsWith('#')) {
    value = value.substring(1);
  } else if (value.startsWith('0x') || value.startsWith('0X')) {
    value = value.substring(2);
  }
  if (value.length == 3) {
    value =
        '${value[0]}${value[0]}${value[1]}${value[1]}${value[2]}${value[2]}';
  }
  if (value.length == 6) {
    value = 'FF$value';
  }
  if (value.length != 8) {
    return null;
  }
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

ImageProvider _resolveTileIcon({
  required CatalogEntry entry,
  required Uri catalogBaseUrl,
  required CacheManager Function() readCacheManager,
}) {
  final iconUrl = entry.tile.iconUrl.trim();
  if (iconUrl.isEmpty) {
    return MemoryImage(_transparentPixelPng);
  }
  if (iconUrl.startsWith('assets/')) {
    return AssetImage(iconUrl);
  }
  final resolvedUrl = catalogBaseUrl.resolve(iconUrl).toString();
  return CachedNetworkImageProvider(
    resolvedUrl,
    cacheManager: readCacheManager(),
  );
}

String _confirmationKey(InstallTask task) {
  return '${task.packageName}:${task.sessionId ?? 0}';
}

String _sectionsSignature(List<ShelfSection> sections) {
  final buffer = StringBuffer();
  for (final section in sections) {
    buffer
      ..write(section.id)
      ..write(':')
      ..write(section.rows)
      ..write(':')
      ..write(section.itemIds.join(','))
      ..write('|');
  }
  return buffer.toString();
}
