import 'package:flutter/material.dart';

const _minVisibleGridPx = 80.0;

const _catalog = [
  'PPSSPP',
  'RetroArch',
  'Dolphin',
  'Flycast',
  'Azahar',
  'MelonDS',
  'DuckStation',
  'ScummVM',
  'Vita3K',
  'Play!',
  'Eden',
  'Redream',
  'M64Plus FZ',
  'NetherSX2',
  'Lemuroid',
  'Pegasus',
  'Daijisho',
  'RetroArch 32',
  'PPSSPP Gold',
  'AetherSX2',
];

class ImePage extends StatefulWidget {
  const ImePage({super.key});

  @override
  State<ImePage> createState() => _ImePageState();
}

class _ImePageState extends State<ImePage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final inset = mq.viewInsets.bottom;
    final remaining = mq.size.height - inset;
    final visible = gridRemainsVisible(
      remainingHeight: remaining,
      minVisible: _minVisibleGridPx,
    );
    final query = _controller.text.toLowerCase();
    final tiles = _catalog
        .where((name) => name.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('#12 IME shape')),
      body: Column(
        children: [
          _ImeBanner(
            size: mq.size,
            insetBottom: inset,
            remaining: remaining,
            gridVisible: visible,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'Type with the d-pad if you can',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: tiles.length,
              itemBuilder: (context, index) {
                return Card(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        tiles[index],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImeBanner extends StatelessWidget {
  const _ImeBanner({
    required this.size,
    required this.insetBottom,
    required this.remaining,
    required this.gridVisible,
  });

  final Size size;
  final double insetBottom;
  final double remaining;
  final bool gridVisible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ratio = size.width / size.height;
    final verdict = insetBottom <= 0
        ? 'NO IME'
        : gridVisible
        ? 'DOCKS — grid visible'
        : 'COVERS — grid hidden';
    return Material(
      color: gridVisible || insetBottom <= 0
          ? colors.surfaceContainerHigh
          : colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(verdict, style: Theme.of(context).textTheme.headlineSmall),
            Text(
              '${size.width.toStringAsFixed(0)}×${size.height.toStringAsFixed(0)}  '
              '${ratio.toStringAsFixed(2)}  '
              'inset ${insetBottom.toStringAsFixed(0)}  '
              'remain ${remaining.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Text(
              'Photograph with the keyboard open. If this grid is gone, IME is fullscreen.',
            ),
          ],
        ),
      ),
    );
  }
}

bool gridRemainsVisible({
  required double remainingHeight,
  required double minVisible,
}) {
  return remainingHeight >= minVisible;
}
