import { useEffect, useMemo, useRef, type KeyboardEvent } from 'react'

import { CATALOG, CATEGORIES, DETAIL_ART, libraryCount, type Entry } from './catalog.ts'
import { Legend, Pad, Screen, TopBar, type Canvas, type Mode } from './Chrome.tsx'
import { InfoStrip } from './Info.tsx'
import { keyDir, useShelfFocus, type Focus, type Frame } from './nav.ts'
import { Shelf } from './Shelf.tsx'

/** Committed queries the sketch cycles through; real search opens the IME. */
const SAMPLE_QUERY = 'dungeon'

export type BrowseProps = {
  canvas?: Canvas
  mode?: Mode
  online?: boolean
  query?: string
  initialFocus?: string
  onOpen?: (entry: Entry) => void
  onSwitch?: (step: number) => void
  onQuery?: (query: string | undefined) => void
}

export function Browse({
  canvas = 'thor',
  mode = 'day',
  online = true,
  query,
  initialFocus,
  onOpen,
  onSwitch,
  onQuery,
}: BrowseProps) {
  const rows = canvas === 'square' ? 4 : 3
  const frames = useMemo(() => browseFrames(query), [query])
  const shelf = useShelfFocus(frames, rows, initialFocus)
  const rootRef = useRef<HTMLDivElement>(null)
  const focused = entryFor(shelf.focus)
  const active = CATALOG.filter((entry) => entry.status === 'downloading' || entry.status === 'confirm')

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
      case 'y':
        onQuery?.(SAMPLE_QUERY)
        break
      case 'x':
        onQuery?.(undefined)
        break
      default:
        return
    }
    event.preventDefault()
  }

  return (
    <Screen canvas={canvas} mode={mode} onKeyDown={onKeyDown} rootRef={rootRef}>
      <TopBar destination="browse" libraryCount={libraryCount()} online={online} query={query} showSearch />
      <InfoStrip
        entry={focused}
        context="browse"
        fallbackTitle={query ? `No apps match “${query}”` : 'Browse'}
        fallbackSummary="Try a shorter word, or clear the search."
      />
      <Shelf
        frames={frames}
        focus={shelf.focus}
        context="browse"
        onFocus={shelf.pick}
        onOpen={onOpen}
        empty={
          <>
            Nothing in the catalog matches.
            <span className="ts-legend__item">
              <Pad button="X" /> Clear search
            </span>
          </>
        }
      />
      <Legend
        left={
          frames.length > 0
            ? [
                { button: 'dpad', label: 'Move' },
                { button: 'A', label: 'Open' },
              ]
            : [{ button: 'X', label: 'Clear search' }]
        }
        middle={active.length > 0 ? <DownloadStrip active={active} compact={canvas === 'square'} /> : null}
      />
    </Screen>
  )
}

function DownloadStrip({ active, compact }: { active: Entry[]; compact: boolean }) {
  const lead = active.find((entry) => entry.status === 'downloading') ?? active[0]
  const progress = lead.status === 'downloading' ? (lead.progress ?? 0) : 1
  return (
    <span className="ts-downloads">
      {compact ? `${active.length} active` : `${lead.name} ${Math.round(progress * 100)}%`}
      <span className="ts-downloads__bar">
        <span style={{ width: `${Math.round(progress * 100)}%` }} />
      </span>
      <span className="ts-downloads__go">{compact ? 'Library' : `+${active.length - 1} · Library`}</span>
    </span>
  )
}

function browseFrames(query: string | undefined): Frame[] {
  const needle = query?.trim().toLowerCase()
  return CATEGORIES.map((category) => ({
    id: category,
    label: category,
    entries: CATALOG.filter(
      (entry) =>
        entry.category === category &&
        (!needle || searchText(entry).includes(needle)),
    ),
  })).filter((frame) => frame.entries.length > 0)
}

/** Spec: name, summary, or description. */
function searchText(entry: Entry): string {
  return [entry.name, entry.summary, ...(DETAIL_ART[entry.id]?.description ?? [])].join(' ').toLowerCase()
}

function entryFor(focus: Focus): Entry | null {
  return CATALOG.find((entry) => entry.id === focus) ?? null
}
