import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  final _search = TextEditingController();
  TraversalMode _mode = TraversalMode.stock;
  bool _wifi = true;
  bool _agree = false;
  String _radio = 'a';
  double _volume = 0.4;
  String _core = 'PPSSPP';
  final _chips = {'ARM', 'x64'};
  String _focus = 'none';

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Focus kitchen')),
      body: Column(
        children: [
          _FocusBanner(label: _focus, mode: _mode, onMode: _setMode),
          Expanded(
            child: Shortcuts(
              shortcuts: _mode.shortcuts(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _section('Row of buttons — does Left/Right follow geometry?'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        autofocus: true,
                        onPressed: () {},
                        child: const Text('Install'),
                      ),
                      FilledButton.tonal(
                        onPressed: () {},
                        child: const Text('Update'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Open'),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {},
                        tooltip: 'More',
                        icon: const Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                  _section('Text field — arrows move the caret, not focus'),
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  _section('Toggles'),
                  SwitchListTile(
                    title: const Text('Wi-Fi'),
                    value: _wifi,
                    onChanged: (v) => setState(() => _wifi = v),
                  ),
                  CheckboxListTile(
                    title: const Text('I agree'),
                    value: _agree,
                    onChanged: (v) => setState(() => _agree = v ?? false),
                  ),
                  RadioGroup<String>(
                    groupValue: _radio,
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _radio = v);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(value: 'a', title: Text('ARM64')),
                        RadioListTile<String>(value: 'b', title: Text('ARM32')),
                      ],
                    ),
                  ),
                  _section('Slider — Left/Right usually change the value'),
                  Slider(
                    value: _volume,
                    label: '${(_volume * 100).round()}%',
                    onChanged: (v) => setState(() => _volume = v),
                  ),
                  _section('Menus'),
                  DropdownButton<String>(
                    value: _core,
                    items: const [
                      DropdownMenuItem(value: 'PPSSPP', child: Text('PPSSPP')),
                      DropdownMenuItem(
                        value: 'RetroArch',
                        child: Text('RetroArch'),
                      ),
                      DropdownMenuItem(
                        value: 'Dolphin',
                        child: Text('Dolphin'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _core = v);
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'a', child: Text('Details')),
                      PopupMenuItem(value: 'b', child: Text('Uninstall')),
                    ],
                    child: const ListTile(
                      title: Text('Overflow menu'),
                      trailing: Icon(Icons.arrow_drop_down),
                    ),
                  ),
                  _section('Chips'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final chip in ['ARM', 'x64', 'Vulkan'])
                        FilterChip(
                          label: Text(chip),
                          selected: _chips.contains(chip),
                          onSelected: (on) => setState(() {
                            if (on) {
                              _chips.add(chip);
                            } else {
                              _chips.remove(chip);
                            }
                          }),
                        ),
                    ],
                  ),
                  _section('List tiles'),
                  const ListTile(
                    leading: Icon(Icons.sports_esports),
                    title: Text('PPSSPP'),
                    subtitle: Text('PlayStation Portable'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings row'),
                    onTap: () {},
                  ),
                  _section(
                    '2×3 grid — Down should not become Next-in-document',
                  ),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.4,
                    children: [
                      for (final name in [
                        'PPSSPP',
                        'RetroArch',
                        'Dolphin',
                        'Flycast',
                        'Azahar',
                        'ScummVM',
                      ])
                        Card(
                          child: InkWell(
                            onTap: () {},
                            child: Center(child: Text(name)),
                          ),
                        ),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text('Expansion — can you enter and leave?'),
                    children: [
                      ListTile(title: const Text('Inside A'), onTap: () {}),
                      ListTile(title: const Text('Inside B'), onTap: () {}),
                    ],
                  ),
                  _section('Overlay — focus must not leak to the list behind'),
                  FilledButton.tonal(
                    onPressed: _openDialog,
                    child: const Text('Open dialog'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onFocus() {
    final node = FocusManager.instance.primaryFocus;
    final next = describeFocus(node);
    if (next == _focus) {
      return;
    }
    setState(() => _focus = next);
  }

  void _setMode(TraversalMode mode) {
    setState(() => _mode = mode);
  }

  Future<void> _openDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Modal'),
          content: const Text(
            'Can the d-pad reach Cancel and OK? Does Back dismiss? '
            'When this closes, focus should return to Open dialog.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class _FocusBanner extends StatelessWidget {
  const _FocusBanner({
    required this.label,
    required this.mode,
    required this.onMode,
  });

  final String label;
  final TraversalMode mode;
  final ValueChanged<TraversalMode> onMode;

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
              'Focus: $label',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Stock maps d-pad to DirectionalFocusIntent. Linear remaps '
              'arrows to Next/Previous — the flutter_gamepads default.',
            ),
            const SizedBox(height: 8),
            SegmentedButton<TraversalMode>(
              segments: const [
                ButtonSegment(value: TraversalMode.stock, label: Text('Stock')),
                ButtonSegment(
                  value: TraversalMode.linear,
                  label: Text('Linear'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (next) => onMode(next.first),
            ),
          ],
        ),
      ),
    );
  }
}

enum TraversalMode { stock, linear }

extension on TraversalMode {
  Map<ShortcutActivator, Intent> shortcuts() {
    switch (this) {
      case TraversalMode.stock:
        return const {};
      case TraversalMode.linear:
        return const {
          SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft): PreviousFocusIntent(),
        };
    }
  }
}

String describeFocus(FocusNode? node) {
  if (node == null) {
    return 'none';
  }
  final label = node.debugLabel;
  if (label != null && label.isNotEmpty) {
    return label;
  }
  final widget = node.context?.widget;
  if (widget == null) {
    return node.toStringShort();
  }
  return widget.runtimeType.toString();
}

Widget _section(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}
