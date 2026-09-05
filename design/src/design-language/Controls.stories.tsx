import type { Meta, StoryObj } from '@storybook/react-vite'

import { PrimaryButton, Toggle } from './Controls.tsx'
import { DeviceFrame } from './DeviceFrame.tsx'

const meta = {
  title: 'Design Language/Controls',
  component: PrimaryButton,
  parameters: { layout: 'centered' },
} satisfies Meta<typeof PrimaryButton>

export default meta
type Story = StoryObj<typeof meta>

export const Actions: Story = {
  args: { action: 'install' },
  render: () => (
    <DeviceFrame>
      <div className="tshop-canvas-pad">
        <PrimaryButton action="install" />
        <PrimaryButton action="update" />
        <PrimaryButton action="open" />
        <PrimaryButton action="retry" />
        <PrimaryButton action="other-source" />
        <PrimaryButton action="install" progress={0.45} />
        <Toggle />
      </div>
    </DeviceFrame>
  ),
}
