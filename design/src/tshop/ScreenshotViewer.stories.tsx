import type { Meta, StoryObj } from '@storybook/react-vite'

import { byId } from './catalog.ts'
import { ScreenshotViewer } from './ScreenshotViewer.tsx'

const meta = {
  title: 'tShop Theme/Screenshot viewer',
  component: ScreenshotViewer,
  parameters: { layout: 'centered' },
  args: { entry: byId('pixel-dungeon'), canvas: 'thor', mode: 'day', initialIndex: 1 },
  argTypes: {
    entry: { control: false },
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
  },
} satisfies Meta<typeof ScreenshotViewer>

export default meta

type Story = StoryObj<typeof meta>

export const Day: Story = {}

export const Night: Story = { args: { mode: 'night', entry: byId('mindustry'), initialIndex: 0 } }

/** Last shot: Right does nothing, the R arrow dims. */
export const LastShot: Story = { args: { entry: byId('unciv'), initialIndex: 3 } }

/** 4:3-ish source on a near-square panel: letterboxed over a blur of itself. */
export const Square: Story = { args: { canvas: 'square', entry: byId('mindustry'), initialIndex: 1 } }

export const Offline: Story = { args: { online: false } }
