import type { Meta, StoryObj } from '@storybook/react-vite'

import { Browse } from './Browse.tsx'

const meta = {
  title: 'tShop Theme/Browse',
  component: Browse,
  parameters: { layout: 'centered' },
  args: { canvas: 'thor', mode: 'day', online: true, initialFocus: 'dolphin' },
  argTypes: {
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
  },
} satisfies Meta<typeof Browse>

export default meta

type Story = StoryObj<typeof meta>

export const Day: Story = {}

export const Night: Story = { args: { mode: 'night', initialFocus: 'pixel-dungeon' } }

export const SquareDay: Story = { args: { canvas: 'square', initialFocus: 'ppsspp' } }

export const SquareNight: Story = { args: { canvas: 'square', mode: 'night', initialFocus: 'ppsspp' } }

export const UnmetCapability: Story = { args: { initialFocus: 'vita3k' } }

export const SearchResults: Story = { args: { query: 'games', initialFocus: 'ppsspp' } }

export const Offline: Story = { args: { online: false, initialFocus: 'retroarch' } }
