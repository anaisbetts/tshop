import type { Meta, StoryObj } from '@storybook/react-vite'

import { About } from './About.tsx'

const meta = {
  title: 'tShop Theme/About',
  component: About,
  parameters: { layout: 'centered' },
  args: { canvas: 'thor', mode: 'day' },
  argTypes: {
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
  },
} satisfies Meta<typeof About>

export default meta

type Story = StoryObj<typeof meta>

export const Day: Story = {}

export const Night: Story = { args: { mode: 'night' } }

export const SourceFocused: Story = { args: { initialFocus: 'source' } }

export const Square: Story = { args: { canvas: 'square' } }

export const SquareNight: Story = { args: { canvas: 'square', mode: 'night' } }
