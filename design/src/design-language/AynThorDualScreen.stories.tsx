import type { Meta, StoryObj } from '@storybook/react-vite';
import { AynThorDualScreen } from './AynThorDualScreen';

// 2. Constants
const meta = {
  title: 'tShop/Hardware Viewports/AYN Thor Dual Screen',
  component: AynThorDualScreen,
  parameters: {
    layout: 'fullscreen',
    docs: {
      description: {
        component:
          'Simulated AYN Thor clamshell hardware running tShop. Features the top 6" AMOLED screen (1920×1080 @ 367 DPI → 837×471 logical px) and bottom 3.92" AMOLED touchscreen (1240×1080 @ 335 DPI → 592×516 logical px) with hardware hinge.',
      },
    },
  },
} satisfies Meta<typeof AynThorDualScreen>;

export default meta;

// 3. Types and Interfaces
type Story = StoryObj<typeof meta>;

// 4. The most important class / function in the file - the theme of what this file is about
export const OnlineClamshell: Story = {
  args: {
    initialStatus: 'online',
    theme: 'dark',
  },
};

// 5. Second-most important classes/functions
export const OfflineProbeClamshell: Story = {
  args: {
    initialStatus: 'offline',
    theme: 'dark',
  },
};

export const ProbingClamshell: Story = {
  args: {
    initialStatus: 'probing',
    theme: 'dark',
  },
};

// 6. At the end, we find utility functions, helpers
// (none)
