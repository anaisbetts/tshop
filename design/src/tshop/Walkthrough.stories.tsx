import type { Meta, StoryObj } from '@storybook/react-vite'

import { Walkthrough } from './Walkthrough.tsx'

const meta = {
  title: 'tShop Theme/Walkthrough',
  component: Walkthrough,
  parameters: { layout: 'centered' },
  args: { canvas: 'thor', mode: 'day' },
  argTypes: {
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
  },
} satisfies Meta<typeof Walkthrough>

export default meta

type Story = StoryObj<typeof meta>

export const Thor: Story = {}

export const Square: Story = { args: { canvas: 'square' } }
