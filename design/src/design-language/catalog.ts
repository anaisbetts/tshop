const ICON_URLS = import.meta.glob('./apps/*.png', {
  eager: true,
  query: '?url',
  import: 'default',
}) as Record<string, string>

export const CATEGORIES = ['Emulators', 'Frontends', 'Games', 'Utilities'] as const

export type Category = (typeof CATEGORIES)[number]

export type TileState = 'installed' | 'update' | 'greyed' | 'downloading' | 'none'

export type CatalogEntry = {
  id: string
  name: string
  category: Category
  icon: string
  state: TileState
  summary: string
  version: string
  progress?: number
}

export const CATALOG: CatalogEntry[] = [
  {
    id: 'dolphin',
    name: 'Dolphin',
    category: 'Emulators',
    icon: iconUrl('dolphin.png'),
    state: 'installed',
    summary: 'GameCube and Wii emulator',
    version: '2509',
  },
  {
    id: 'ppsspp',
    name: 'PPSSPP',
    category: 'Emulators',
    icon: iconUrl('ppsspp.png'),
    state: 'update',
    summary: 'PSP emulator',
    version: '1.18.1',
  },
  {
    id: 'retroarch',
    name: 'RetroArch',
    category: 'Emulators',
    icon: iconUrl('retroarch.png'),
    state: 'none',
    summary: 'Libretro frontend',
    version: '1.21.0',
  },
  {
    id: 'melonds',
    name: 'melonDS',
    category: 'Emulators',
    icon: iconUrl('melonds.png'),
    state: 'downloading',
    summary: 'DS emulator',
    version: '1.0',
    progress: 0.62,
  },
  {
    id: 'flycast',
    name: 'Flycast',
    category: 'Emulators',
    icon: iconUrl('flycast.png'),
    state: 'greyed',
    summary: 'Dreamcast emulator',
    version: '2.5',
  },
  {
    id: 'vita3k',
    name: 'Vita3K',
    category: 'Emulators',
    icon: iconUrl('vita3k.png'),
    state: 'none',
    summary: 'PlayStation Vita emulator',
    version: '0.2.0',
  },
  {
    id: 'scummvm',
    name: 'ScummVM',
    category: 'Emulators',
    icon: iconUrl('scummvm.png'),
    state: 'installed',
    summary: 'Classic adventure engine',
    version: '2.9.1',
  },
  {
    id: 'lemuroid',
    name: 'Lemuroid',
    category: 'Frontends',
    icon: iconUrl('lemuroid.png'),
    state: 'update',
    summary: 'Android emulation frontend',
    version: '1.16.0',
  },
  {
    id: 'supertuxkart',
    name: 'SuperTuxKart',
    category: 'Games',
    icon: iconUrl('supertuxkart.png'),
    state: 'none',
    summary: 'Kart racer',
    version: '1.4',
  },
  {
    id: 'mindustry',
    name: 'Mindustry',
    category: 'Games',
    icon: iconUrl('mindustry.png'),
    state: 'installed',
    summary: 'Factory sandbox',
    version: '146',
  },
  {
    id: 'pixel-dungeon',
    name: 'Shattered PD',
    category: 'Games',
    icon: iconUrl('pixel-dungeon.png'),
    state: 'downloading',
    summary: 'Roguelike dungeon crawl',
    version: '3.2.0',
    progress: 0.35,
  },
  {
    id: 'unciv',
    name: 'Unciv',
    category: 'Games',
    icon: iconUrl('unciv.png'),
    state: 'none',
    summary: 'Civilization-style 4X',
    version: '4.17.4',
  },
  {
    id: 'moonlight',
    name: 'Moonlight',
    category: 'Utilities',
    icon: iconUrl('moonlight.png'),
    state: 'greyed',
    summary: 'Game streaming client',
    version: '12.1',
  },
  {
    id: 'syncthing',
    name: 'Syncthing',
    category: 'Utilities',
    icon: iconUrl('syncthing.png'),
    state: 'installed',
    summary: 'Peer file sync',
    version: '1.29.5',
  },
  {
    id: 'amaze',
    name: 'Amaze',
    category: 'Utilities',
    icon: iconUrl('amaze.png'),
    state: 'none',
    summary: 'File manager',
    version: '3.10',
  },
]

export function entriesByCategory(category: Category): CatalogEntry[] {
  return CATALOG.filter((entry) => entry.category === category)
}

export function libraryFrames(): { label: string; entries: CatalogEntry[] }[] {
  return [
    { label: 'Queue', entries: CATALOG.filter((entry) => entry.state === 'downloading') },
    { label: 'Updates available', entries: CATALOG.filter((entry) => entry.state === 'update') },
    { label: 'Up to date', entries: CATALOG.filter((entry) => entry.state === 'installed') },
  ].filter((frame) => frame.entries.length > 0)
}

function iconUrl(file: string): string {
  const url = ICON_URLS[`./apps/${file}`]
  if (!url) throw new Error(`missing icon ${file}`)
  return url
}
