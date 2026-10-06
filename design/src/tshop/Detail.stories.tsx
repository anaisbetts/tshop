import type { Meta, StoryObj } from '@storybook/react-vite'

import { byId } from './catalog.ts'
import { Detail } from './Detail.tsx'

const meta = {
  title: 'tShop Theme/Detail',
  component: Detail,
  parameters: { layout: 'centered' },
  args: { entry: byId('pixel-dungeon'), canvas: 'thor', mode: 'day', online: true },
  argTypes: {
    entry: { control: false },
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
  },
} satisfies Meta<typeof Detail>

export default meta

type Story = StoryObj<typeof meta>

export const Install: Story = {}

export const InstallNight: Story = { args: { mode: 'night' } }

export const Update: Story = { args: { entry: byId('mindustry') } }

export const WaitingForConfirm: Story = { args: { entry: byId('unciv'), mode: 'night' } }

export const Square: Story = { args: { canvas: 'square' } }

export const SquareNight: Story = { args: { canvas: 'square', mode: 'night', entry: byId('mindustry') } }

/** No feature graphic yet: the banner falls back to the tile backdrop and a blurred icon. */
export const NoFeatureGraphic: Story = { args: { entry: byId('vita3k') } }

export const OtherSource: Story = { args: { entry: byId('moonlight') } }

export const Offline: Story = { args: { online: false } }
