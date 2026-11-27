import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/input/gamepad_action.dart';

/// Manages the active controller button glyph layout preference.
class PadButtonLayoutNotifier extends Notifier<PadButtonLayout> {
  @override
  PadButtonLayout build() => PadButtonLayout.nintendo;

  /// Updates the active button glyph [layout].
  void setLayout(PadButtonLayout layout) {
    if (state == layout) {
      return;
    }
    state = layout;
  }

  /// Toggles between [PadButtonLayout.nintendo] and [PadButtonLayout.xbox].
  void toggle() {
    state = switch (state) {
      PadButtonLayout.nintendo => PadButtonLayout.xbox,
      PadButtonLayout.xbox => PadButtonLayout.nintendo,
    };
  }
}

/// Active controller button glyph layout (defaults to
/// [PadButtonLayout.nintendo]).
final padButtonLayoutProvider =
    NotifierProvider<PadButtonLayoutNotifier, PadButtonLayout>(
      PadButtonLayoutNotifier.new,
    );
