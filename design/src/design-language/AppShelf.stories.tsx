import type { Meta, StoryObj } from '@storybook/react-vite'

import { AppShelf } from './AppShelf.tsx'
import { DeviceFrame } from './DeviceFrame.tsx'

const meta = {
  title: 'Design Language/App Shelf',
  component: AppShelf,
  parameters: { layout: 'fullscreen' },
  render: () => (
    <DeviceFrame>
      <AppShelf />
    </DeviceFrame>
  ),
} satisfies Meta<typeof AppShelf>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}
