import type { Meta, StoryObj } from '@storybook/react-vite';
import { ScrollableAppList } from './ScrollableAppList';
import { getMockAppCatalog } from './mockData';

// 2. Constants
const meta = {
  title: 'tShop/Controls/Scrollable App List (3DS Grid)',
  component: ScrollableAppList,
  parameters: {
    layout: 'padded',
    docs: {
      description: {
        component:
          'Continuous 3DS category-framed square tile grid. Supports D-pad navigation, high-contrast focus rings, status badges (update, installed, publisher/landing, unmet capability).',
      },
    },
  },
} satisfies Meta<typeof ScrollableAppList>;

export default meta;

// 3. Types and Interfaces
type Story = StoryObj<typeof meta>;

// 4. The most important class / function in the file - the theme of what this file is about
export const FullCatalog: Story = {
  args: {
    sections: getMockAppCatalog(),
    selectedAppId: 'retroarch',
  },
};

// 5. Second-most important classes/functions
export const EmulatorsOnly: Story = {
  args: {
    sections: [getMockAppCatalog()[0]!],
    selectedAppId: 'dolphin',
  },
};

// 6. At the end, we find utility functions, helpers
// (none)
