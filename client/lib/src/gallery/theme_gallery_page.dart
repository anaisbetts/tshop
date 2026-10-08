import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:tshop/src/gallery/gallery_samples.dart';
import 'package:tshop/src/theme/tshop_theme.dart';
import 'package:tshop/src/theme/tshop_tokens.dart';
import 'package:tshop/src/theme/widgets/pad_glyph.dart';
import 'package:tshop/src/theme/widgets/tshop_button.dart';
import 'package:tshop/src/theme/widgets/tshop_chip.dart';
import 'package:tshop/src/theme/widgets/tshop_chrome.dart';
import 'package:tshop/src/theme/widgets/tshop_settings.dart';
import 'package:tshop/src/theme/widgets/tshop_surfaces.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';
import 'package:tshop/src/theme/widgets/tshop_wallpaper.dart';

const _tileStates = [
  ('Focused', 'pixel-dungeon'),
  ('Available', 'retroarch'),
  ('Installed', 'dolphin'),
  ('Update', 'ppsspp'),
  ('Downloading', 'melonds'),
  ('Confirm', 'unciv'),
  ('Failed', 'amaze'),
  ('Other source', 'moonlight'),
  ('Needs hardware', 'vita3k'),
];

const _browseFrames = [
  (
    'Emulators',
    ['dolphin', 'ppsspp', 'melonds', 'vita3k', 'flycast', 'scummvm'],
  ),
  ('Frontends', ['retroarch', 'lemuroid']),
  ('Games', ['pixel-dungeon', 'mindustry', 'supertuxkart', 'unciv']),
  ('Utilities', ['moonlight', 'syncthing', 'amaze']),
];

/// Every tShop control on one scrolling page, in Day or Night.
///
/// A Flutter mirror of the Storybook "tShop Theme" stories, for checking
/// the theme on a real device or the web demo.
class ThemeGalleryPage extends HookWidget {
  /// Creates the gallery.
  const ThemeGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = useState(Brightness.light);
    final theme = useMemoized(
      () => buildTshopTheme(brightness.value),
      [brightness.value],
    );

    return AnimatedTheme(
      data: theme,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Theme gallery'),
            actions: [
              _ModeToggle(
                value: brightness.value,
                onChanged: (value) => brightness.value = value,
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: TshopWallpaper(
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: const [
                _Section('Palette and type', child: _PaletteSection()),
                _Section('Pad glyphs', child: _PadSection()),
                _Section('Tiles', child: _TileSection()),
                _Section('Primary actions', child: _ActionSection()),
                _Section('Buttons', child: _ButtonSection()),
                _Section('Chips', child: _ChipSection()),
                _Section('Top bar', child: _TopBarSection()),
                _Section('Info strip', child: _InfoSection()),
                _Section('Frames', child: _FrameSection()),
                _Section('Settings', child: _SettingsSection()),
                _Section('Cards', child: _CardSection()),
                _Section('Legend', child: _LegendSection()),
                _Section('Browse on Thor (837 × 471)', child: _BrowseMock()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.value, required this.onChanged});

  final Brightness value;
  final ValueChanged<Brightness> onChanged;

  @override
  Widget build(BuildContext context) {
    TshopButton option(String label, Brightness mode) => TshopButton(
      label: label,
      pad: null,
      small: true,
      tone: value == mode ? TshopButtonTone.primary : TshopButtonTone.ghost,
      onPressed: () => onChanged(mode),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        option('Day', Brightness.light),
        option('Night', Brightness.dark),
      ],
    );
  }
}

class _PaletteSection extends StatelessWidget {
  const _PaletteSection();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    final text = Theme.of(context).textTheme;
    final swatches = <(String, Decoration)>[
      ('Accent', const BoxDecoration(color: TshopBrand.accent)),
      ('Good', const BoxDecoration(color: TshopBrand.good)),
      ('Bad', const BoxDecoration(color: TshopBrand.bad)),
      ('Ink', BoxDecoration(color: tokens.ink)),
      ('Ink 2', BoxDecoration(color: tokens.ink2)),
      ('Ink 3', BoxDecoration(color: tokens.ink3)),
      ('Card', BoxDecoration(color: tokens.card)),
      ('Chip', BoxDecoration(color: tokens.chip)),
      ('Wall', BoxDecoration(gradient: tokens.wallpaper)),
    ];
    return Wrap(
      spacing: 28,
      runSpacing: 20,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (final (name, decoration) in swatches)
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Container(
                  width: double.infinity,
                  height: 52,
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tokens.hairline),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: DecoratedBox(decoration: decoration),
                  ),
                ),
                Text(name, style: text.labelSmall),
              ],
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text('Shattered Pixel Dungeon', style: text.displaySmall),
            Text('Dolphin', style: text.headlineSmall),
            Text('Emulators 6', style: text.titleMedium),
            Text('Privacy Mode', style: text.titleSmall),
            Text(
              'A traditional roguelike: every run a new dungeon.',
              style: text.bodyMedium,
            ),
            Text('Browse · Library · Settings', style: text.labelMedium),
            Text(
              'M PLUS Rounded 1c · 900 / 800 / 700 / 500',
              style: text.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _PadSection extends StatelessWidget {
  const _PadSection();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 16,
      children: [
        for (final button in PadButton.values)
          _Specimen(
            label: button == PadButton.dpad ? 'D-pad' : button.label,
            child: PadGlyph(button, size: 24),
          ),
      ],
    );
  }
}

class _TileSection extends HookWidget {
  const _TileSection();

  @override
  Widget build(BuildContext context) {
    final focus = useState('Focused');
    return Wrap(
      spacing: 28,
      runSpacing: 24,
      children: [
        for (final (label, id) in _tileStates)
          _Specimen(
            label: label,
            child: sampleApps[id]!.tile(
              focused: focus.value == label,
              context: label == 'Other source'
                  ? TileContext.library
                  : TileContext.browse,
              onTap: () => focus.value = label,
            ),
          ),
        _Specimen(
          label: 'Action tile',
          child: TshopActionTile(
            icon: Icons.upgrade_rounded,
            label: 'Update All',
            focused: focus.value == 'Action tile',
            onTap: () => focus.value = 'Action tile',
          ),
        ),
      ],
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection();

  @override
  Widget build(BuildContext context) {
    final ppsspp = sampleApps['ppsspp']!;
    final pixel = sampleApps['pixel-dungeon']!;
    final actions = <(String, Widget, String?)>[
      (
        'Install',
        TshopButton(label: 'Install', sub: pixel.size, onPressed: () {}),
        null,
      ),
      (
        'Update',
        TshopButton(
          label: 'Update',
          sub: 'to ${ppsspp.version}',
          onPressed: () {},
        ),
        'Installed ${ppsspp.installedVersion}',
      ),
      (
        'Open',
        TshopButton(
          label: 'Open',
          tone: TshopButtonTone.open,
          onPressed: () {},
        ),
        null,
      ),
      (
        'Downloading',
        const TshopProgressButton(value: 0.62, label: 'Downloading 62%'),
        null,
      ),
      (
        'Confirm',
        const TshopProgressButton(
          value: 1,
          label: 'Ready · confirm in Library',
        ),
        null,
      ),
      (
        'Retry',
        TshopButton(
          label: 'Retry',
          tone: TshopButtonTone.retry,
          onPressed: () {},
        ),
        sampleApps['amaze']!.failure,
      ),
      (
        'Other source',
        TshopButton(
          label: 'Installed from another source',
          tone: TshopButtonTone.quiet,
          onPressed: () {},
        ),
        'Signed by someone else (likely Play Store). Uninstall it so tShop '
            'can manage updates.',
      ),
      (
        'Landing page',
        TshopButton(label: 'Go to Publisher', onPressed: () {}),
        'ES-DE for Android is a paid app sold directly by its developer.',
      ),
      (
        'Offline',
        const TshopButton(
          label: 'Install when online',
          tone: TshopButtonTone.disabled,
        ),
        'You’re offline. Browsing still works from the saved catalog.',
      ),
    ];
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: 28,
      runSpacing: 24,
      children: [
        for (final (label, button, explainer) in actions)
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(label, style: text.labelMedium),
                button,
                if (explainer != null) Text(explainer, style: text.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}

class _ButtonSection extends HookWidget {
  const _ButtonSection();

  @override
  Widget build(BuildContext context) {
    final taps = useState(0);
    void tap() => taps.value++;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TshopButton(label: 'Focused', focused: true, onPressed: tap),
            TshopButton(label: 'Primary', onPressed: tap),
            TshopButton(
              label: 'Ghost',
              tone: TshopButtonTone.ghost,
              onPressed: tap,
            ),
            TshopButton(label: 'No glyph', pad: null, onPressed: tap),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tone in TshopButtonTone.values)
              TshopButton(
                label: tone.name,
                small: true,
                pad: tone == TshopButtonTone.ghost ? PadButton.b : PadButton.a,
                tone: tone,
                onPressed: tap,
              ),
            const TshopProgressButton(value: 0.35, label: 'Small progress'),
          ],
        ),
        Text(
          'Tapped ${taps.value} times',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const TshopChip('Emulators'),
        const TshopChip('Installed', tone: TshopChipTone.good),
        const TshopChip('Update 1.17.1 → 1.18.1', tone: TshopChipTone.accent),
        const TshopChip('Download failed', tone: TshopChipTone.bad),
        for (final count in [1, 3, 12]) TshopCountBadge(count),
      ],
    );
  }
}

class _TopBarSection extends HookWidget {
  const _TopBarSection();

  @override
  Widget build(BuildContext context) {
    final destination = useState(TshopDestination.browse);
    return Column(
      spacing: 14,
      children: [
        TshopTopBar(
          destination: destination.value,
          libraryCount: 3,
          showSearch: destination.value == TshopDestination.browse,
          onDestination: (value) => destination.value = value,
        ),
        const TshopTopBar(
          destination: TshopDestination.browse,
          libraryCount: 3,
          showSearch: true,
          query: 'emulator',
        ),
        const TshopTopBar(
          destination: TshopDestination.library,
          online: false,
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 14,
      children: [
        for (final id in ['ppsspp', 'vita3k', 'amaze']) _info(sampleApps[id]!),
        const TshopInfoStrip(
          title: 'Library',
          summary: 'Everything tShop installed, updating, or waiting on you.',
        ),
      ],
    );
  }

  Widget _info(SampleApp app) => TshopInfoStrip(
    title: app.name,
    summary: app.failure ?? app.summary,
    chips: [TshopChip(app.category), app.statusChip],
  );
}

class _FrameSection extends HookWidget {
  const _FrameSection();

  @override
  Widget build(BuildContext context) {
    final focus = useState('update-all');
    TshopTile tile(String id) => sampleApps[id]!.tile(
      context: TileContext.library,
      focused: focus.value == id,
      onTap: () => focus.value = id,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          TshopFrame(
            label: 'Updates',
            count: 3,
            tiles: [
              TshopActionTile(
                icon: Icons.upgrade_rounded,
                label: 'Update All',
                focused: focus.value == 'update-all',
                onTap: () => focus.value = 'update-all',
              ),
              tile('ppsspp'),
              tile('lemuroid'),
              tile('mindustry'),
            ],
          ),
          TshopFrame(
            label: 'In progress',
            tiles: [tile('melonds'), tile('unciv'), tile('amaze')],
          ),
          TshopFrame(
            label: 'Installed',
            rows: 4,
            tileSize: 70,
            gap: 7,
            tiles: [
              for (final id in [
                'dolphin',
                'scummvm',
                'supertuxkart',
                'syncthing',
                'moonlight',
              ])
                tile(id),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends HookWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    final focus = useState(1);
    final notifications = useState(true);
    final privacy = useState(false);
    TshopSettingsRow row(
      int index,
      String title, {
      String? description,
      Widget? trailing,
      VoidCallback? onActivate,
    }) => TshopSettingsRow(
      title: title,
      description: description,
      trailing: trailing,
      focused: focus.value == index,
      onTap: () {
        focus.value = index;
        onActivate?.call();
      },
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: TshopSettingsPanel(
          rows: [
            row(
              0,
              'Update notifications',
              description: 'One summary when catalog updates are ready.',
              trailing: TshopSwitch(
                value: notifications.value,
                onChanged: (value) => notifications.value = value,
              ),
              onActivate: () => notifications.value = !notifications.value,
            ),
            row(
              1,
              'Privacy Mode',
              description:
                  'Do not send any anonymized information to the '
                  'shop.',
              trailing: TshopSwitch(
                value: privacy.value,
                onChanged: (value) => privacy.value = value,
              ),
              onActivate: () => privacy.value = !privacy.value,
            ),
            row(
              2,
              'Check for updates now',
              trailing: const TshopRowValue('Last checked 9:12'),
            ),
            row(
              3,
              'Catalog',
              trailing: const TshopRowValue('Published 6 Oct 2026, 08:00'),
            ),
            row(
              4,
              'About tShop',
              description:
                  'What tShop knows about you, licenses, source, '
                  'public stats',
              trailing: const TshopRowValue('›'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection();

  @override
  Widget build(BuildContext context) {
    final app = sampleApps['pixel-dungeon']!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Expanded(
          flex: 14,
          child: TshopCard(
            heading: 'About',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(
                  app.summary,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Explore the dungeon, fight monsters, find loot and '
                  'upgrade your hero. Every run is different.',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 10,
          child: TshopCard(
            heading: 'New in ${app.version}',
            child: const Text(
              '• New boss and quest rework\n'
              '• Controller remapping\n'
              '• Bug fixes',
            ),
          ),
        ),
        Expanded(
          flex: 10,
          child: TshopCard(
            heading: 'Details',
            child: TshopFacts([
              ('Released', '28 Sep 2026'),
              ('Size', app.size),
              ('Version', app.version),
              ('Category', app.category),
            ]),
          ),
        ),
      ],
    );
  }
}

class _LegendSection extends StatelessWidget {
  const _LegendSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      spacing: 14,
      children: [
        TshopLegend(
          left: [
            (button: PadButton.dpad, label: 'Move'),
            (button: PadButton.a, label: 'Open'),
          ],
          right: [
            (button: PadButton.y, label: 'Search'),
            (button: PadButton.b, label: 'Back'),
          ],
          middle: TshopDownloadsPill(
            label: 'melonDS 62%',
            progress: 0.62,
            go: '+1 · Library',
          ),
        ),
        TshopLegend(
          left: [
            (button: PadButton.dpad, label: 'Move'),
            (button: PadButton.a, label: 'Change'),
          ],
          right: [(button: PadButton.b, label: 'Back')],
        ),
      ],
    );
  }
}

class _BrowseMock extends HookWidget {
  const _BrowseMock();

  @override
  Widget build(BuildContext context) {
    final focus = useState('pixel-dungeon');
    final app = sampleApps[focus.value]!;
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: TshopMetrics.thorCanvas.width,
          height: TshopMetrics.thorCanvas.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: context.tshop.cardShadow,
          ),
          child: TshopWallpaper(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  const TshopTopBar(
                    destination: TshopDestination.browse,
                    libraryCount: 3,
                    showSearch: true,
                  ),
                  TshopInfoStrip(
                    title: app.name,
                    summary: app.failure ?? app.summary,
                    chips: [TshopChip(app.category), app.statusChip],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 10,
                        children: [
                          for (final (label, ids) in _browseFrames)
                            TshopFrame(
                              label: label,
                              tiles: [
                                for (final id in ids)
                                  sampleApps[id]!.tile(
                                    focused: focus.value == id,
                                    onTap: () => focus.value = id,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const TshopLegend(
                    left: [
                      (button: PadButton.dpad, label: 'Move'),
                      (button: PadButton.a, label: 'Details'),
                    ],
                    right: [(button: PadButton.y, label: 'Search')],
                    middle: TshopDownloadsPill(
                      label: 'melonDS 62%',
                      progress: 0.62,
                      go: 'Library',
                    ),
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

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tshop;
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tokens.ink3,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Specimen extends StatelessWidget {
  const _Specimen({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        child,
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
