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

/** Every frame emptied, so every frame is gone; clearing is the only move. */
export const SearchNoResults: Story = { args: { query: 'pinball' } }

export const SearchNoResultsNight: Story = { args: { query: 'pinball', mode: 'night' } }

/** Publisher-only entry: same tile, no install mark; Detail offers Go to Publisher. */
export const LandingPage: Story = { args: { initialFocus: 'duckstation' } }

export const Offline: Story = { args: { online: false, initialFocus: 'retroarch' } }

export const OfflineNight: Story = { args: { online: false, mode: 'night', initialFocus: 'retroarch' } }
