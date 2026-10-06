import type { Meta, StoryObj } from '@storybook/react-vite'

import { Settings } from './Settings.tsx'

const meta = {
  title: 'tShop Theme/Settings',
  component: Settings,
  parameters: { layout: 'centered' },
  args: { canvas: 'thor', mode: 'day' },
  argTypes: {
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
  },
} satisfies Meta<typeof Settings>

export default meta

type Story = StoryObj<typeof meta>

export const Day: Story = {}

export const Night: Story = { args: { mode: 'night' } }

export const Square: Story = { args: { canvas: 'square' } }
