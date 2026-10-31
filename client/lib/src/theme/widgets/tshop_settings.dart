import 'package:flutter/material.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';

const _switchDuration = Duration(milliseconds: 140);

/// Frosted panel of [TshopSettingsRow]s with hairlines between them.
class TshopSettingsPanel extends StatelessWidget {
  /// Creates a panel.
  const TshopSettingsPanel({required this.rows, super.key});

  /// Rows, top to bottom.
  final List<TshopSettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: tokens.shelf,
        borderRadius: BorderRadius.circular(TshopMetrics.shelfRadius),
        boxShadow: tokens.shelfShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: rows[i].focused || rows[i - 1].focused
                    ? Colors.transparent
                    : tokens.hairline,
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One Settings line: title, optional description, trailing control.
class TshopSettingsRow extends StatelessWidget {
  /// Creates a row.
  const TshopSettingsRow({
    required this.title,
    super.key,
    this.description,
    this.trailing,
    this.focused = false,
    this.onTap,
  });

  /// Bold label.
  final String title;

  /// Secondary line under the title.
  final String? description;

  /// Switch, value or chevron.
  final Widget? trailing;

  /// Whether the d-pad cursor is on this row.
  final bool focused;

  /// Called on tap / A.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: focused ? tokens.card : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: focused ? tokens.focusRing() : const [],
        ),
        child: Row(
          spacing: 16,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(title, style: text.titleSmall),
                  if (description != null)
                    Text(
                      description!,
                      style: text.bodySmall?.copyWith(height: 1.3),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Muted trailing value on a [TshopSettingsRow].
class TshopRowValue extends StatelessWidget {
  /// Creates a value label.
  const TshopRowValue(this.value, {super.key});

  /// Text to show, e.g. "Last checked 9:12".
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// 44 × 26 dp toggle: orange when on.
class TshopSwitch extends StatelessWidget {
  /// Creates a switch.
  const TshopSwitch({required this.value, super.key, this.onChanged});

  /// Current state.
  final bool value;

  /// Called with the new value on tap.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: _switchDuration,
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? TshopBrand.accent : tokens.chip,
            borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TshopMetrics.pillRadius),
            border: Border.all(
              color: value ? Colors.transparent : tokens.hairline,
            ),
          ),
          child: AnimatedAlign(
            duration: _switchDuration,
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40000000),
                    offset: Offset(0, 1),
                    blurRadius: 3,
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
