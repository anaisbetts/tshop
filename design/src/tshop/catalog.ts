const ART = import.meta.glob('./art/**/*.{png,jpg}', {
  eager: true,
  query: '?url',
  import: 'default',
}) as Record<string, string>

export const CATEGORIES = ['Emulators', 'Frontends', 'Games', 'Utilities'] as const

export type Category = (typeof CATEGORIES)[number]

/**
 * What the client knows about one package on this device. Browse shows the
 * mark; Library sorts tiles into frames by it; Detail derives the one
 * primary action from it.
 */
export type Status =
  | 'available'
  | 'installed'
  | 'update'
  | 'downloading'
  | 'confirm'
  | 'failed'
  | 'other-source'

export type Entry = {
  id: string
  name: string
  publisher: string
  category: Category
  summary: string
  version: string
  released: string
  size: string
  /** Square tile backdrop. The catalog pipeline would bake this into the tile PNG. */
  backdrop: string
  /** Icon scale inside the square: >1 crops an icon's own rounded corners. */
  scale: number
  icon: string
  status: Status
  installedVersion?: string
  progress?: number
  failure?: string
  unmet?: string[]
  /** Publisher-only entry (03): same tile and detail, primary action is Go to Publisher. */
  landingPage?: string
  /** Only set when the catalog marks the release's APKs as a genuine user choice. */
  variants?: Variant[]
}

export type Variant = { label: string; note: string; size: string }

export type DetailArt = {
  feature: string
  shots: string[]
  description: string[]
  changelog: string[]
}

export const CATALOG: Entry[] = [
  {
    id: 'dolphin',
    name: 'Dolphin',
    publisher: 'Dolphin Team',
    category: 'Emulators',
    summary: 'GameCube and Wii games in HD, with netplay and save states.',
    version: '2509',
    released: '28 Sep 2026',
    size: '19 MB',
    backdrop: 'linear-gradient(160deg, #0f3b6e 0%, #082447 100%)',
    scale: 0.82,
    icon: art('icons/dolphin.png'),
    status: 'installed',
    installedVersion: '2509',
  },
  {
    id: 'ppsspp',
    name: 'PPSSPP',
    publisher: 'Henrik Rydgård',
    category: 'Emulators',
    summary: 'PSP games at up to 4× resolution, with controller remapping.',
    version: '1.18.1',
    released: '2 Oct 2026',
    size: '41 MB',
    backdrop: 'linear-gradient(160deg, #35505f 0%, #24363f 100%)',
    scale: 1.14,
    icon: art('icons/ppsspp.png'),
    status: 'update',
    installedVersion: '1.17.1',
  },
  {
    id: 'melonds',
    name: 'melonDS',
    publisher: 'Rafael Caetano',
    category: 'Emulators',
    summary: 'Nintendo DS with dual-screen layouts built for handhelds.',
    version: '1.0',
    released: '19 Aug 2026',
    size: '12 MB',
    backdrop: 'linear-gradient(160deg, #f7f3ea 0%, #e6dfcf 100%)',
    scale: 0.86,
    icon: art('icons/melonds.png'),
    status: 'downloading',
    progress: 0.62,
  },
  {
    id: 'vita3k',
    name: 'Vita3K',
    publisher: 'Vita3K Project',
    category: 'Emulators',
    summary: 'Experimental PlayStation Vita emulator.',
    version: '0.2.0',
    released: '14 Sep 2026',
    size: '33 MB',
    backdrop: 'linear-gradient(160deg, #4a2378 0%, #2a1147 100%)',
    scale: 0.84,
    icon: art('icons/vita3k.png'),
    status: 'available',
    unmet: ['Vulkan 1.1 GPU driver'],
  },
  {
    id: 'flycast',
    name: 'Flycast',
    publisher: 'flyinghead',
    category: 'Emulators',
    summary: 'Dreamcast, Naomi and Atomiswave at full speed.',
    version: '2.5',
    released: '5 Sep 2026',
    size: '16 MB',
    backdrop: 'linear-gradient(160deg, #a77cf6 0%, #7445d9 100%)',
    scale: 1.1,
    icon: art('icons/flycast.png'),
    status: 'available',
    variants: [
      { label: 'Vulkan renderer', note: 'Faster on most current handhelds', size: '16 MB' },
      { label: 'OpenGL ES renderer', note: 'For older or unusual GPU drivers', size: '15 MB' },
    ],
  },
  {
    id: 'duckstation',
    name: 'DuckStation',
    publisher: 'Stenzek',
    category: 'Emulators',
    summary: 'PlayStation games with upscaling and fast, accurate emulation.',
    version: '0.1',
    released: '12 May 2025',
    size: '—',
    backdrop: 'linear-gradient(160deg, #24304d 0%, #141b30 100%)',
    scale: 0.8,
    icon: art('icons/duckstation.png'),
    status: 'available',
    landingPage: 'This emulator’s license does not allow tShop to redistribute it.',
  },
  {
    id: 'scummvm',
    name: 'ScummVM',
    publisher: 'ScummVM Team',
    category: 'Emulators',
    summary: 'Classic point-and-click adventures on modern hardware.',
    version: '2.9.1',
    released: '30 Jul 2026',
    size: '96 MB',
    backdrop: 'linear-gradient(160deg, #fff8dc 0%, #f1e3a6 100%)',
    scale: 0.8,
    icon: art('icons/scummvm.png'),
    status: 'installed',
    installedVersion: '2.9.1',
  },
  {
    id: 'retroarch',
    name: 'RetroArch',
    publisher: 'Libretro',
    category: 'Frontends',
    summary: 'One frontend for hundreds of cores, shaders and netplay.',
    version: '1.21.0',
    released: '21 Sep 2026',
    size: '118 MB',
    backdrop: '#333333',
    scale: 1,
    icon: art('icons/retroarch.png'),
    status: 'available',
  },
  {
    id: 'lemuroid',
    name: 'Lemuroid',
    publisher: 'Swordfish90',
    category: 'Frontends',
    summary: 'Point it at a folder of games and play. No setup.',
    version: '1.16.0',
    released: '11 Sep 2026',
    size: '64 MB',
    backdrop: 'linear-gradient(160deg, #2ccb63 0%, #18a64c 100%)',
    scale: 1.14,
    icon: art('icons/lemuroid.png'),
    status: 'update',
    installedVersion: '1.15.2',
  },
  {
    id: 'pixel-dungeon',
    name: 'Shattered Pixel Dungeon',
    publisher: 'Shattered Pixel',
    category: 'Games',
    summary: 'A traditional roguelike: every run a new dungeon.',
    version: '3.2.0',
    released: '24 Sep 2026',
    size: '24 MB',
    backdrop: '#2b2b28',
    scale: 1.08,
    icon: art('icons/pixel-dungeon.png'),
    status: 'available',
  },
  {
    id: 'mindustry',
    name: 'Mindustry',
    publisher: 'Anuken',
    category: 'Games',
    summary: 'Build supply chains and defend them in a factory-tower hybrid.',
    version: '146',
    released: '1 Oct 2026',
    size: '78 MB',
    backdrop: '#989aa4',
    scale: 1,
    icon: art('icons/mindustry.png'),
    status: 'update',
    installedVersion: '145.1',
  },
  {
    id: 'supertuxkart',
    name: 'SuperTuxKart',
    publisher: 'SuperTuxKart Team',
    category: 'Games',
    summary: 'Kart racing with Tux and friends, local and online.',
    version: '1.4',
    released: '9 Jun 2026',
    size: '612 MB',
    backdrop: 'linear-gradient(170deg, #8fd3ff 0%, #3f93e8 100%)',
    scale: 0.86,
    icon: art('icons/supertuxkart.png'),
    status: 'installed',
    installedVersion: '1.4',
  },
  {
    id: 'unciv',
    name: 'Unciv',
    publisher: 'yairm210',
    category: 'Games',
    summary: 'An open-source take on Civilization V, made for small screens.',
    version: '4.17.4',
    released: '3 Oct 2026',
    size: '31 MB',
    backdrop: 'linear-gradient(160deg, #233a7a 0%, #142453 100%)',
    scale: 0.86,
    icon: art('icons/unciv.png'),
    status: 'confirm',
  },
  {
    id: 'moonlight',
    name: 'Moonlight',
    publisher: 'Moonlight Game Streaming',
    category: 'Utilities',
    summary: 'Stream games from your PC with low latency.',
    version: '12.1',
    released: '17 Aug 2026',
    size: '14 MB',
    backdrop: '#565c64',
    scale: 1,
    icon: art('icons/moonlight.png'),
    status: 'other-source',
  },
  {
    id: 'syncthing',
    name: 'Syncthing',
    publisher: 'Syncthing Foundation',
    category: 'Utilities',
    summary: 'Keep save files in sync between devices. No cloud.',
    version: '1.29.5',
    released: '22 Sep 2026',
    size: '28 MB',
    backdrop: 'linear-gradient(160deg, #ffffff 0%, #e3f1f8 100%)',
    scale: 0.84,
    icon: art('icons/syncthing.png'),
    status: 'installed',
    installedVersion: '1.29.5',
  },
  {
    id: 'amaze',
    name: 'Amaze',
    publisher: 'Team Amaze',
    category: 'Utilities',
    summary: 'A file manager that is easy to drive with a pad.',
    version: '3.10',
    released: '12 Jul 2026',
    size: '9 MB',
    backdrop: 'linear-gradient(160deg, #e9f1ff 0%, #c9dcff 100%)',
    scale: 0.86,
    icon: art('icons/amaze.png'),
    status: 'failed',
    failure: 'Publisher host unreachable. Privacy Mode does not fall back to tShop.',
  },
]

export const DETAIL_ART: Record<string, DetailArt> = {
  'pixel-dungeon': {
    feature: art('shots/pixel-dungeon-feature.jpg'),
    shots: [1, 2, 3, 4].map((n) => art(`shots/pixel-dungeon-shot-${n}.jpg`)),
    description: [
      'Shattered Pixel Dungeon is a roguelike RPG with pixel art graphics and simple, tactical gameplay. Explore an ever-changing dungeon, fight monsters, find loot, and level up your hero.',
      'Four hero classes, hundreds of items, and runs that last minutes or hours. Fully playable with a d-pad.',
    ],
    changelog: [
      'New boss behaviour on depth 20',
      'Rebalanced the Duelist’s abilities',
      'Controller hints for every menu',
    ],
  },
  mindustry: {
    feature: art('shots/mindustry-feature.jpg'),
    shots: [1, 2, 3, 4].map((n) => art(`shots/mindustry-shot-${n}.jpg`)),
    description: [
      'Create elaborate supply chains of conveyor belts to feed ammunition into your turrets, produce materials to use for building, and defend your structures from waves of enemies.',
    ],
    changelog: ['Erekir campaign fixes', 'Faster world loading on large maps', 'Gamepad cursor acceleration'],
  },
  unciv: {
    feature: art('shots/unciv-feature.jpg'),
    shots: [1, 2, 3, 4].map((n) => art(`shots/unciv-shot-${n}.jpg`)),
    description: [
      'An open-source, mobile-first, moddable remake of Civilization V. Lead a civilization from the ancient era to the space age, one turn at a time.',
    ],
    changelog: ['New religion victory screen', 'Mod manager search', 'Smaller saves'],
  },
}

/** Library tab badge: queued items plus available updates. */
export function libraryCount(entries: Entry[] = CATALOG): number {
  return entries.filter((entry) => ['downloading', 'confirm', 'failed', 'update'].includes(entry.status)).length
}

export function byId(id: string): Entry {
  const entry = CATALOG.find((item) => item.id === id)
  if (!entry) throw new Error(`no entry ${id}`)
  return entry
}

function art(path: string): string {
  const url = ART[`./art/${path}`]
  if (!url) throw new Error(`missing art ${path}`)
  return url
}
