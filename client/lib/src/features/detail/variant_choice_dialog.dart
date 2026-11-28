import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/input/gamepad_scope.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/focus_breath.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';

const Color _scrimOverlayColor = Color(0x6B0A0E18);
const double _backdropBlurSigma = 6;
const double _maxDialogWidth = 440;
const double _dialogWidthFraction = 0.88;

const BoxShadow _dialogLiftShadow = BoxShadow(
  color: Color(0x590A0E18),
  offset: Offset(0, 24),
  blurRadius: 60,
);

/// Modal overlay allowing the user to pick between compatible APK variants
/// when a release marks its variants as a genuine user choice.
class VariantChoiceDialog extends HookConsumerWidget {
  /// Creates a variant choice overlay for [appName].
  const VariantChoiceDialog({
    required this.appName,
    required this.variants,
    required this.onSelected,
    required this.onCancel,
    super.key,
    this.initialIndex = 0,
  });

  /// Display name of the app being installed.
  final String appName;

  /// Compatible APK variants presented as choices.
  final List<CatalogVariant> variants;

  /// Invoked when the user confirms a variant via gamepad `[A]` or tap.
  final ValueChanged<CatalogVariant> onSelected;

  /// Invoked when the user dismisses the dialog via `[B]` or backdrop tap.
  final VoidCallback onCancel;

  /// Initially highlighted variant index.
  final int initialIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tshop;
    final textTheme = Theme.of(context).textTheme;
    final selectedIndex = useState(
      variants.isEmpty ? 0 : initialIndex.clamp(0, variants.length - 1),
    );

    useEffect(() {
      if (variants.isNotEmpty && selectedIndex.value >= variants.length) {
        selectedIndex.value = variants.length - 1;
      }
      return null;
    }, <Object>[variants.length]);

    void handleAction(GamepadAction action) {
      switch (action) {
        case GamepadAction.up:
          if (variants.isNotEmpty) {
            selectedIndex.value = math.max(0, selectedIndex.value - 1);
          }
        case GamepadAction.down:
          if (variants.isNotEmpty) {
            selectedIndex.value = math.min(
              variants.length - 1,
              selectedIndex.value + 1,
            );
          }
        case GamepadAction.confirm:
          if (variants.isNotEmpty) {
            onSelected(variants[selectedIndex.value]);
          }
        case GamepadAction.back:
          onCancel();
        case GamepadAction.left:
        case GamepadAction.right:
        case GamepadAction.secondary:
        case GamepadAction.searchOrRetry:
        case GamepadAction.tabPrev:
        case GamepadAction.tabNext:
        case GamepadAction.menu:
          break;
      }
    }

    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = math.min(
      _maxDialogWidth,
      viewportWidth * _dialogWidthFraction,
    );

    return TshopGamepadScope(
      onAction: handleAction,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: 'Choose a $appName build',
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onCancel,
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _backdropBlurSigma,
                  sigmaY: _backdropBlurSigma,
                ),
                child: const ColoredBox(color: _scrimOverlayColor),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(
                      TshopMetrics.shelfRadius,
                    ),
                    boxShadow: <BoxShadow>[
                      ...tokens.cardShadow,
                      _dialogLiftShadow,
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(
                            'INSTALL ${appName.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: tokens.ink3,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.48,
                            ),
                          ),
                          Text(
                            'Which build?',
                            style: textTheme.headlineSmall?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: tokens.ink,
                            ),
                          ),
                        ],
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          clipBehavior: Clip.none,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 2,
                            children: [
                              for (var i = 0; i < variants.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    indent: 14,
                                    endIndent: 14,
                                    color:
                                        i == selectedIndex.value ||
                                            i - 1 == selectedIndex.value
                                        ? Colors.transparent
                                        : tokens.hairline,
                                  ),
                                _VariantOptionRow(
                                  title: _variantLabel(variants[i], i),
                                  note: _variantNote(variants[i]),
                                  sizeLabel: formatByteSize(
                                    variants[i].sizeBytes,
                                  ),
                                  focused: i == selectedIndex.value,
                                  onHover: () => selectedIndex.value = i,
                                  onTap: () {
                                    selectedIndex.value = i;
                                    onSelected(variants[i]);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      TshopLegend(
                        left: <LegendItem>[
                          LegendItem(
                            button: PadButton.a,
                            label: 'Install',
                            onTap: variants.isEmpty
                                ? null
                                : () => onSelected(
                                    variants[selectedIndex.value],
                                  ),
                          ),
                        ],
                        right: <LegendItem>[
                          LegendItem(
                            button: PadButton.b,
                            label: 'Cancel',
                            onTap: onCancel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantOptionRow extends HookWidget {
  const _VariantOptionRow({
    required this.title,
    required this.sizeLabel,
    required this.focused,
    required this.onHover,
    required this.onTap,
    this.note,
  });

  final String title;
  final String? note;
  final String sizeLabel;
  final bool focused;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final textTheme = Theme.of(context).textTheme;
    final breath = useFocusBreath(focused: focused);

    return Semantics(
      button: true,
      selected: focused,
      label: '$title, $sizeLabel',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: breath,
            builder: (context, child) => Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: focused ? tokens.card : Colors.transparent,
                borderRadius: BorderRadius.circular(TshopMetrics.cardRadius),
                boxShadow: focused
                    ? tokens.focusRing(breath: breath.value)
                    : const <BoxShadow>[],
              ),
              child: child,
            ),
            child: Row(
              spacing: 16,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: tokens.ink,
                        ),
                      ),
                      if (note != null)
                        Text(
                          note!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.ink2,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  sizeLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: tokens.ink2,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
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

String _variantLabel(CatalogVariant variant, int index) {
  final resolved = variant.label?.resolve().trim();
  if (resolved != null && resolved.isNotEmpty) {
    return resolved;
  }
  if (variant.abis.isNotEmpty) {
    return variant.abis.join(', ');
  }
  return 'Build ${index + 1}';
}

String? _variantNote(CatalogVariant variant) {
  final resolved = variant.note?.resolve().trim();
  if (resolved == null || resolved.isEmpty) {
    return null;
  }
  return resolved;
}
