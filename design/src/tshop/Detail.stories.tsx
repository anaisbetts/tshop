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

/** Present and current. Uninstall is the secondary action. */
export const Open: Story = { args: { entry: byId('dolphin') } }

/** Install was confirmed: the button became progress and the user can leave. */
export const Downloading: Story = { args: { entry: byId('melonds') } }

export const WaitingForConfirm: Story = { args: { entry: byId('unciv'), mode: 'night' } }

export const Retry: Story = { args: { entry: byId('amaze') } }

export const OtherSource: Story = { args: { entry: byId('moonlight') } }

/** Explains the greyed tile: each requirement this device doesn't meet. */
export const UnmetCapability: Story = { args: { entry: byId('vita3k') } }

export const LandingPage: Story = { args: { entry: byId('duckstation') } }

export const LandingPageNight: Story = { args: { entry: byId('duckstation'), mode: 'night' } }

/** Only when the catalog marks the APKs as a real choice; otherwise ABI and SDK decide silently. */
export const VariantChoice: Story = { args: { entry: byId('flycast'), choosingVariant: true } }

export const VariantChoiceNight: Story = { args: { entry: byId('flycast'), choosingVariant: true, mode: 'night' } }

/** D-pad down from the action lands in the strip; A opens the viewer. */
export const ScreenshotFocused: Story = { args: { initialFocus: 1 } }

export const Square: Story = { args: { canvas: 'square' } }

export const SquareNight: Story = { args: { canvas: 'square', mode: 'night', entry: byId('mindustry') } }

/** No feature graphic yet: the banner falls back to the tile backdrop and a blurred icon. */
export const NoFeatureGraphic: Story = { args: { entry: byId('vita3k') } }

export const Offline: Story = { args: { online: false } }
