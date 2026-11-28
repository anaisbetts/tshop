import 'package:material_ui/material_ui.dart';
import 'package:tshop/src/features/detail/detail_art.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/tshop_button.dart';

const String _offlineExplainer =
    "You're offline. Browsing still works from the saved catalog.";
const String _installPermissionExplainer =
    'Allow tShop to install unknown apps, then retry.';
const String _otherSourceExplainer =
    'Signed by someone else. Uninstall it so tShop can manage updates.';

/// Primary action pill and optional one-line explainer for an app on Detail.
class DetailPrimaryAction extends StatelessWidget {
  /// Creates a primary action block for [appState].
  const DetailPrimaryAction({
    required this.appState,
    required this.online,
    required this.focused,
    required this.unmetCapabilityLabels,
    required this.onInstallOrUpdate,
    required this.onOpen,
    required this.onGoToLibrary,
    required this.onOpenSettings,
    required this.onRetry,
    required this.onUninstallOtherSource,
    required this.onGoToPublisher,
    super.key,
    this.compact = false,
  });

  /// Resolved catalog, installed, and queue state for the entry.
  final ResolvedAppState appState;

  /// Whether the client currently has network connectivity.
  final bool online;

  /// Whether gamepad focus currently rests on this primary action.
  final bool focused;

  /// Human-readable labels for unmet device capabilities.
  final List<String> unmetCapabilityLabels;

  /// Invoked when the user triggers Install or Update.
  final VoidCallback onInstallOrUpdate;

  /// Invoked when the user triggers Open on an installed app.
  final VoidCallback onOpen;

  /// Invoked when the user activates `Ready · confirm in Library`.
  final VoidCallback onGoToLibrary;

  /// Invoked when the user activates `Open Settings` for install permission.
  final VoidCallback onOpenSettings;

  /// Invoked when the user activates `Retry` after a failure.
  final VoidCallback onRetry;

  /// Invoked when the user activates `Installed from another source`.
  final VoidCallback onUninstallOtherSource;

  /// Invoked when the user activates `Go to Publisher` for a landing entry.
  final VoidCallback onGoToPublisher;

  /// Uses a single horizontal row with left-aligned explainer on narrow widths.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final button = _buildButton();
    final explainer = _resolveExplainer();

    if (compact) {
      return Row(
        spacing: 12,
        children: [
          button,
          if (explainer != null)
            Expanded(
              child: _ExplainerText(
                text: explainer.text,
                color: explainer.isWarning ? tokens.badInk : tokens.ink2,
                textAlign: TextAlign.left,
              ),
            ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 6,
        children: [
          button,
          if (explainer != null)
            _ExplainerText(
              text: explainer.text,
              color: explainer.isWarning ? tokens.badInk : tokens.ink2,
              textAlign: TextAlign.right,
            ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    final entry = appState.entry;
    final task = appState.activeTask;
    final selectedVariant = appState.selectedVariant;

    switch (appState.status) {
      case AppCatalogStatus.landing:
        return TshopButton(
          label: 'Go to Publisher',
          focused: focused,
          onPressed: onGoToPublisher,
        );
      case AppCatalogStatus.available:
        if (!online) {
          return TshopButton(
            label: 'Install when online',
            tone: TshopButtonTone.disabled,
            focused: focused,
          );
        }
        return TshopButton(
          label: 'Install',
          sub: selectedVariant == null
              ? null
              : formatByteSize(selectedVariant.sizeBytes),
          focused: focused,
          onPressed: onInstallOrUpdate,
        );
      case AppCatalogStatus.updateAvailable:
        if (!online) {
          return TshopButton(
            label: 'Install when online',
            tone: TshopButtonTone.disabled,
            focused: focused,
          );
        }
        final targetVersion = entry.release?.versionName;
        return TshopButton(
          label: 'Update',
          sub: targetVersion == null || targetVersion.isEmpty
              ? null
              : 'to $targetVersion',
          focused: focused,
          onPressed: onInstallOrUpdate,
        );
      case AppCatalogStatus.installed:
        return TshopButton(
          label: 'Open',
          tone: TshopButtonTone.open,
          focused: focused,
          onPressed: onOpen,
        );
      case AppCatalogStatus.queued:
        return TshopProgressButton(
          value: 0,
          label: 'Queued…',
          focused: focused,
        );
      case AppCatalogStatus.downloading:
        final progress = (task?.progress ?? 0).clamp(0.0, 1.0);
        final percent = (progress * 100).round();
        return TshopProgressButton(
          value: progress,
          label: 'Downloading $percent%',
          focused: focused,
        );
      case AppCatalogStatus.verifying:
        return TshopProgressButton(
          value: 1,
          label: 'Verifying…',
          focused: focused,
        );
      case AppCatalogStatus.installing:
        return TshopProgressButton(
          value: 1,
          label: 'Installing…',
          focused: focused,
        );
      case AppCatalogStatus.awaitingConfirm:
        return Semantics(
          button: true,
          selected: focused,
          label: 'Ready · confirm in Library',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onGoToLibrary,
              child: TshopProgressButton(
                value: 1,
                label: 'Ready · confirm in Library',
                focused: focused,
              ),
            ),
          ),
        );
      case AppCatalogStatus.failed:
        if (task?.needsInstallPermission ?? false) {
          return TshopButton(
            label: 'Open Settings',
            tone: TshopButtonTone.retry,
            focused: focused,
            onPressed: onOpenSettings,
          );
        }
        return TshopButton(
          label: 'Retry',
          tone: TshopButtonTone.retry,
          focused: focused,
          onPressed: onRetry,
        );
      case AppCatalogStatus.otherSource:
        return TshopButton(
          label: 'Installed from another source',
          tone: TshopButtonTone.quiet,
          focused: focused,
          onPressed: onUninstallOtherSource,
        );
    }
  }

  _Explainer? _resolveExplainer() {
    final entry = appState.entry;
    final task = appState.activeTask;
    final unmetWarning = unmetCapabilityLabels.isEmpty
        ? null
        : "Needs ${unmetCapabilityLabels.join(', ')}. "
              "This device doesn't report it.";

    switch (appState.status) {
      case AppCatalogStatus.landing:
        final reason = entry.landing?.reason.resolve().trim();
        if (reason == null || reason.isEmpty) {
          return null;
        }
        return _Explainer(text: reason);
      case AppCatalogStatus.available:
        if (!online) {
          return const _Explainer(text: _offlineExplainer);
        }
        if (unmetWarning != null) {
          return _Explainer(text: unmetWarning, isWarning: true);
        }
        return null;
      case AppCatalogStatus.updateAvailable:
        if (!online) {
          return const _Explainer(text: _offlineExplainer);
        }
        if (unmetWarning != null) {
          return _Explainer(text: unmetWarning, isWarning: true);
        }
        final installed = appState.installedPackage;
        if (installed == null) {
          return null;
        }
        final installedLabel = formatInstalledVersion(
          installed.versionCode,
          entry.changelogs,
        );
        return _Explainer(text: 'Installed $installedLabel');
      case AppCatalogStatus.installed:
      case AppCatalogStatus.queued:
      case AppCatalogStatus.downloading:
      case AppCatalogStatus.verifying:
      case AppCatalogStatus.installing:
      case AppCatalogStatus.awaitingConfirm:
        return null;
      case AppCatalogStatus.failed:
        if (task?.needsInstallPermission ?? false) {
          return const _Explainer(text: _installPermissionExplainer);
        }
        final message = task?.errorMessage?.trim();
        if (message == null || message.isEmpty) {
          return null;
        }
        return _Explainer(text: message);
      case AppCatalogStatus.otherSource:
        return const _Explainer(text: _otherSourceExplainer);
    }
  }
}

class _Explainer {
  const _Explainer({
    required this.text,
    this.isWarning = false,
  });

  final String text;
  final bool isWarning;
}

class _ExplainerText extends StatelessWidget {
  const _ExplainerText({
    required this.text,
    required this.color,
    required this.textAlign,
  });

  final String text;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Text(
      text,
      textAlign: textAlign,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(color: color, height: 1.3),
    );
  }
}
