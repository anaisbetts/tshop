import type { Meta, StoryObj } from '@storybook/react-vite';
import { AppTile } from './AppTile';

// 2. Constants
const meta = {
  title: 'tShop/Controls/App Tile (3DS Cartridge)',
  component: AppTile,
  parameters: {
    layout: 'centered',
    docs: {
      description: {
        component:
          '3DS cartridge-style square app tile with neutral high-contrast focus ring, badge indicators (update, installed, landing page, unmet capability), and subtle glass sheen.',
      },
    },
  },
} satisfies Meta<typeof AppTile>;

export default meta;

// 3. Types and Interfaces
type Story = StoryObj<typeof meta>;

// 4. The most important class / function in the file - the theme of what this file is about
export const DefaultFocused: Story = {
  args: {
    app: {
      id: 'retroarch',
      name: 'RetroArch',
      category: 'Emulators',
      version: '1.19.1',
      iconBg: 'linear-gradient(135deg, #1e293b, #0f172a)',
      iconSymbol: 'RA',
      badge: 'update',
      downloadsRecent: 1420,
    },
    isFocused: true,
  },
};

// 5. Second-most important classes/functions
export const InstalledState: Story = {
  args: {
    app: {
      id: 'dolphin',
      name: 'Dolphin',
      category: 'Emulators',
      version: '2407-75',
      iconBg: 'linear-gradient(135deg, #0284c7, #0369a1)',
      iconSymbol: '🐬',
      badge: 'installed',
      downloadsRecent: 980,
    },
    isFocused: false,
  },
};

export const LandingPagePublisherState: Story = {
  args: {
    app: {
      id: 'nether-sx2',
      name: 'NetherSX2',
      category: 'Emulators',
      version: 'v1.9-4248',
      iconBg: 'linear-gradient(135deg, #f59e0b, #b45309)',
      iconSymbol: 'PS2',
      badge: 'landing',
      downloadsRecent: 510,
    },
    isFocused: false,
  },
};

export const IncompatibleGreyedState: Story = {
  args: {
    app: {
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
    isFocused: false,
  },
};

// 6. At the end, we find utility functions, helpers
// (none)
