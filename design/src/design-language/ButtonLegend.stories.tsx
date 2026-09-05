import type { Meta, StoryObj } from '@storybook/react-vite'

import { ButtonLegend } from './ButtonLegend.tsx'
import { DeviceFrame } from './DeviceFrame.tsx'

const meta = {
  title: 'Design Language/Button Legend',
  component: ButtonLegend,
  parameters: { layout: 'centered' },
  render: () => (
    <DeviceFrame>
      <div className="tshop-shelf" style={{ gridTemplateRows: '1fr 36px' }}>
        <div />
        <ButtonLegend />
      </div>
    </DeviceFrame>
  ),
} satisfies Meta<typeof ButtonLegend>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}
