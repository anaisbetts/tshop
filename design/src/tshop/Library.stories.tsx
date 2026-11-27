import type { Meta, StoryObj } from '@storybook/react-vite'

import { CATALOG, type Entry, type Status } from './catalog.ts'
import { Library } from './Library.tsx'

const meta = {
  title: 'tShop Theme/Library',
  component: Library,
  parameters: { layout: 'centered' },
  args: { canvas: 'thor', mode: 'day', initialFocus: 'amaze' },
  argTypes: {
    entries: { control: false },
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
  },
} satisfies Meta<typeof Library>

export default meta

type Story = StoryObj<typeof meta>

export const FailedItem: Story = {}

export const UpdateAll: Story = { args: { initialFocus: 'update-all' } }

/** Downloaded; Android's own install prompt fires while the user stays on Library. */
export const AwaitingConfirm: Story = { args: { initialFocus: 'unciv' } }

/** Greyed: matches a catalog entry but carries another signing certificate. */
export const OtherSource: Story = { args: { initialFocus: 'moonlight' } }

export const Night: Story = { args: { mode: 'night', initialFocus: 'melonds' } }

export const Square: Story = { args: { canvas: 'square', initialFocus: 'update-all' } }

/** Nothing queued, nothing to update: only Up to date (and Other source) remain. */
export const AllUpToDate: Story = { args: { entries: withStatus({ update: 'installed', downloading: 'available', confirm: 'available', failed: 'available' }), initialFocus: 'dolphin' } }

/** Fresh device: no catalog app is installed yet. */
export const Empty: Story = { args: { entries: withStatus({ installed: 'available', update: 'available', downloading: 'available', confirm: 'available', failed: 'available', 'other-source': 'available' }), initialFocus: undefined } }

export const EmptyNight: Story = { args: { ...Empty.args, mode: 'night' } }

function withStatus(map: Partial<Record<Status, Status>>): Entry[] {
  return CATALOG.map((entry) => {
    const status = map[entry.status] ?? entry.status
    return status === entry.status ? entry : { ...entry, status, installedVersion: status === 'installed' ? entry.version : undefined }
  })
}
