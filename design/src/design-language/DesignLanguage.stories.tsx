import type { Meta, StoryObj } from '@storybook/react-vite';
import { DesignLanguageShowcase } from './DesignLanguageShowcase';

// 2. Constants
const meta = {
  title: 'tShop/Design Language',
  component: DesignLanguageShowcase,
  parameters: {
    layout: 'fullscreen',
    docs: {
      description: {
        component:
          'Design Language documentation and interactive token explorer for tShop. Models the Nintendo 3DS continuous category grid, iiSU launcher gradient / frosted aesthetic, and Ayn Thor dual-screen viewports (837×471 top AMOLED and 592×516 bottom touchscreen).',
      },
    },
  },
} satisfies Meta<typeof DesignLanguageShowcase>;

export default meta;

// 3. Types and Interfaces
type Story = StoryObj<typeof meta>;

// 4. The most important class / function in the file - the theme of what this file is about
export const DefaultDark: Story = {
  args: {
    initialTheme: 'dark',
  },
};

// 5. Second-most important classes/functions
export const LightTheme: Story = {
  args: {
    initialTheme: 'light',
  },
};

// 6. At the end, we find utility functions, helpers
// (none)
