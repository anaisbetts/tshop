import type { Meta, StoryObj } from '@storybook/react-vite';
import { AppDetailHero } from './AppDetailHero';

// 2. Constants
const meta = {
  title: 'tShop/Controls/App Detail Hero',
  component: AppDetailHero,
  parameters: {
    layout: 'padded',
    docs: {
      description: {
        component:
          'tShop hero detail panel displayed on the top 16:9 screen of the AYN Thor. Shows title, tags, summary, primary action button (Install, Update, Open, Go to Publisher, Mismatch), and progress bars.',
      },
    },
  },
} satisfies Meta<typeof AppDetailHero>;

export default meta;

// 3. Types and Interfaces
type Story = StoryObj<typeof meta>;

// 4. The most important class / function in the file - the theme of what this file is about
export const InstallReady: Story = {
  args: {
    name: 'iiSU Launcher',
    category: 'Frontends',
    version: '0.8.4',
    author: 'iiSU Network',
    summary:
      'Nintendo 3DS and Wii U inspired launcher for Android handhelds, featuring custom themes, frosted glass, and dedicated DS dual-screen support.',
    primaryAction: 'install',
    iconBg: 'linear-gradient(135deg, #9d4edd, #f72585)',
    iconSymbol: 'iiSU',
    isDownloading: false,
  },
};

// 5. Second-most important classes/functions
export const UpdateAvailable: Story = {
  args: {
    name: 'RetroArch',
    category: 'Emulators',
    version: '1.19.1',
    author: 'Libretro',
    summary:
      'Universal frontend for emulators with unified shader pipeline, netplay, and custom controller mappings.',
    primaryAction: 'update',
    iconBg: 'linear-gradient(135deg, #1e293b, #0f172a)',
    iconSymbol: 'RA',
    isDownloading: false,
  },
};

export const InFlightDownloading: Story = {
  args: {
    name: 'Dolphin Emulator',
    category: 'Emulators',
    version: '2407-75',
    author: 'Dolphin Team',
    summary:
      'GameCube and Wii emulator for Android with dual-screen touchscreen sensor emulation.',
    primaryAction: 'install',
    iconBg: 'linear-gradient(135deg, #0284c7, #0369a1)',
    iconSymbol: '🐬',
    isDownloading: true,
    downloadProgress: 68,
  },
};

export const LandingPagePublisherRedirect: Story = {
  args: {
    name: 'NetherSX2',
    category: 'Emulators',
    version: 'v1.9-4248',
    author: 'Trixarian',
    summary:
      'PS2 emulator patch based on AetherSX2. Due to CC BY-NC-ND licensing, tShop links directly to publisher instructions.',
    primaryAction: 'landing',
    iconBg: 'linear-gradient(135deg, #f59e0b, #b45309)',
    iconSymbol: 'PS2',
    isDownloading: false,
  },
};

// 6. At the end, we find utility functions, helpers
// (none)
