import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tshop/src/platform/app_services.dart';

/// Default repeat cooldown for held D-pad directions (100 ms).
const Duration defaultDpadRepeatCooldown = Duration(milliseconds: 100);

/// High-level controller and keyboard actions normalized for tShop screens.
enum GamepadAction {
  /// Move focus upward (D-pad up / ArrowUp).
  up,

  /// Move focus downward (D-pad down / ArrowDown).
  down,

  /// Move focus left (D-pad left / ArrowLeft).
  left,

  /// Move focus right (D-pad right / ArrowRight).
  right,

  /// Primary confirm action (A / Enter / Space).
  confirm,

  /// Back / dismiss action (B / Escape / Backspace).
  back,

  /// Secondary contextual action (X).
  secondary,

  /// Open search or retry action (Y / `/`).
  searchOrRetry,

  /// Switch to the previous top-level tab (L1 / LB / `[` / `Q`).
  tabPrev,

  /// Switch to the next top-level tab (R1 / RB / `]` / `E`).
  tabNext,

  /// Open menu / quick actions (Start / `+`).
  menu;

  /// Whether this action represents a repeatable directional input.
  bool get isDirectional => switch (this) {
    GamepadAction.up ||
    GamepadAction.down ||
    GamepadAction.left ||
    GamepadAction.right => true,
    GamepadAction.confirm ||
    GamepadAction.back ||
    GamepadAction.secondary ||
    GamepadAction.searchOrRetry ||
    GamepadAction.tabPrev ||
    GamepadAction.tabNext ||
    GamepadAction.menu => false,
  };
}

/// Controller face-button glyph set shown in on-screen legends.
///
/// Confirm is always `A` and back is always `B` in both layouts; this setting
/// selects which physical glyph convention the HUD labels follow.
enum PadButtonLayout {
  /// Nintendo layout (default, matching the design system).
  nintendo,

  /// Xbox layout.
  xbox,
}

/// Result of processing a [KeyEvent] through [GamepadActionMapper].
@immutable
final class GamepadKeyResult {
  /// Creates a key processing result.
  const GamepadKeyResult({
    required this.handled,
    this.action,
  });

  /// Unhandled key event that should pass through to other handlers.
  static const unhandled = GamepadKeyResult(handled: false);

  /// Key event consumed without emitting an action (for example a key-up or
  /// a suppressed repeat).
  static const consumed = GamepadKeyResult(handled: true);

  /// Emitted action, or `null` when suppressed or released.
  final GamepadAction? action;

  /// Whether the event belongs to a mapped gamepad/navigation key and should
  /// not fall through to Flutter's default focus traversal.
  final bool handled;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is GamepadKeyResult &&
            other.action == action &&
            other.handled == handled);
  }

  @override
  int get hashCode => Object.hash(action, handled);

  @override
  String toString() => 'GamepadKeyResult(handled: $handled, action: $action)';
}

/// Normalizes Flutter [KeyEvent]s and Android [GamepadHatEvent]s into
/// [GamepadAction]s with handheld-safe repeat and key-up tracking.
///
/// Implements the AYN Thor key-up mismatch shim:
/// - Tracks pressed buttons by [PhysicalKeyboardKey] on [KeyDownEvent].
/// - Ignores stray [KeyUpEvent]s and mismatched logical keys on key-up/repeat.
/// - Enforces [repeatCooldown] (~100 ms) for held directional inputs.
/// - Never repeats face or shoulder buttons while held.
final class GamepadActionMapper {
  /// Creates a mapper with optional [repeatCooldown] and [clock] overrides.
  GamepadActionMapper({
    this.repeatCooldown = defaultDpadRepeatCooldown,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Minimum interval between repeated directional actions while held.
  final Duration repeatCooldown;

  final DateTime Function() _clock;
  final Set<PhysicalKeyboardKey> _pressedPhysicalKeys = <PhysicalKeyboardKey>{};
  final Map<PhysicalKeyboardKey, GamepadAction> _pressedActions =
      <PhysicalKeyboardKey, GamepadAction>{};
  final Map<GamepadAction, DateTime> _lastDirectionalFire =
      <GamepadAction, DateTime>{};

  GamepadAction? _activeHatAction;
  Timer? _hatRepeatTimer;

  /// Physical keys currently tracked as held down.
  Set<PhysicalKeyboardKey> get pressedPhysicalKeys =>
      Set<PhysicalKeyboardKey>.unmodifiable(_pressedPhysicalKeys);

  /// Currently held directional hat action, if any.
  GamepadAction? get activeHatAction => _activeHatAction;

  /// Maps a single [KeyEvent] to a [GamepadAction], or `null` when ignored,
  /// released, or suppressed by cooldown / non-repeat rules.
  GamepadAction? handleKeyEvent(KeyEvent event) =>
      processKeyEvent(event).action;

  /// Processes a [KeyEvent], returning both the emitted action (if any) and
  /// whether the key belongs to this mapper and should be consumed.
  GamepadKeyResult processKeyEvent(KeyEvent event) {
    final physicalKey = event.physicalKey;

    if (event is KeyUpEvent) {
      final wasPressed = _pressedPhysicalKeys.remove(physicalKey);
      _pressedActions.remove(physicalKey);
      if (wasPressed || mapKey(event.logicalKey, physicalKey) != null) {
        return GamepadKeyResult.consumed;
      }
      return GamepadKeyResult.unhandled;
    }

    if (event is KeyDownEvent) {
      final trackedAction = _pressedActions[physicalKey];
      final action = trackedAction ?? mapKey(event.logicalKey, physicalKey);
      if (action == null) {
        return GamepadKeyResult.unhandled;
      }

      if (_pressedPhysicalKeys.contains(physicalKey)) {
        return _handleHeldAction(action);
      }

      _pressedPhysicalKeys.add(physicalKey);
      _pressedActions[physicalKey] = action;
      if (action.isDirectional) {
        _lastDirectionalFire[action] = _clock();
      }
      return GamepadKeyResult(handled: true, action: action);
    }

    if (event is KeyRepeatEvent) {
      final trackedAction = _pressedActions[physicalKey];
      final action = trackedAction ?? mapKey(event.logicalKey, physicalKey);
      if (action == null) {
        return GamepadKeyResult.unhandled;
      }
      if (!_pressedPhysicalKeys.contains(physicalKey)) {
        _pressedPhysicalKeys.add(physicalKey);
        _pressedActions[physicalKey] = action;
      }
      return _handleHeldAction(action);
    }

    return GamepadKeyResult.unhandled;
  }

  /// Processes a quantized Android `AXIS_HAT_X/Y` [event], immediately
  /// invoking [onAction] on direction changes and repeating every
  /// [repeatCooldown] while held non-zero.
  ///
  /// Returning to `(0, 0)` cancels any active repeat timer.
  void handleHatEvent(
    GamepadHatEvent event,
    ValueChanged<GamepadAction> onAction,
  ) {
    final nextAction = _resolveHatAction(event, current: _activeHatAction);
    if (nextAction == null) {
      cancelHatRepeat();
      return;
    }

    if (nextAction == _activeHatAction && _hatRepeatTimer != null) {
      return;
    }

    cancelHatRepeat();
    _activeHatAction = nextAction;
    _lastDirectionalFire[nextAction] = _clock();
    onAction(nextAction);

    _hatRepeatTimer = Timer.periodic(repeatCooldown, (_) {
      final held = _activeHatAction;
      if (held == null) {
        cancelHatRepeat();
        return;
      }
      _lastDirectionalFire[held] = _clock();
      onAction(held);
    });
  }

  /// Maps a [logicalKey] (with optional [physicalKey] fallback) to a
  /// [GamepadAction] without mutating held-key state.
  GamepadAction? mapKey(
    LogicalKeyboardKey logicalKey, [
    PhysicalKeyboardKey? physicalKey,
  ]) {
    final mapped = _mapLogicalKey(logicalKey);
    if (mapped != null) {
      return mapped;
    }
    return physicalKey == null ? null : _mapPhysicalKey(physicalKey);
  }

  /// Maps a quantized [GamepadHatEvent] to a directional [GamepadAction], or
  /// `null` for `(0, 0)`.
  GamepadAction? mapHat(GamepadHatEvent event) => _resolveHatAction(event);

  /// Cancels any active hat repeat timer and clears the active hat direction.
  void cancelHatRepeat() {
    _hatRepeatTimer?.cancel();
    _hatRepeatTimer = null;
    _activeHatAction = null;
  }

  /// Clears all tracked pressed keys, cooldown timestamps, and active hat
  /// repeat timers.
  void reset() {
    cancelHatRepeat();
    _pressedPhysicalKeys.clear();
    _pressedActions.clear();
    _lastDirectionalFire.clear();
  }

  /// Releases any active timers held by this mapper.
  void dispose() {
    reset();
  }

  GamepadKeyResult _handleHeldAction(GamepadAction action) {
    if (!action.isDirectional) {
      return GamepadKeyResult.consumed;
    }

    final now = _clock();
    final lastFire = _lastDirectionalFire[action];
    if (lastFire != null && now.difference(lastFire) < repeatCooldown) {
      return GamepadKeyResult.consumed;
    }

    _lastDirectionalFire[action] = now;
    return GamepadKeyResult(handled: true, action: action);
  }
}

GamepadAction? _mapLogicalKey(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowUp) {
    return GamepadAction.up;
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    return GamepadAction.down;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return GamepadAction.left;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    return GamepadAction.right;
  }
  if (key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space) {
    return GamepadAction.confirm;
  }
  if (key == LogicalKeyboardKey.gameButtonB ||
      key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.backspace) {
    return GamepadAction.back;
  }
  if (key == LogicalKeyboardKey.gameButtonX || key == LogicalKeyboardKey.keyX) {
    return GamepadAction.secondary;
  }
  if (key == LogicalKeyboardKey.gameButtonY ||
      key == LogicalKeyboardKey.keyY ||
      key == LogicalKeyboardKey.slash) {
    return GamepadAction.searchOrRetry;
  }
  if (key == LogicalKeyboardKey.gameButtonLeft1 ||
      key == LogicalKeyboardKey.bracketLeft ||
      key == LogicalKeyboardKey.keyQ) {
    return GamepadAction.tabPrev;
  }
  if (key == LogicalKeyboardKey.gameButtonRight1 ||
      key == LogicalKeyboardKey.bracketRight ||
      key == LogicalKeyboardKey.keyE) {
    return GamepadAction.tabNext;
  }
  if (key == LogicalKeyboardKey.gameButtonStart) {
    return GamepadAction.menu;
  }
  return null;
}

GamepadAction? _mapPhysicalKey(PhysicalKeyboardKey key) {
  if (key == PhysicalKeyboardKey.arrowUp) {
    return GamepadAction.up;
  }
  if (key == PhysicalKeyboardKey.arrowDown) {
    return GamepadAction.down;
  }
  if (key == PhysicalKeyboardKey.arrowLeft) {
    return GamepadAction.left;
  }
  if (key == PhysicalKeyboardKey.arrowRight) {
    return GamepadAction.right;
  }
  if (key == PhysicalKeyboardKey.enter ||
      key == PhysicalKeyboardKey.numpadEnter ||
      key == PhysicalKeyboardKey.space ||
      key == PhysicalKeyboardKey.select) {
    return GamepadAction.confirm;
  }
  if (key == PhysicalKeyboardKey.escape ||
      key == PhysicalKeyboardKey.backspace ||
      key == PhysicalKeyboardKey.browserBack) {
    return GamepadAction.back;
  }
  if (key == PhysicalKeyboardKey.keyX) {
    return GamepadAction.secondary;
  }
  if (key == PhysicalKeyboardKey.keyY || key == PhysicalKeyboardKey.slash) {
    return GamepadAction.searchOrRetry;
  }
  if (key == PhysicalKeyboardKey.bracketLeft ||
      key == PhysicalKeyboardKey.keyQ) {
    return GamepadAction.tabPrev;
  }
  if (key == PhysicalKeyboardKey.bracketRight ||
      key == PhysicalKeyboardKey.keyE) {
    return GamepadAction.tabNext;
  }
  return null;
}

GamepadAction? _resolveHatAction(
  GamepadHatEvent event, {
  GamepadAction? current,
}) {
  final horizontal = event.x < 0
      ? GamepadAction.left
      : event.x > 0
      ? GamepadAction.right
      : null;
  final vertical = event.y < 0
      ? GamepadAction.up
      : event.y > 0
      ? GamepadAction.down
      : null;

  if (horizontal == null && vertical == null) {
    return null;
  }
  if (horizontal != null && vertical == null) {
    return horizontal;
  }
  if (vertical != null && horizontal == null) {
    return vertical;
  }
  if (current == horizontal || current == vertical) {
    return current;
  }
  return horizontal;
}
