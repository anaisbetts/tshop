import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_button.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';

const int _ghostColumnCount = 10;
const double _minTopBarWidth = 640;

/// Top navigation bar for Browse pairing [TshopTopBar] with a tappable search
/// pill positioned in the exact search slot.
class BrowseTopBar extends StatelessWidget {
  /// Creates a [BrowseTopBar].
  const BrowseTopBar({
    required this.libraryCount,
    required this.online,
    required this.showSearch,
    required this.compact,
    required this.onDestination,
    super.key,
    this.query,
    this.time = '9:41',
    this.onOpenSearch,
    this.onClearSearch,
  });

  /// Badge count displayed on the Library tab.
  final int libraryCount;

  /// Whether the catalog is currently online.
  final bool online;

  /// Whether the search trigger pill is shown.
  final bool showSearch;

  /// Whether the viewport is using compact/square dimensions.
  final bool compact;

  /// Active committed search query, if any.
  final String? query;

  /// Formatted clock string displayed in the status cluster.
  final String time;

  /// Called when a destination tab is tapped.
  final ValueChanged<TshopDestination> onDestination;

  /// Called when the idle search pill is tapped.
  final VoidCallback? onOpenSearch;

  /// Called when the active search pill is tapped to clear the filter.
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final topBar = TshopTopBar(
      destination: TshopDestination.browse,
      libraryCount: libraryCount,
      online: online,
      time: time,
      onDestination: onDestination,
    );

    final Widget bar;
    if (!showSearch) {
      bar = topBar;
    } else {
      final activeQuery = query?.trim() ?? '';
      final isActive = activeQuery.isNotEmpty;
      bar = Stack(
        alignment: Alignment.centerRight,
        children: [
          topBar,
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                _InteractiveSearchPill(
                  query: activeQuery,
                  compact: compact,
                  onTap: isActive ? onClearSearch : onOpenSearch,
                ),
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0,
                      child: _StatusClusterSpacer(time: time),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite ||
            constraints.maxWidth >= _minTopBarWidth) {
          return bar;
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(width: _minTopBarWidth, child: bar),
        );
      },
    );
  }
}

/// Frosted ghost-tile frame used for loading, offline-empty, and zero-result
/// search states, matching Storybook's `.ts-frame--empty`.
class BrowseEmptyFrame extends StatelessWidget {
  /// Creates a [BrowseEmptyFrame] with [child] centered over ghost tiles.
  const BrowseEmptyFrame({
    required this.rows,
    required this.tileSize,
    required this.gap,
    required this.tileRadius,
    required this.child,
    super.key,
  });

  /// Number of ghost rows per column.
  final int rows;

  /// Edge length of each ghost tile.
  final double tileSize;

  /// Spacing between ghost tiles.
  final double gap;

  /// Corner radius of each ghost tile.
  final double tileRadius;

  /// Centered overlay message and action controls.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final veilColor = tokens.brightness == Brightness.dark
        ? tokens.wallBottom
        : tokens.wallTop;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.shelf,
        borderRadius: BorderRadius.circular(TshopMetrics.shelfRadius),
        boxShadow: tokens.shelfShadow,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: gap,
                    children: [
                      for (var col = 0; col < _ghostColumnCount; col++)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: gap,
                          children: [
                            for (var row = 0; row < rows; row++)
                              Container(
                                width: tileSize,
                                height: tileSize,
                                decoration: BoxDecoration(
                                  color: tokens.chip,
                                  borderRadius: BorderRadius.circular(
                                    tileRadius,
                                  ),
                                  border: Border.all(
                                    color: tokens.hairline,
                                    width: 1.5,
                                  ),
                                ),
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
                radius: 0.72,
                colors: <Color>[
                  veilColor.withValues(alpha: 0.94),
                  veilColor.withValues(alpha: 0.55),
                  veilColor.withValues(alpha: 0),
                ],
                stops: const <double>[0, 0.45, 1],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Commit-then-view search modal overlay styled after Storybook's `.ts-dialog`.
class BrowseSearchOverlay extends HookWidget {
  /// Creates a [BrowseSearchOverlay].
  const BrowseSearchOverlay({
    required this.initialQuery,
    required this.onCommit,
    required this.onCancel,
    super.key,
  });

  /// Pre-filled search text when opening the modal.
  final String initialQuery;

  /// Invoked when the user presses Enter or taps Search.
  final ValueChanged<String> onCommit;

  /// Invoked when the user presses Escape, taps Cancel, or taps the backdrop.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final textTheme = Theme.of(context).textTheme;
    final controller = useTextEditingController(text: initialQuery);
    final focusNode = useFocusNode();

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        focusNode.requestFocus();
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      });
      return null;
    }, [focusNode, controller]);

    void submit() => onCommit(controller.text.trim());

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCancel,
            child: const ColoredBox(color: Color(0x6B0A0E18)),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    decoration: BoxDecoration(
                      color: tokens.card,
                      borderRadius: BorderRadius.circular(
                        TshopMetrics.shelfRadius,
                      ),
                      boxShadow: <BoxShadow>[
                        ...tokens.cardShadow,
                        const BoxShadow(
                          color: Color(0x590A0E18),
                          offset: Offset(0, 24),
                          blurRadius: 60,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 10,
                      children: [
                        Text(
                          'SEARCH CATALOG',
                          style: textTheme.labelMedium?.copyWith(
                            color: tokens.ink3,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.48,
                          ),
                        ),
                        Text(
                          'Find an app',
                          style: textTheme.headlineSmall?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextField(
                          key: const ValueKey<String>('browse-search-input'),
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => submit(),
                          style: textTheme.bodyMedium?.copyWith(
                            color: tokens.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: 'App name, genre, or tag…',
                            hintStyle: textTheme.bodyMedium?.copyWith(
                              color: tokens.ink3,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: tokens.ink2,
                            ),
                            filled: true,
                            fillColor: tokens.chip,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                TshopMetrics.pillRadius,
                              ),
                              borderSide: BorderSide(color: tokens.hairline),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                TshopMetrics.pillRadius,
                              ),
                              borderSide: BorderSide(color: tokens.hairline),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                TshopMetrics.pillRadius,
                              ),
                              borderSide: const BorderSide(
                                color: TshopBrand.accent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          spacing: 8,
                          children: [
                            TshopButton(
                              label: 'Cancel',
                              pad: PadButton.b,
                              tone: TshopButtonTone.ghost,
                              small: true,
                              onPressed: onCancel,
                            ),
                            TshopButton(
                              label: 'Search',
                              small: true,
                              onPressed: submit,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveSearchPill extends StatelessWidget {
  const _InteractiveSearchPill({
    required this.query,
    required this.compact,
    this.onTap,
  });

  final String query;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final active = query.isNotEmpty;
    final ink = active ? tokens.card : tokens.ink2;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: ink);

    return Semantics(
      button: true,
      label: active ? 'Clear search $query' : 'Search catalog',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const ValueKey<String>('browse-search-pill'),
          onTap: onTap,
          child: Container(
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
                  ? <Widget>[
                      Icon(Icons.search_rounded, size: 16, color: ink),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact ? 96 : 140,
                        ),
                        child: Text(
                          query,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                      ),
                      const PadGlyph(PadButton.x),
                    ]
                  : <Widget>[
                      const PadGlyph(PadButton.y),
                      Text('Search', style: style),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusClusterSpacer extends StatelessWidget {
  const _StatusClusterSpacer({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    final uiStyle = Theme.of(context).textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          const SizedBox(width: 18, height: 14),
          Text(
            time,
            style: uiStyle?.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 22, height: 12),
        ],
      ),
    );
  }
}
