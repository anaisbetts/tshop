import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:tshop/src/theme/widgets/tshop_chip.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';

/// Fake apps from `design/src/tshop/catalog.ts`, for the theme gallery only.
const sampleApps = <String, SampleApp>{
  'dolphin': SampleApp(
    name: 'Dolphin',
    category: 'Emulators',
    summary: 'GameCube and Wii games in HD, with netplay and save states.',
    size: '19 MB',
    version: '2509',
    icon: 'dolphin',
    backdrop: [Color(0xFF0F3B6E), Color(0xFF082447)],
    scale: 0.82,
    status: TileStatus.installed,
  ),
  'ppsspp': SampleApp(
    name: 'PPSSPP',
    category: 'Emulators',
    summary: 'PSP games at up to 4× resolution, with controller remapping.',
    size: '41 MB',
    version: '1.18.1',
    installedVersion: '1.17.1',
    icon: 'ppsspp',
    backdrop: [Color(0xFF35505F), Color(0xFF24363F)],
    scale: 1.14,
    status: TileStatus.update,
  ),
  'melonds': SampleApp(
    name: 'melonDS',
    category: 'Emulators',
    summary: 'Nintendo DS with dual-screen layouts built for handhelds.',
    size: '12 MB',
    version: '1.0',
    icon: 'melonds',
    backdrop: [Color(0xFFF7F3EA), Color(0xFFE6DFCF)],
    scale: 0.86,
    status: TileStatus.downloading,
    progress: 0.62,
  ),
  'vita3k': SampleApp(
    name: 'Vita3K',
    category: 'Emulators',
    summary: 'Experimental PlayStation Vita emulator.',
    size: '33 MB',
    version: '0.2.0',
    icon: 'vita3k',
    backdrop: [Color(0xFF4A2378), Color(0xFF2A1147)],
    scale: 0.84,
    unmet: 'Vulkan 1.1 GPU driver',
  ),
  'flycast': SampleApp(
    name: 'Flycast',
    category: 'Emulators',
    summary: 'Dreamcast, Naomi and Atomiswave at full speed.',
    size: '16 MB',
    version: '2.5',
    icon: 'flycast',
    backdrop: [Color(0xFFA77CF6), Color(0xFF7445D9)],
    scale: 1.1,
  ),
  'scummvm': SampleApp(
    name: 'ScummVM',
    category: 'Emulators',
    summary: 'Classic point-and-click adventures on modern hardware.',
    size: '96 MB',
    version: '2.9.1',
    icon: 'scummvm',
    backdrop: [Color(0xFFFFF8DC), Color(0xFFF1E3A6)],
    scale: 0.8,
    status: TileStatus.installed,
  ),
  'retroarch': SampleApp(
    name: 'RetroArch',
    category: 'Frontends',
    summary: 'One frontend for hundreds of cores, shaders and netplay.',
    size: '118 MB',
    version: '1.21.0',
    icon: 'retroarch',
    backdrop: [Color(0xFF333333), Color(0xFF333333)],
  ),
  'lemuroid': SampleApp(
    name: 'Lemuroid',
    category: 'Frontends',
    summary: 'Point it at a folder of games and play. No setup.',
    size: '64 MB',
    version: '1.16.0',
    installedVersion: '1.15.2',
    icon: 'lemuroid',
    backdrop: [Color(0xFF2CCB63), Color(0xFF18A64C)],
    scale: 1.14,
    status: TileStatus.update,
  ),
  'pixel-dungeon': SampleApp(
    name: 'Shattered Pixel Dungeon',
    category: 'Games',
    summary: 'A traditional roguelike: every run a new dungeon.',
    size: '24 MB',
    version: '3.2.0',
    icon: 'pixel-dungeon',
    backdrop: [Color(0xFF2B2B28), Color(0xFF2B2B28)],
    scale: 1.08,
  ),
  'mindustry': SampleApp(
    name: 'Mindustry',
    category: 'Games',
    summary: 'Build supply chains and defend them in a factory-tower hybrid.',
    size: '78 MB',
    version: '146',
    installedVersion: '145.1',
    icon: 'mindustry',
    backdrop: [Color(0xFF989AA4), Color(0xFF989AA4)],
    status: TileStatus.update,
  ),
  'supertuxkart': SampleApp(
    name: 'SuperTuxKart',
    category: 'Games',
    summary: 'Kart racing with Tux and friends, local and online.',
    size: '612 MB',
    version: '1.4',
    icon: 'supertuxkart',
    backdrop: [Color(0xFF8FD3FF), Color(0xFF3F93E8)],
    angle: 170,
    scale: 0.86,
    status: TileStatus.installed,
  ),
  'unciv': SampleApp(
    name: 'Unciv',
    category: 'Games',
    summary: 'An open-source take on Civilization V, made for small screens.',
    size: '31 MB',
    version: '4.17.4',
    icon: 'unciv',
    backdrop: [Color(0xFF233A7A), Color(0xFF142453)],
    scale: 0.86,
    status: TileStatus.confirm,
  ),
  'moonlight': SampleApp(
    name: 'Moonlight',
    category: 'Utilities',
    summary: 'Stream games from your PC with low latency.',
    size: '14 MB',
    version: '12.1',
    icon: 'moonlight',
    backdrop: [Color(0xFF565C64), Color(0xFF565C64)],
    status: TileStatus.otherSource,
  ),
  'syncthing': SampleApp(
    name: 'Syncthing',
    category: 'Utilities',
    summary: 'Keep save files in sync between devices. No cloud.',
    size: '28 MB',
    version: '1.29.5',
    icon: 'syncthing',
    backdrop: [Color(0xFFFFFFFF), Color(0xFFE3F1F8)],
    scale: 0.84,
    status: TileStatus.installed,
  ),
  'amaze': SampleApp(
    name: 'Amaze',
    category: 'Utilities',
    summary: 'A file manager that is easy to drive with a pad.',
    size: '9 MB',
    version: '3.10',
    icon: 'amaze',
    backdrop: [Color(0xFFE9F1FF), Color(0xFFC9DCFF)],
    scale: 0.86,
    status: TileStatus.failed,
    failure:
        'Publisher host unreachable. Privacy Mode does not fall back to tShop.',
  ),
};

/// One fake catalog entry with the art needed to draw its tile.
class SampleApp {
  /// Creates a sample entry.
  const SampleApp({
    required this.name,
    required this.category,
    required this.summary,
    required this.size,
    required this.version,
    required this.icon,
    required this.backdrop,
    this.angle = 160,
    this.scale = 1,
    this.status = TileStatus.available,
    this.progress = 0,
    this.installedVersion,
    this.unmet,
    this.failure,
  });

  /// Display name.
  final String name;

  /// Shelf it sits on.
  final String category;

  /// One-line pitch.
  final String summary;

  /// Download size.
  final String size;

  /// Catalog version.
  final String version;

  /// File stem under `assets/sample/icons/`.
  final String icon;

  /// Two-stop tile backdrop.
  final List<Color> backdrop;

  /// CSS gradient angle in degrees.
  final double angle;

  /// Icon scale inside the tile.
  final double scale;

  /// Install state.
  final TileStatus status;

  /// Download progress 0–1.
  final double progress;

  /// Version on the device, when installed.
  final String? installedVersion;

  /// Hardware the device doesn't report.
  final String? unmet;

  /// Why the last download failed.
  final String? failure;

  /// Asset image for the tile.
  ImageProvider get image => AssetImage('assets/sample/icons/$icon.png');

  /// Backdrop as a Flutter gradient matching the CSS angle.
  LinearGradient get gradient {
    final radians = angle * math.pi / 180;
    final direction = Alignment(math.sin(radians), -math.cos(radians));
    return LinearGradient(
      begin: -direction,
      end: direction,
      colors: backdrop,
    );
  }

  /// Builds this app's tile.
  TshopTile tile({
    bool focused = false,
    TileContext context = TileContext.browse,
    VoidCallback? onTap,
  }) => TshopTile(
    icon: image,
    backdrop: gradient,
    iconScale: scale,
    status: status,
    context: context,
    progress: progress,
    needsHardware: unmet != null,
    focused: focused,
    semanticLabel: name,
    onTap: onTap,
  );

  /// Status chip shown in the info strip.
  TshopChip get statusChip {
    if (unmet != null) {
      return TshopChip('Needs $unmet', tone: TshopChipTone.bad);
    }
    return switch (status) {
      TileStatus.available => TshopChip(size),
      TileStatus.installed => const TshopChip(
        'Installed',
        tone: TshopChipTone.good,
      ),
      TileStatus.update => TshopChip(
        'Update $installedVersion → $version',
        tone: TshopChipTone.accent,
      ),
      TileStatus.downloading => TshopChip(
        'Downloading ${(progress * 100).round()}%',
        tone: TshopChipTone.accent,
      ),
      TileStatus.confirm => const TshopChip(
        'Downloaded · confirm in Library',
        tone: TshopChipTone.good,
      ),
      TileStatus.failed => const TshopChip(
        'Download failed',
        tone: TshopChipTone.bad,
      ),
      TileStatus.otherSource => const TshopChip(
        'Installed from another source',
      ),
    };
  }
}
