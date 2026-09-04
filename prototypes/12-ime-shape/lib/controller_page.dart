import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const motionChannelName = 'dev.anais.tshop.ime_shape/motion';
const settingsChannelName = 'dev.anais.tshop.ime_shape/settings';

const _maxLog = 80;

class InputLine {
  const InputLine({required this.kind, required this.label});

  factory InputLine.fromKey(KeyEvent event) {
    return InputLine(
      kind: keyKind(event),
      label:
          'phys=${event.physicalKey.debugName}  '
          'log=${event.logicalKey.debugName}',
    );
  }

  final String kind;
  final String label;

  String format() => '$kind  $label';
}

class RepeatWatch {
  const RepeatWatch({
    required this.repeats,
    required this.intervalsMs,
    this.lastAtMs,
  });

  static const empty = RepeatWatch(repeats: 0, intervalsMs: []);

  final int repeats;
  final List<int> intervalsMs;
  final int? lastAtMs;

  RepeatWatch observe(KeyEvent event) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (event is KeyUpEvent) {
      return RepeatWatch(repeats: repeats, intervalsMs: intervalsMs);
    }
    final isRepeat = event is KeyRepeatEvent;
    if (!isRepeat) {
      return RepeatWatch(repeats: 0, intervalsMs: [], lastAtMs: now);
    }
    final interval = lastAtMs == null ? 0 : now - lastAtMs!;
    return RepeatWatch(
      repeats: repeats + 1,
      intervalsMs: [...intervalsMs, if (interval > 0) interval],
      lastAtMs: now,
    );
  }

  String summary() {
    if (repeats == 0) {
      return 'none';
    }
    if (intervalsMs.isEmpty) {
      return '$repeats (cadence unknown)';
    }
    return '$repeats, last ${intervalsMs.last}ms';
  }
}

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key, this.motionEvents, this.settings});

  final Stream<dynamic>? motionEvents;
  final Future<void> Function()? settings;

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  final _focus = FocusNode();
  final _log = <InputLine>[];
  StreamSubscription<dynamic>? _motion;
  RepeatWatch _dpad = RepeatWatch.empty;
  RepeatWatch _faceA = RepeatWatch.empty;
  String _hat = 'none';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    final motion =
        widget.motionEvents ??
        const EventChannel(motionChannelName).receiveBroadcastStream();
    _motion = motion.listen(_onMotion, onError: (_) {});
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    unawaited(_motion?.cancel());
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('#2 Controller input')),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatsBanner(dpad: _dpad, faceA: _faceA, hat: _hat),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.tonal(
                onPressed: _openUnknownApps,
                child: const Text('Open unknown-apps Settings'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _log.length,
                itemBuilder: (context, index) {
                  final line = _log[index];
                  return Text(
                    line.format(),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontFamily: 'monospace'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _onKey(KeyEvent event) {
    final line = InputLine.fromKey(event);
    final dpad = _isDpad(event.logicalKey);
    final faceA = event.logicalKey == LogicalKeyboardKey.gameButtonA;
    setState(() {
      _push(line);
      if (dpad) {
        _dpad = _dpad.observe(event);
      }
      if (faceA) {
        _faceA = _faceA.observe(event);
      }
    });
    return false;
  }

  void _onMotion(dynamic raw) {
    if (raw is! Map) {
      return;
    }
    final hatX = (raw['hatX'] as num?)?.toDouble() ?? 0;
    final hatY = (raw['hatY'] as num?)?.toDouble() ?? 0;
    final device = raw['device']?.toString() ?? '';
    final source = raw['source']?.toString() ?? '';
    setState(() {
      _hat = 'hatX ${hatX.toStringAsFixed(2)}  hatY ${hatY.toStringAsFixed(2)}';
      _push(InputLine(kind: 'motion', label: '$device src=$source $_hat'));
    });
  }

  void _push(InputLine line) {
    _log.insert(0, line);
    if (_log.length > _maxLog) {
      _log.removeLast();
    }
  }

  Future<void> _openUnknownApps() async {
    final open =
        widget.settings ??
        () =>
            const MethodChannel(settingsChannelName)
                .invokeMethod<void>('openUnknownSources');
    try {
      await open();
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unknown-apps Settings is Android only.')),
      );
    }
  }
}

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({
    required this.dpad,
    required this.faceA,
    required this.hat,
  });

  final RepeatWatch dpad;
  final RepeatWatch faceA;
  final String hat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Press every control. Hold d-pad, then hold A.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('D-pad repeats: ${dpad.summary()}'),
            Text('A repeats: ${faceA.summary()}'),
            Text('Last hat: $hat'),
            const Text(
              'If motion stays "none" and no DPAD keys appear, Dart never saw the pad.',
            ),
          ],
        ),
      ),
    );
  }
}

String keyKind(KeyEvent event) {
  switch (event) {
    case KeyDownEvent():
      return 'down';
    case KeyRepeatEvent():
      return 'repeat';
    case KeyUpEvent():
      return 'up';
    default:
      return event.runtimeType.toString();
  }
}

bool _isDpad(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight;
}
