import type { Meta, StoryObj } from '@storybook/react-vite'

import { AppTile } from './AppTile.tsx'
import { CATALOG } from './catalog.ts'
import { DeviceFrame } from './DeviceFrame.tsx'

const byState = {
  none: CATALOG.find((entry) => entry.id === 'retroarch')!,
  installed: CATALOG.find((entry) => entry.id === 'dolphin')!,
  update: CATALOG.find((entry) => entry.id === 'ppsspp')!,
  greyed: CATALOG.find((entry) => entry.id === 'flycast')!,
  downloading: CATALOG.find((entry) => entry.id === 'melonds')!,
}

const meta = {
  title: 'Design Language/App Tile',
  component: AppTile,
  parameters: { layout: 'centered' },
} satisfies Meta<typeof AppTile>

export default meta
type Story = StoryObj<typeof meta>

export const States: Story = {
  args: { entry: byState.none },
  render: () => (
    <DeviceFrame>
      <div className="tshop-canvas-pad">
        <AppTile entry={byState.none} />
        <AppTile entry={byState.installed} />
        <AppTile entry={byState.update} />
        <AppTile entry={byState.greyed} />
        <AppTile entry={byState.downloading} />
        <AppTile entry={byState.none} focused />
      </div>
    </DeviceFrame>
  ),
}

export const Focused: Story = {
  args: { entry: byState.none, focused: true },
}
