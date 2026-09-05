import type { Meta, StoryObj } from '@storybook/react-vite'

import { entriesByCategory } from './catalog.ts'
import { CategoryFrame } from './CategoryFrame.tsx'
import { DeviceFrame } from './DeviceFrame.tsx'

const meta = {
  title: 'Design Language/Category Frame',
  component: CategoryFrame,
  parameters: { layout: 'centered' },
} satisfies Meta<typeof CategoryFrame>

export default meta
type Story = StoryObj<typeof meta>

export const Emulators: Story = {
  args: {
    label: 'Emulators',
    entries: entriesByCategory('Emulators'),
    focusedId: 'dolphin',
  },
  render: (args) => (
    <DeviceFrame>
      <div className="tshop-shelf" style={{ gridTemplateRows: '1fr' }}>
        <CategoryFrame {...args} />
      </div>
    </DeviceFrame>
  ),
}
