import type { Meta, StoryObj } from '@storybook/react-vite'

import { Library } from './Library.tsx'

const meta = {
  title: 'tShop Theme/Library',
  component: Library,
  parameters: { layout: 'centered' },
  args: { canvas: 'thor', mode: 'day', initialFocus: 'amaze' },
  argTypes: {
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
  },
} satisfies Meta<typeof Library>

export default meta

type Story = StoryObj<typeof meta>

export const FailedItem: Story = {}

export const UpdateAll: Story = { args: { initialFocus: 'update-all' } }

export const Night: Story = { args: { mode: 'night', initialFocus: 'melonds' } }

export const Square: Story = { args: { canvas: 'square', initialFocus: 'update-all' } }
