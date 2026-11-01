import type { Meta, StoryObj } from '@storybook/react-vite'

import { Stats } from './Stats.tsx'

const meta = {
  title: 'tShop Theme/Public stats (web page)',
  component: Stats,
  parameters: { layout: 'fullscreen' },
  args: { mode: 'day' },
  argTypes: { mode: { control: 'inline-radio', options: ['day', 'night'] } },
} satisfies Meta<typeof Stats>

export default meta

type Story = StoryObj<typeof meta>

export const Day: Story = {}

export const Night: Story = { args: { mode: 'night' } }
