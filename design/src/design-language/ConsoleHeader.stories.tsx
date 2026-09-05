import type { Meta, StoryObj } from '@storybook/react-vite';
import { ConsoleHeader } from './ConsoleHeader';

// 2. Constants
const meta = {
  title: 'tShop/Controls/Console Header',
  component: ConsoleHeader,
  parameters: {
    layout: 'padded',
    docs: {
      description: {
        component:
          'tShop console header featuring Browse, Library (with update badge), and Settings tabs, 3DS bitmapped Wi-Fi reachability probe icon, battery monitor, and time.',
      },
    },
  },
} satisfies Meta<typeof ConsoleHeader>;

export default meta;

// 3. Types and Interfaces
type Story = StoryObj<typeof meta>;

// 4. The most important class / function in the file - the theme of what this file is about
export const OnlineWithUpdates: Story = {
  args: {
    title: 'tShop',
    activeTab: 'browse',
    status: 'online',
    libraryBadgeCount: 3,
    batteryPercentage: 88,
    timeString: '14:28',
  },
};

// 5. Second-most important classes/functions
export const OfflineReachabilityProbe: Story = {
  args: {
    title: 'tShop',
    activeTab: 'library',
    status: 'offline',
    libraryBadgeCount: 0,
    batteryPercentage: 42,
    timeString: '18:05',
  },
};

export const ProbingNetwork: Story = {
  args: {
    title: 'tShop',
    activeTab: 'browse',
    status: 'probing',
    libraryBadgeCount: 1,
    batteryPercentage: 99,
    timeString: '09:12',
  },
};

// 6. At the end, we find utility functions, helpers
// (none)
