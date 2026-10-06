import { useEffect, useRef, type KeyboardEvent } from 'react'

import { CATALOG, libraryCount, type Entry, type Status } from './catalog.ts'
import { Legend, Screen, TopBar, type Canvas, type LegendItem, type Mode } from './Chrome.tsx'
import { InfoStrip } from './Info.tsx'
import { keyDir, useShelfFocus, type Focus, type Frame } from './nav.ts'
import { Shelf } from './Shelf.tsx'

const UPDATE_ALL = 'update-all'

const FRAMES: { id: string; label: string; statuses: Status[] }[] = [
  { id: 'queue', label: 'Queue', statuses: ['downloading', 'confirm', 'failed'] },
  { id: 'updates', label: 'Updates available', statuses: ['update'] },
  { id: 'current', label: 'Up to date', statuses: ['installed'] },
  { id: 'other', label: 'Other source', statuses: ['other-source'] },
]

export type LibraryProps = {
  canvas?: Canvas
  mode?: Mode
  online?: boolean
  /** Entry id, or `update-all` to start on the Updates frame's action tile. */
  initialFocus?: string
  onOpen?: (entry: Entry) => void
  onSwitch?: (step: number) => void
}

/** Same framed grid as Browse; frames are install states instead of categories. */
export function Library({ canvas = 'thor', mode = 'day', online = true, initialFocus, onOpen, onSwitch }: LibraryProps) {
  const rows = canvas === 'square' ? 4 : 3
  const frames = libraryFrames()
  const shelf = useShelfFocus(frames, rows, initialFocus)
  const rootRef = useRef<HTMLDivElement>(null)
  const focused = entryFor(shelf.focus)
  const updates = frames.find((frame) => frame.id === 'updates')?.entries.length ?? 0

  useEffect(() => {
    rootRef.current?.focus({ preventScroll: true })
  }, [])

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    const dir = keyDir(event.key)
    if (dir) {
      event.preventDefault()
      shelf.move(dir)
      return
    }
    switch (event.key) {
      case 'Enter':
        if (focused) onOpen?.(focused)
        break
      case '[':
        onSwitch?.(-1)
        break
      case ']':
        onSwitch?.(1)
        break
      default:
        return
    }
    event.preventDefault()
  }

  return (
    <Screen canvas={canvas} mode={mode} onKeyDown={onKeyDown} rootRef={rootRef}>
      <TopBar destination="library" libraryCount={libraryCount()} online={online} />
      <InfoStrip
        entry={focused}
        context="library"
        fallbackTitle={`Update all ${updates} apps`}
        fallbackSummary="Downloads start now. The rest of the queue keeps going if one fails."
      />
      <Shelf frames={frames} focus={shelf.focus} context="library" onFocus={shelf.pick} onOpen={onOpen} />
      <Legend left={legendFor(shelf.focus, focused)} middle={<ConfirmNote />} />
    </Screen>
  )
}

function libraryFrames(): Frame[] {
  return FRAMES.map(({ id, label, statuses }) => ({
    id,
    label,
    entries: CATALOG.filter((entry) => statuses.includes(entry.status)),
    lead: id === 'updates' ? { id: UPDATE_ALL, render: (focused: boolean) => <UpdateAllTile focused={focused} /> } : undefined,
  })).filter((frame) => frame.entries.length > 0)
}

function ConfirmNote() {
  return <span className="ts-legend__note">Android asks to confirm each install while you’re on Library</span>
}

function UpdateAllTile({ focused }: { focused: boolean }) {
  return (
    <button type="button" className={`ts-tile ts-action-tile${focused ? ' is-focused' : ''}`} tabIndex={-1}>
      <svg viewBox="0 0 24 24" width="30" height="30" aria-hidden="true">
        <path d="M12 4v13M6 10l6-6 6 6M5 20h14" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <span>Update All</span>
    </button>
  )
}

function legendFor(focus: Focus, entry: Entry | null): LegendItem[] {
  if (focus === UPDATE_ALL) return [{ button: 'dpad', label: 'Move' }, { button: 'A', label: 'Update All' }]
  const base: LegendItem[] = [
    { button: 'dpad', label: 'Move' },
    { button: 'A', label: 'Open' },
  ]
  switch (entry?.status) {
    case 'failed':
      return [...base, { button: 'Y', label: 'Retry' }, { button: 'X', label: 'Dismiss' }]
    case 'downloading':
    case 'confirm':
      return [...base, { button: 'X', label: 'Cancel' }]
    default:
      return base
  }
}

function entryFor(focus: Focus): Entry | null {
  return CATALOG.find((entry) => entry.id === focus) ?? null
}
