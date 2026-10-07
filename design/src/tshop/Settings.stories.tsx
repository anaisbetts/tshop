import type { Meta, StoryObj } from '@storybook/react-vite'

import { Settings } from './Settings.tsx'

const meta = {
  title: 'tShop Theme/Settings',
  component: Settings,
  parameters: { layout: 'centered' },
  args: { canvas: 'thor', mode: 'day' },
  argTypes: {
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
    padLayout: { control: 'inline-radio', options: ['nintendo', 'xbox'] },
  },
} satisfies Meta<typeof Settings>

export default meta

type Story = StoryObj<typeof meta>

export const Day: Story = {}

export const Night: Story = { args: { mode: 'night' } }

/** On: downloads come from each publisher's URL and fail rather than fall back to the counted host. */
export const PrivacyModeOn: Story = { args: { privacy: true } }

export const PrivacyModeOnNight: Story = { args: { privacy: true, mode: 'night' } }

/** From 04: the layout is a setting and every hint on screen follows it. */
export const ButtonLayoutNintendo: Story = { args: { initialFocus: 'layout', padLayout: 'nintendo' } }

export const ButtonLayoutXbox: Story = { args: { initialFocus: 'layout', padLayout: 'xbox' } }

export const ButtonLayoutXboxNight: Story = { args: { initialFocus: 'layout', padLayout: 'xbox', mode: 'night' } }

export const AboutFocused: Story = { args: { initialFocus: 'about' } }

export const Square: Story = { args: { canvas: 'square' } }

export const SquareNight: Story = { args: { canvas: 'square', mode: 'night', initialFocus: 'layout', padLayout: 'xbox' } }
