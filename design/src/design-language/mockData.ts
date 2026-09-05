import type { AppTileData } from './AppTile';

// 2. Constants
export const DEFAULT_CATEGORY_NAMES = ['Emulators', 'Frontends', 'PC Emulation', 'Utilities'] as const;

// 3. Types and Interfaces
export interface CategorySection {
  id: string;
  title: string;
  description?: string;
  apps: AppTileData[];
}

// 4. The most important class / function in the file - the theme of what this file is about
export function getMockAppCatalog(): CategorySection[] {
  return [
    {
      id: 'emulators',
      title: 'Emulators',
      description: 'Popular console emulators',
      apps: [
        {
          id: 'retroarch',
          name: 'RetroArch',
          category: 'Emulators',
          version: '1.19.1',
          iconBg: 'linear-gradient(135deg, #1e293b, #0f172a)',
          iconSymbol: 'RA',
          badge: 'update',
          downloadsRecent: 1420,
        },
        {
          id: 'dolphin',
          name: 'Dolphin',
          category: 'Emulators',
          version: '2407-75',
          iconBg: 'linear-gradient(135deg, #0284c7, #0369a1)',
          iconSymbol: '🐬',
          badge: 'installed',
          downloadsRecent: 980,
        },
        {
          id: 'ppsspp',
          name: 'PPSSPP',
          category: 'Emulators',
          version: '1.17.1',
          iconBg: 'linear-gradient(135deg, #0d9488, #115e59)',
          iconSymbol: 'PSP',
          badge: 'none',
          downloadsRecent: 720,
        },
        {
          id: 'nether-sx2',
          name: 'NetherSX2',
          category: 'Emulators',
          version: 'v1.9-4248',
          iconBg: 'linear-gradient(135deg, #f59e0b, #b45309)',
          iconSymbol: 'PS2',
          badge: 'landing',
          downloadsRecent: 510,
        },
        {
          id: 'eden',
          name: 'Eden',
          category: 'Emulators',
          version: '0.1.2',
          iconBg: 'linear-gradient(135deg, #ec4899, #be185d)',
          iconSymbol: 'EDEN',
          badge: 'none',
          downloadsRecent: 430,
        },
        {
          id: 'cemu',
          name: 'Cemu',
          category: 'Emulators',
          version: '2.0-89',
          iconBg: 'linear-gradient(135deg, #6366f1, #4338ca)',
          iconSymbol: 'WiiU',
          badge: 'incompatible',
          isGreyed: true,
          unmetCapability: 'gpu:adreno',
          downloadsRecent: 310,
        },
      ],
    },
    {
      id: 'frontends',
      title: 'Frontends & Launchers',
      description: 'Console menus and launchers',
      apps: [
        {
          id: 'iisu',
          name: 'iiSU Launcher',
          category: 'Frontends',
          version: '0.8.4',
          iconBg: 'linear-gradient(135deg, #9d4edd, #f72585)',
          iconSymbol: 'iiSU',
          badge: 'installed',
          downloadsRecent: 890,
        },
        {
          id: 'daijisho',
          name: 'Daijishō',
          category: 'Frontends',
          version: '1.4.67',
          iconBg: 'linear-gradient(135deg, #e11d48, #9f1239)',
          iconSymbol: 'DJ',
          badge: 'none',
          downloadsRecent: 650,
        },
        {
          id: 'es-de',
          name: 'ES-DE',
          category: 'Frontends',
          version: '3.1.0',
          iconBg: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
          iconSymbol: 'ES',
          badge: 'landing',
          downloadsRecent: 400,
        },
        {
          id: 'pegasus',
          name: 'Pegasus',
          category: 'Frontends',
          version: 'alpha16',
          iconBg: 'linear-gradient(135deg, #475569, #334155)',
          iconSymbol: 'PEG',
          badge: 'none',
          downloadsRecent: 220,
        },
      ],
    },
    {
      id: 'utilities',
      title: 'Console Utilities',
      description: 'Device tuning, audio & sync',
      apps: [
        {
          id: 'odintools',
          name: 'OdinTools',
          category: 'Utilities',
          version: '1.2.3',
          iconBg: 'linear-gradient(135deg, #10b981, #047857)',
          iconSymbol: '⚙️',
          badge: 'none',
          downloadsRecent: 410,
        },
        {
          id: 'syncthing',
          name: 'Syncthing Fork',
          category: 'Utilities',
          version: '1.27.0',
          iconBg: 'linear-gradient(135deg, #0284c7, #0f172a)',
          iconSymbol: 'SYNC',
          badge: 'installed',
          downloadsRecent: 350,
        },
      ],
    },
  ];
}
