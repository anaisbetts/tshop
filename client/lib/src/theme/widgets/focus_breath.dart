import 'package:flutter/animation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// One full in-and-out breath of the focus ring.
const focusBreathPeriod = Duration(milliseconds: 1600);

/// Overshooting ease used when a tile lifts into focus.
const focusLiftCurve = Cubic(0.3, 0.7, 0.4, 1.4);

/// 0 → 1 → 0 while [focused], idle at 0 otherwise.
Animation<double> useFocusBreath({required bool focused}) {
  final controller = useAnimationController(
    duration: focusBreathPeriod ~/ 2,
  );
  final curved = useMemoized(
    () => CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    [controller],
  );
  useEffect(() => curved.dispose, [curved]);
  useEffect(() {
    if (focused) {
      controller.repeat(reverse: true);
    } else {
      controller.value = 0;
    }
    return null;
  }, [focused]);
  return curved;
}
