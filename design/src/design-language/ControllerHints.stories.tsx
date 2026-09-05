import type { Meta, StoryObj } from '@storybook/react-vite';
import { ControllerHints, type ControllerPromptItem } from './ControllerHints';

// 2. Constants
const DEFAULT_CONSOLE_PROMPTS: ControllerPromptItem[] = [
  { button: 'a', label: 'Open' },
  { button: 'b', label: 'Back' },
  { button: 'y', label: 'Search' },
  { button: 'l2', label: 'Prev Tab' },
  { button: 'r2', label: 'Next Tab' },
  { button: 'select', label: 'Privacy' },
];

const meta = {
  title: 'tShop/Controls/Controller Hints (HUD Prompts)',
  component: ControllerHints,
  parameters: {
    layout: 'padded',
    docs: {
      description: {
        component:
          'Controller HUD hints displaying action mappings with physical colored button glyphs (Nintendo A/B/X/Y and shoulder buttons).',
      },
    },
  },
} satisfies Meta<typeof ControllerHints>;

export default meta;

// 3. Types and Interfaces
type Story = StoryObj<typeof meta>;

// 4. The most important class / function in the file - the theme of what this file is about
export const DefaultBrowseHints: Story = {
  args: {
    prompts: DEFAULT_CONSOLE_PROMPTS,
    theme: 'dark',
    layout: 'nintendo',
  },
};

// 5. Second-most important classes/functions
export const DetailScreenHints: Story = {
  args: {
    prompts: [
      { button: 'a', label: 'Install / Update' },
      { button: 'b', label: 'Back to Grid' },
      { button: 'x', label: 'Screenshots' },
      { button: 'y', label: 'Open Upstream URL' },
    ],
    theme: 'dark',
    layout: 'nintendo',
  },
};

// 6. At the end, we find utility functions, helpers
// (none)
