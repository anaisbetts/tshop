import type { Meta, StoryObj } from '@storybook/react-vite'
import type { ReactNode } from 'react'

import { byId, type Entry } from './catalog.ts'
import type { Mode } from './Chrome.tsx'
import { PrimaryAction } from './PrimaryAction.tsx'
import { Tile } from './Tile.tsx'

const TILE_STATES: { label: string; entry: Entry; focused?: boolean }[] = [
  { label: 'Focused', entry: byId('pixel-dungeon'), focused: true },
  { label: 'Available', entry: byId('retroarch') },
  { label: 'Installed', entry: byId('dolphin') },
  { label: 'Update', entry: byId('ppsspp') },
  { label: 'Downloading', entry: byId('melonds') },
  { label: 'Confirm', entry: byId('unciv') },
  { label: 'Failed', entry: byId('amaze') },
  { label: 'Other source', entry: byId('moonlight') },
  { label: 'Needs hardware', entry: byId('vita3k') },
]

const ACTIONS: { label: string; entry: Entry; online?: boolean }[] = [
  { label: 'Install', entry: byId('pixel-dungeon') },
  { label: 'Update', entry: byId('ppsspp') },
  { label: 'Open', entry: byId('dolphin') },
  { label: 'Downloading', entry: byId('melonds') },
  { label: 'Retry', entry: byId('amaze') },
  { label: 'Other source', entry: byId('moonlight') },
  {
    label: 'Landing Page',
    entry: { ...byId('retroarch'), landingPage: 'ES-DE for Android is a paid app sold directly by its developer.' },
  },
  { label: 'Offline', entry: byId('retroarch'), online: false },
]

const SWATCHES = [
  ['Accent', 'var(--ts-accent)'],
  ['Good', 'var(--ts-good)'],
  ['Bad', 'var(--ts-bad)'],
  ['Ink', 'var(--ts-ink)'],
  ['Ink 2', 'var(--ts-ink-2)'],
  ['Card', 'var(--ts-card)'],
  ['Wall', 'linear-gradient(180deg, var(--ts-wall-top), var(--ts-wall-bottom))'],
] as const

const meta = {
  title: 'tShop Theme/Parts',
  parameters: { layout: 'fullscreen' },
} satisfies Meta

export default meta

type Story = StoryObj<typeof meta>

export const Tiles: Story = {
  render: () => (
    <>
      {(['day', 'night'] as const).map((mode) => (
        <Sheet mode={mode} key={mode}>
          {TILE_STATES.map(({ label, entry, focused }) => (
            <div className="ts-specimen" key={label}>
              <Tile entry={entry} focused={focused} context={label === 'Other source' ? 'library' : 'browse'} />
              {label}
            </div>
          ))}
        </Sheet>
      ))}
    </>
  ),
}

export const PrimaryActions: Story = {
  render: () => (
    <>
      {(['day', 'night'] as const).map((mode) => (
        <Sheet mode={mode} key={mode}>
          {ACTIONS.map(({ label, entry, online }) => (
            <div className="ts-specimen" key={label} style={{ maxWidth: 240, justifyItems: 'start' }}>
              {label}
              <PrimaryAction entry={entry} online={online} focused={false} />
            </div>
          ))}
        </Sheet>
      ))}
    </>
  ),
}

export const Palette: Story = {
  render: () => (
    <>
      {(['day', 'night'] as const).map((mode) => (
        <Sheet mode={mode} key={mode}>
          {SWATCHES.map(([name, value]) => (
            <div className="ts-swatch" key={name}>
              <span className="ts-swatch__chip" style={{ background: value }} />
              {name}
            </div>
          ))}
          <div className="ts-specimen" style={{ justifyItems: 'start' }}>
            <span style={{ fontSize: 26, fontWeight: 900, color: 'var(--ts-ink)' }}>Shattered Pixel Dungeon</span>
            <span style={{ fontSize: 17, fontWeight: 800, color: 'var(--ts-ink)' }}>Emulators 6</span>
            <span style={{ fontSize: 12.5, fontWeight: 500 }}>A traditional roguelike: every run a new dungeon.</span>
            <span>M PLUS Rounded 1c · 900 / 800 / 700 / 500</span>
          </div>
        </Sheet>
      ))}
    </>
  ),
}

function Sheet({ mode, children }: { mode: Mode; children: ReactNode }) {
  return (
    <div className="ts-root ts-sheet" data-mode={mode}>
      {children}
    </div>
  )
}
