import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/catalog/catalog_provider.dart';
import 'package:tshop/src/features/detail/detail_art.dart';
import 'package:tshop/src/features/detail/detail_primary_action.dart';
import 'package:tshop/src/features/detail/variant_choice_dialog.dart';
import 'package:tshop/src/images/app_image_cache.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/input/gamepad_scope.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/logging/app_talker.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/focus_breath.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';
import 'package:tshop/src/theme/widgets/tshop_surfaces.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';
import 'package:tshop/src/theme/widgets/tshop_wallpaper.dart';
import 'package:url_launcher/url_launcher.dart';

const double _compactWidthBreakpoint = 660;
const double _wideTileSize = 104;
const double _compactTileSize = 88;
const double _wideTileRadius = 24;
const double _compactTileRadius = 20;
const double _wideShotWidth = 156;
const double _compactShotWidth = 150;
const double _shotAspectRatio = 16 / 9;
const double _shotGap = 10;
const double _cardsScrollStep = 96;
const int _placeholderShotCount = 4;

const BoxShadow _detailTileDropShadow = BoxShadow(
  color: Color(0x4D0A0E18),
  offset: Offset(0, 10),
  blurRadius: 24,
);

/// Callback invoked when [DetailPage] launches an external URL.
typedef UrlLauncherCallback = Future<bool> Function(Uri uri);

/// Active gamepad focus zone on [DetailPage].
@immutable
sealed class DetailFocusZone {
  /// Creates a focus zone.
  const DetailFocusZone();
}

/// Focus rests on the primary action pill (Install, Update, Open, etc.).
final class DetailFocusPrimaryAction extends DetailFocusZone {
  /// Creates the primary-action focus zone.
  const DetailFocusPrimaryAction();

  @override
  bool operator ==(Object other) => other is DetailFocusPrimaryAction;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Focus rests on the screenshot thumbnail at [index].
final class DetailFocusScreenshot extends DetailFocusZone {
  /// Creates a screenshot focus zone for [index].
  const DetailFocusScreenshot(this.index);

  /// Zero-based index into the entry's screenshot list.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is DetailFocusScreenshot && other.index == index;

  @override
  int get hashCode => Object.hash(runtimeType, index);
}

/// Full-bleed app detail screen with hero banner, primary install CTA,
/// focusable screenshot strip, and three-column info cards.
class DetailPage extends HookConsumerWidget {
  /// Creates a detail page for the catalog entry matching [packageName].
  const DetailPage({
    required this.packageName,
    super.key,
    this.onLaunchUrl,
  });

  /// Android package name identifying the entry to display.
  final String packageName;

  /// Optional URL launcher override for testing external links.
  final UrlLauncherCallback? onLaunchUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final appState = ref.watch(resolvedAppStateProvider(packageName));
    final libraryCount = ref.watch(libraryBadgeCountProvider);
    final cacheManager = ref.watch(imageCacheProvider);

    final catalogState = catalogAsync.value;
    final online = !(catalogState?.isOffline ?? false);
    final focus = useState<DetailFocusZone>(const DetailFocusPrimaryAction());
    final choosingVariant = useState(false);
    final shotsScrollController = useScrollController();
    final cardsScrollController = useScrollController();

    final screenshots =
        appState?.entry.screenshots ?? const <CatalogScreenshot>[];

    useEffect(() {
      final current = focus.value;
      if (current is DetailFocusScreenshot) {
        if (screenshots.isEmpty) {
          focus.value = const DetailFocusPrimaryAction();
        } else if (current.index >= screenshots.length) {
          focus.value = DetailFocusScreenshot(screenshots.length - 1);
        }
      }
      return null;
    }, <Object>[screenshots.length]);

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }

    Future<void> openExternalUrl(String rawUrl) async {
      final uri = Uri.tryParse(rawUrl.trim());
      if (uri == null || !uri.hasScheme) {
        return;
      }
      final launcher = onLaunchUrl ?? _defaultLaunchUrl;
      try {
        await launcher(uri);
      } on Object catch (error, stackTrace) {
        ref
            .read(talkerProvider)
            .warning('Failed to launch external URL $uri', error, stackTrace);
      }
    }

    if (appState == null) {
      return TshopGamepadScope(
        onAction: (action) {
          switch (action) {
            case GamepadAction.back:
              goBack();
            case GamepadAction.tabPrev:
              context.go('/settings');
            case GamepadAction.tabNext:
              context.go('/library');
            case GamepadAction.up:
            case GamepadAction.down:
            case GamepadAction.left:
            case GamepadAction.right:
            case GamepadAction.confirm:
            case GamepadAction.secondary:
            case GamepadAction.searchOrRetry:
            case GamepadAction.menu:
              break;
          }
        },
        child: _DetailStatusScaffold(
          libraryCount: libraryCount,
          online: online,
          message: catalogAsync.isLoading
              ? 'Loading app details…'
              : 'App not found in the catalog.',
          onDestination: (dest) => _navigateToDestination(context, dest),
          onBack: goBack,
        ),
      );
    }

    final entry = appState.entry;
    final appName = entry.name.resolve();
    final capabilityDefs =
        catalogState?.catalog.capabilityTags ?? const <CatalogCapabilityTag>[];
    final unmetCapabilityLabels = resolveCapabilityLabels(
      appState.unmetCapabilities,
      capabilityDefs,
    );
    final canUninstall = _isInstalledStatus(appState.status);
    final compact = MediaQuery.sizeOf(context).width < _compactWidthBreakpoint;
    final shotWidth = compact ? _compactShotWidth : _wideShotWidth;

    void handleInstallOrUpdate() {
      if (!online) {
        return;
      }
      if (appState.needsUserChoice && appState.compatibleVariants.length > 1) {
        choosingVariant.value = true;
        return;
      }
      unawaited(ref.read(installQueueProvider.notifier).enqueueInstall(entry));
    }

    void handleOpenApp() {
      unawaited(
        ref.read(installQueueProvider.notifier).openApp(entry.packageName),
      );
    }

    void handleGoToLibrary() {
      context.go('/library');
    }

    void handleOpenSettings() {
      final notifier = ref.read(installQueueProvider.notifier);
      unawaited(notifier.openInstallPermissionSettings());
      notifier.dismissFailed(entry.packageName);
    }

    void handleRetry() {
      unawaited(ref.read(installQueueProvider.notifier).retryTask(entry));
    }

    void handleUninstall() {
      unawaited(
        ref.read(installQueueProvider.notifier).uninstallApp(entry.packageName),
      );
    }

    void handleGoToPublisher() {
      final url = entry.landing?.url;
      final target = (url != null && url.isNotEmpty) ? url : entry.homepageUrl;
      unawaited(openExternalUrl(target));
    }

    void activatePrimaryAction() {
      switch (appState.status) {
        case AppCatalogStatus.landing:
          handleGoToPublisher();
        case AppCatalogStatus.available:
        case AppCatalogStatus.updateAvailable:
          handleInstallOrUpdate();
        case AppCatalogStatus.installed:
          handleOpenApp();
        case AppCatalogStatus.awaitingConfirm:
          handleGoToLibrary();
        case AppCatalogStatus.failed:
          if (appState.activeTask?.needsInstallPermission ?? false) {
            handleOpenSettings();
          } else {
            handleRetry();
          }
        case AppCatalogStatus.otherSource:
          handleUninstall();
        case AppCatalogStatus.queued:
        case AppCatalogStatus.downloading:
        case AppCatalogStatus.verifying:
        case AppCatalogStatus.installing:
          break;
      }
    }

    void openScreenshot(int index) {
      if (screenshots.isEmpty) {
        return;
      }
      final clamped = index.clamp(0, screenshots.length - 1);
      unawaited(context.push('/app/$packageName/screenshots/$clamped'));
    }

    void focusScreenshot(int index) {
      focus.value = DetailFocusScreenshot(index);
      _scrollThumbnailIntoView(shotsScrollController, index, shotWidth);
    }

    void handleGamepadAction(GamepadAction action) {
      switch (action) {
        case GamepadAction.back:
          goBack();
        case GamepadAction.down:
          if (focus.value is DetailFocusPrimaryAction &&
              screenshots.isNotEmpty) {
            focusScreenshot(0);
          } else {
            _nudgeScroll(cardsScrollController, _cardsScrollStep);
          }
        case GamepadAction.up:
          if (focus.value is DetailFocusScreenshot) {
            focus.value = const DetailFocusPrimaryAction();
          } else {
            _nudgeScroll(cardsScrollController, -_cardsScrollStep);
          }
        case GamepadAction.left:
          if (focus.value case DetailFocusScreenshot(:final index)) {
            focusScreenshot(math.max(0, index - 1));
          }
        case GamepadAction.right:
          if (focus.value case DetailFocusScreenshot(:final index)) {
            focusScreenshot(math.min(screenshots.length - 1, index + 1));
          }
        case GamepadAction.confirm:
          switch (focus.value) {
            case DetailFocusPrimaryAction():
              activatePrimaryAction();
            case DetailFocusScreenshot(:final index):
              openScreenshot(index);
          }
        case GamepadAction.secondary:
          if (entry.homepageUrl.isNotEmpty) {
            unawaited(openExternalUrl(entry.homepageUrl));
          }
        case GamepadAction.menu:
          if (canUninstall) {
            handleUninstall();
          }
        case GamepadAction.tabPrev:
          context.go('/settings');
        case GamepadAction.tabNext:
          context.go('/library');
        case GamepadAction.searchOrRetry:
          if (appState.status == AppCatalogStatus.failed) {
            handleRetry();
          }
      }
    }

    final activeFocus = focus.value;
    final leftLegend = <LegendItem>[
      switch (activeFocus) {
        DetailFocusPrimaryAction() => LegendItem(
          button: PadButton.a,
          label: 'Select',
          onTap: activatePrimaryAction,
        ),
        DetailFocusScreenshot(:final index) => LegendItem(
          button: PadButton.a,
          label: 'View',
          onTap: () => openScreenshot(index),
        ),
      },
      if (screenshots.isNotEmpty)
        const LegendItem(button: PadButton.dpad, label: 'Screenshots'),
      if (entry.homepageUrl.isNotEmpty)
        LegendItem(
          button: PadButton.x,
          label: 'Upstream page',
          onTap: () => unawaited(openExternalUrl(entry.homepageUrl)),
        ),
    ];

    return TshopGamepadScope(
      enabled: !choosingVariant.value,
      onAction: handleGamepadAction,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: TshopWallpaper(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: DetailHeroBanner(
                  entry: entry,
                  cacheManager: cacheManager,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TshopTopBar(
                      destination: TshopDestination.browse,
                      libraryCount: libraryCount,
                      online: online,
                      onDestination: (dest) =>
                          _navigateToDestination(context, dest),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 12,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                top: compact ? 56 : 66,
                              ),
                              child: _DetailHeader(
                                appState: appState,
                                appName: appName,
                                online: online,
                                compact: compact,
                                actionFocused:
                                    focus.value is DetailFocusPrimaryAction &&
                                    !choosingVariant.value,
                                unmetCapabilityLabels: unmetCapabilityLabels,
                                cacheManager: cacheManager,
                                onInstallOrUpdate: handleInstallOrUpdate,
                                onOpen: handleOpenApp,
                                onGoToLibrary: handleGoToLibrary,
                                onOpenSettings: handleOpenSettings,
                                onRetry: handleRetry,
                                onUninstallOtherSource: handleUninstall,
                                onGoToPublisher: handleGoToPublisher,
                              ),
                            ),
                            _DetailScreenshotStrip(
                              screenshots: screenshots,
                              focusedIndex: switch (focus.value) {
                                DetailFocusScreenshot(:final index)
                                    when !choosingVariant.value =>
                                  index,
                                _ => null,
                              },
                              shotWidth: shotWidth,
                              controller: shotsScrollController,
                              cacheManager: cacheManager,
                              onHover: (index) =>
                                  focus.value = DetailFocusScreenshot(index),
                              onTap: openScreenshot,
                            ),
                            Expanded(
                              child: _DetailCardsViewport(
                                controller: cardsScrollController,
                                child: _DetailCardsGrid(
                                  appState: appState,
                                  unmetCapabilityLabels: unmetCapabilityLabels,
                                  compact: compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TshopLegend(
                      left: leftLegend,
                      right: <LegendItem>[
                        LegendItem(
                          button: PadButton.b,
                          label: 'Back',
                          onTap: goBack,
                        ),
                      ],
                      middle: canUninstall
                          ? TshopLegendHint(
                              item: LegendItem(
                                button: PadButton.plus,
                                label: 'Uninstall',
                                onTap: handleUninstall,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              if (choosingVariant.value &&
                  appState.compatibleVariants.isNotEmpty)
                Positioned.fill(
                  child: VariantChoiceDialog(
                    appName: appName,
                    variants: appState.compatibleVariants,
                    onSelected: (variant) {
                      choosingVariant.value = false;
                      unawaited(
                        ref
                            .read(installQueueProvider.notifier)
                            .enqueueInstall(entry, variantOverride: variant),
                      );
                    },
                    onCancel: () => choosingVariant.value = false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.appState,
    required this.appName,
    required this.online,
    required this.compact,
    required this.actionFocused,
    required this.unmetCapabilityLabels,
    required this.cacheManager,
    required this.onInstallOrUpdate,
    required this.onOpen,
    required this.onGoToLibrary,
    required this.onOpenSettings,
    required this.onRetry,
    required this.onUninstallOtherSource,
    required this.onGoToPublisher,
  });

  final ResolvedAppState appState;
  final String appName;
  final bool online;
  final bool compact;
  final bool actionFocused;
  final List<String> unmetCapabilityLabels;
  final BaseCacheManager cacheManager;
  final VoidCallback onInstallOrUpdate;
  final VoidCallback onOpen;
  final VoidCallback onGoToLibrary;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;
  final VoidCallback onUninstallOtherSource;
  final VoidCallback onGoToPublisher;

  @override
  Widget build(BuildContext context) {
    final entry = appState.entry;
    final tokens = context.tshop;
    final textTheme = Theme.of(context).textTheme;
    final tileSize = compact ? _compactTileSize : _wideTileSize;
    final tileRadius = compact ? _compactTileRadius : _wideTileRadius;
    final gradient = parseBackdropGradient(
      entry.tile.backdropColors,
      entry.tile.backdropAngle,
    );

    final tile = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tileRadius),
        boxShadow: <BoxShadow>[
          _detailTileDropShadow,
          BoxShadow(color: tokens.focusGap, spreadRadius: 4),
        ],
      ),
      child: entry.tile.iconUrl.isNotEmpty
          ? TshopTile(
              icon: CachedNetworkImageProvider(
                entry.tile.iconUrl,
                cacheManager: cacheManager,
              ),
              backdrop: gradient,
              iconScale: entry.tile.iconScale,
              size: tileSize,
              radius: tileRadius,
              semanticLabel: appName,
            )
          : Container(
              width: tileSize,
              height: tileSize,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(tileRadius),
              ),
              foregroundDecoration: BoxDecoration(
                gradient: tileSheen,
                borderRadius: BorderRadius.circular(tileRadius),
              ),
            ),
    );

    final versionText =
        entry.rehostMode == RehostMode.landing || entry.release == null
        ? null
        : _formatVersionTag(entry.release!.versionName);

    final titleColumn = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.displaySmall?.copyWith(color: tokens.ink),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              Text(entry.publisher, style: textTheme.labelMedium),
              Text(
                '•',
                style: textTheme.labelMedium?.copyWith(color: tokens.ink3),
              ),
              Text(entry.category, style: textTheme.labelMedium),
              if (versionText != null) ...[
                Text(
                  '•',
                  style: textTheme.labelMedium?.copyWith(color: tokens.ink3),
                ),
                Text(versionText, style: textTheme.labelMedium),
              ],
            ],
          ),
        ],
      ),
    );

    final primaryAction = DetailPrimaryAction(
      appState: appState,
      online: online,
      focused: actionFocused,
      unmetCapabilityLabels: unmetCapabilityLabels,
      onInstallOrUpdate: onInstallOrUpdate,
      onOpen: onOpen,
      onGoToLibrary: onGoToLibrary,
      onOpenSettings: onOpenSettings,
      onRetry: onRetry,
      onUninstallOtherSource: onUninstallOtherSource,
      onGoToPublisher: onGoToPublisher,
      compact: compact,
    );

    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 16,
            children: [
              tile,
              Expanded(child: titleColumn),
            ],
          ),
          primaryAction,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 16,
      children: [
        tile,
        Expanded(child: titleColumn),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: primaryAction,
        ),
      ],
    );
  }
}

class _DetailScreenshotStrip extends StatelessWidget {
  const _DetailScreenshotStrip({
    required this.screenshots,
    required this.focusedIndex,
    required this.shotWidth,
    required this.controller,
    required this.cacheManager,
    required this.onHover,
    required this.onTap,
  });

  final List<CatalogScreenshot> screenshots;
  final int? focusedIndex;
  final double shotWidth;
  final ScrollController controller;
  final BaseCacheManager cacheManager;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final shotHeight = shotWidth / _shotAspectRatio;
    return SizedBox(
      height: shotHeight,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          spacing: _shotGap,
          children: screenshots.isNotEmpty
              ? <Widget>[
                  for (var i = 0; i < screenshots.length; i++)
                    _ScreenshotThumb(
                      screenshot: screenshots[i],
                      index: i,
                      width: shotWidth,
                      height: shotHeight,
                      focused: focusedIndex == i,
                      cacheManager: cacheManager,
                      onHover: () => onHover(i),
                      onTap: () => onTap(i),
                    ),
                ]
              : <Widget>[
                  for (var i = 0; i < _placeholderShotCount; i++)
                    _EmptyScreenshotPlaceholder(
                      width: shotWidth,
                      height: shotHeight,
                    ),
                ],
        ),
      ),
    );
  }
}

class _ScreenshotThumb extends HookWidget {
  const _ScreenshotThumb({
    required this.screenshot,
    required this.index,
    required this.width,
    required this.height,
    required this.focused,
    required this.cacheManager,
    required this.onHover,
    required this.onTap,
  });

  final CatalogScreenshot screenshot;
  final int index;
  final double width;
  final double height;
  final bool focused;
  final BaseCacheManager cacheManager;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final breath = useFocusBreath(focused: focused);
    final radius = BorderRadius.circular(12);
    final placeholder = _EmptyScreenshotPlaceholder(
      width: width,
      height: height,
    );

    return Semantics(
      button: true,
      selected: focused,
      excludeSemantics: true,
      label: 'Screenshot ${index + 1}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedSlide(
            offset: Offset(0, focused ? -2 / height : 0),
            duration: const Duration(milliseconds: 120),
            curve: focusLiftCurve,
            child: AnimatedScale(
              scale: focused ? 1.04 : 1,
              duration: const Duration(milliseconds: 120),
              curve: focusLiftCurve,
              child: AnimatedBuilder(
                animation: breath,
                builder: (context, child) => Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: radius,
                    boxShadow: focused
                        ? tokens.focusRing(breath: breath.value)
                        : tokens.cardShadow,
                  ),
                  child: child,
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: CachedNetworkImage(
                    imageUrl: screenshot.thumbUrl,
                    cacheManager: cacheManager,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => placeholder,
                    errorWidget: (context, url, error) => placeholder,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyScreenshotPlaceholder extends StatelessWidget {
  const _EmptyScreenshotPlaceholder({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Screenshot',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: tokens.ink3,
        ),
      ),
    );
  }
}

class _DetailCardsViewport extends StatelessWidget {
  const _DetailCardsViewport({
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Colors.white, Colors.white, Colors.transparent],
        stops: <double>[0, 0.78, 1],
      ).createShader(bounds),
      child: SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.only(top: 2, bottom: 24),
        child: child,
      ),
    );
  }
}

class _DetailCardsGrid extends StatelessWidget {
  const _DetailCardsGrid({
    required this.appState,
    required this.unmetCapabilityLabels,
    required this.compact,
  });

  final ResolvedAppState appState;
  final List<String> unmetCapabilityLabels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final entry = appState.entry;
    final tokens = context.tshop;
    final summary = entry.summary.resolve().trim();
    final paragraphs = entry.description
        .resolve()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final compatNotes = entry.compatNotes?.resolve().trim();

    final aboutCard = TshopCard(
      heading: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (summary.isNotEmpty)
            Text(
              summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          for (final paragraph in paragraphs) Text(paragraph),
          if (compatNotes != null && compatNotes.isNotEmpty)
            Text(
              compatNotes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.ink2,
              ),
            ),
        ],
      ),
    );

    final release = entry.release;
    final changelogHeading =
        entry.rehostMode == RehostMode.landing || release == null
        ? 'Release notes'
        : 'New in ${release.versionName}';
    final changelogLines = entry.changelogs.isNotEmpty
        ? entry.changelogs.first.notes
              .resolve()
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList()
        : const <String>[];

    final changelogCard = TshopCard(
      heading: changelogHeading,
      child: changelogLines.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                for (final line in changelogLines)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      const Text('•'),
                      Expanded(child: Text(line)),
                    ],
                  ),
              ],
            )
          : const Text('Release notes from upstream.'),
    );

    final releasedText = release == null
        ? '—'
        : formatReleaseDate(release.releasedAt);
    final sizeText = entry.rehostMode == RehostMode.landing
        ? 'From the publisher'
        : (appState.selectedVariant == null
              ? '—'
              : formatByteSize(appState.selectedVariant!.sizeBytes));
    final installed = appState.installedPackage;
    final installedText = installed == null
        ? null
        : formatInstalledVersion(installed.versionCode, entry.changelogs);

    final detailsCard = TshopCard(
      heading: 'Details',
      child: _DetailFactsSection(
        releasedText: releasedText,
        sizeText: sizeText,
        installedText: installedText,
        unmetCapabilityLabels: unmetCapabilityLabels,
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Expanded(flex: 13, child: aboutCard),
              Expanded(flex: 10, child: changelogCard),
            ],
          ),
          detailsCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Expanded(flex: 14, child: aboutCard),
        Expanded(flex: 10, child: changelogCard),
        Expanded(flex: 10, child: detailsCard),
      ],
    );
  }
}

class _DetailFactsSection extends StatelessWidget {
  const _DetailFactsSection({
    required this.releasedText,
    required this.sizeText,
    required this.unmetCapabilityLabels,
    this.installedText,
  });

  final String releasedText;
  final String sizeText;
  final String? installedText;
  final List<String> unmetCapabilityLabels;

  @override
  Widget build(BuildContext context) {
    if (unmetCapabilityLabels.isEmpty) {
      return TshopFacts(<(String, String)>[
        ('Released', releasedText),
        ('Size', sizeText),
        if (installedText != null) ('Installed', installedText!),
        ('Needs', '✓ Nothing special'),
      ]);
    }

    final tokens = context.tshop;
    final style = Theme.of(context).textTheme.labelMedium;
    final rows = <(String, Widget)>[
      (
        'Released',
        Text(releasedText, style: style?.copyWith(color: tokens.ink)),
      ),
      (
        'Size',
        Text(sizeText, style: style?.copyWith(color: tokens.ink)),
      ),
      if (installedText != null)
        (
          'Installed',
          Text(installedText!, style: style?.copyWith(color: tokens.ink)),
        ),
      (
        'Needs',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            for (final label in unmetCapabilityLabels)
              Text(
                '✕ $label',
                style: style?.copyWith(color: TshopBrand.bad),
              ),
          ],
        ),
      ),
    ];

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const <int, TableColumnWidth>{1: FlexColumnWidth()},
      children: [
        for (final (term, valueWidget) in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: Text(term, style: style?.copyWith(color: tokens.ink3)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: valueWidget,
              ),
            ],
          ),
      ],
    );
  }
}

class _DetailStatusScaffold extends StatelessWidget {
  const _DetailStatusScaffold({
    required this.libraryCount,
    required this.online,
    required this.message,
    required this.onDestination,
    required this.onBack,
  });

  final int libraryCount;
  final bool online;
  final String message;
  final ValueChanged<TshopDestination> onDestination;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TshopWallpaper(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TshopTopBar(
                destination: TshopDestination.browse,
                libraryCount: libraryCount,
                online: online,
                onDestination: onDestination,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.ink2,
                    ),
                  ),
                ),
              ),
              TshopLegend(
                left: const <LegendItem>[],
                right: <LegendItem>[
                  LegendItem(
                    button: PadButton.b,
                    label: 'Back',
                    onTap: onBack,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _defaultLaunchUrl(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

void _navigateToDestination(
  BuildContext context,
  TshopDestination destination,
) {
  switch (destination) {
    case TshopDestination.browse:
      context.go('/');
    case TshopDestination.library:
      context.go('/library');
    case TshopDestination.settings:
      context.go('/settings');
  }
}

bool _isInstalledStatus(AppCatalogStatus status) {
  return switch (status) {
    AppCatalogStatus.installed ||
    AppCatalogStatus.updateAvailable ||
    AppCatalogStatus.otherSource => true,
    AppCatalogStatus.available ||
    AppCatalogStatus.landing ||
    AppCatalogStatus.queued ||
    AppCatalogStatus.downloading ||
    AppCatalogStatus.verifying ||
    AppCatalogStatus.installing ||
    AppCatalogStatus.awaitingConfirm ||
    AppCatalogStatus.failed => false,
  };
}

String _formatVersionTag(String versionName) {
  final trimmed = versionName.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed;
  }
  return 'v$trimmed';
}

void _scrollThumbnailIntoView(
  ScrollController controller,
  int index,
  double shotWidth,
) {
  if (!controller.hasClients) {
    return;
  }
  final position = controller.position;
  final itemExtent = shotWidth + _shotGap;
  final itemStart = index * itemExtent;
  final itemEnd = itemStart + shotWidth;
  final viewportStart = position.pixels;
  final viewportEnd = viewportStart + position.viewportDimension;

  double? target;
  if (itemStart < viewportStart) {
    target = itemStart;
  } else if (itemEnd > viewportEnd) {
    target = itemEnd - position.viewportDimension;
  }
  if (target != null) {
    controller.animateTo(
      target.clamp(0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }
}

void _nudgeScroll(ScrollController controller, double delta) {
  if (!controller.hasClients) {
    return;
  }
  final position = controller.position;
  if (position.maxScrollExtent <= 0) {
    return;
  }
  final target = (position.pixels + delta).clamp(0.0, position.maxScrollExtent);
  controller.animateTo(
    target,
    duration: const Duration(milliseconds: 160),
    curve: Curves.easeOut,
  );
}
