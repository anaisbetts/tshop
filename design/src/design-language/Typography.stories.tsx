import type { Meta, StoryObj } from '@storybook/react-vite'

import { DeviceFrame } from './DeviceFrame.tsx'
import { Palette, Typography } from './Typography.tsx'

const meta = {
  title: 'Design Language/Typography',
  component: Typography,
  parameters: { layout: 'centered' },
} satisfies Meta<typeof Typography>

export default meta
type Story = StoryObj<typeof meta>

export const Specimens: Story = {
  render: () => (
    <DeviceFrame>
      <Typography />
    </DeviceFrame>
  ),
}

export const Colors: Story = {
  render: () => (
    <DeviceFrame>
      <div className="tshop-canvas-pad">
        <Palette />
      </div>
    </DeviceFrame>
  ),
}
