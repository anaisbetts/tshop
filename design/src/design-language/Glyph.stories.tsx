import type { Meta, StoryObj } from '@storybook/react-vite'

import { DeviceFrame } from './DeviceFrame.tsx'
import { Glyph, WifiIcon } from './Glyph.tsx'

const meta = {
  title: 'Design Language/Glyph',
  component: Glyph,
  parameters: { layout: 'centered' },
} satisfies Meta<typeof Glyph>

export default meta
type Story = StoryObj<typeof meta>

export const Set: Story = {
  args: { name: 'A' },
  render: () => (
    <DeviceFrame>
      <div className="tshop-canvas-pad">
        {(['A', 'B', 'X', 'Y', 'L', 'R', '+', '-'] as const).map((name) => (
          <Glyph key={name} name={name} />
        ))}
        <WifiIcon state="online" />
        <WifiIcon state="offline" />
      </div>
    </DeviceFrame>
  ),
}
