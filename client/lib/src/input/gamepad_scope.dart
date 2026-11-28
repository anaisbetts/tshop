import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/platform/app_services.dart';

/// Wraps a screen to receive normalized [GamepadAction]s from both
/// [HardwareKeyboard] and Android [AppServices.gamepadHatEvents].
///
/// Keyboard interception and hat dispatch pause automatically when [enabled]
/// is `false`, when the enclosing [ModalRoute] is covered by another route or
/// modal, or (when [ignoreWhenTextInputFocused] is `true`) while an
/// [EditableText] holds primary focus so Android IME typing works cleanly.
class TshopGamepadScope extends HookConsumerWidget {
  /// Creates a gamepad scope around [child].
  const TshopGamepadScope({
    required this.onAction,
    required this.child,
    super.key,
    this.enabled = true,
    this.ignoreWhenTextInputFocused = true,
    this.mapper,
  });

  /// Called whenever a normalized [GamepadAction] fires.
  final ValueChanged<GamepadAction> onAction;

  /// Subtree wrapped by this input scope.
  final Widget child;

  /// Whether this scope actively intercepts keyboard and hat events.
  ///
  /// Set to `false` while a search field or blocking overlay is open.
  final bool enabled;

  /// Whether keyboard events should pass through when an [EditableText] has
  /// primary focus.
  final bool ignoreWhenTextInputFocused;

  /// Optional custom [GamepadActionMapper] for testing or specialized timing.
  ///
  /// When omitted, this scope creates and disposes its own mapper.
  final GamepadActionMapper? mapper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appServices = ref.watch(appServicesProvider);
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final isActive = enabled && routeIsCurrent;

    final ownedMapper = useMemoized(GamepadActionMapper.new);
    useEffect(() => ownedMapper.dispose, [ownedMapper]);

    final activeMapper = mapper ?? ownedMapper;
    final onActionRef = useRef(onAction)..value = onAction;
    final ignoreImeRef = useRef(ignoreWhenTextInputFocused)
      ..value = ignoreWhenTextInputFocused;

    useEffect(() {
      if (!isActive) {
        activeMapper.reset();
        return null;
      }

      bool handleKey(KeyEvent event) {
        if (ignoreImeRef.value && _hasTextInputFocus()) {
          return false;
        }
        final result = activeMapper.processKeyEvent(event);
        final action = result.action;
        if (action != null) {
          onActionRef.value(action);
        }
        return result.handled;
      }

      HardwareKeyboard.instance.addHandler(handleKey);
      return () {
        HardwareKeyboard.instance.removeHandler(handleKey);
        activeMapper.reset();
      };
    }, [isActive, activeMapper]);

    useEffect(() {
      if (!isActive) {
        activeMapper.cancelHatRepeat();
        return null;
      }

      final subscription = appServices.gamepadHatEvents.listen((hatEvent) {
        if (ignoreImeRef.value && _hasTextInputFocus()) {
          activeMapper.cancelHatRepeat();
          return;
        }
        activeMapper.handleHatEvent(
          hatEvent,
          (action) => onActionRef.value(action),
        );
      });

      return () {
        unawaited(subscription.cancel());
        activeMapper.cancelHatRepeat();
      };
    }, [isActive, appServices, activeMapper]);

    return child;
  }
}

bool _hasTextInputFocus() {
  final primaryContext = FocusManager.instance.primaryFocus?.context;
  if (primaryContext == null) {
    return false;
  }
  if (primaryContext.widget is EditableText) {
    return true;
  }
  return primaryContext.findAncestorWidgetOfExactType<EditableText>() != null;
}
