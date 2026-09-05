import type { Meta, StoryObj } from '@storybook/react-vite'

import { DeviceFrame } from './DeviceFrame.tsx'
import { TopBar } from './TopBar.tsx'

const meta = {
  title: 'Design Language/Top Bar',
  component: TopBar,
  parameters: { layout: 'centered' },
  args: {
    destination: 'browse',
    title: 'Dolphin',
    online: true,
    libraryCount: 4,
    onDestination: () => undefined,
  },
  render: (args) => (
    <DeviceFrame>
      <div className="tshop-shelf" style={{ gridTemplateRows: '44px' }}>
        <TopBar {...args} />
      </div>
    </DeviceFrame>
  ),
} satisfies Meta<typeof TopBar>

export default meta
type Story = StoryObj<typeof meta>

export const Browse: Story = {}

export const Offline: Story = {
  args: { online: false, title: 'Cached catalog' },
}
