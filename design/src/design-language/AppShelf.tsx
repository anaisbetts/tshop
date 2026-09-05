import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react'

import { ButtonLegend } from './ButtonLegend.tsx'
import { CATEGORIES, CATALOG, entriesByCategory, libraryFrames, type CatalogEntry } from './catalog.ts'
import { CategoryFrame } from './CategoryFrame.tsx'
import { Toggle } from './Controls.tsx'
import { DESTINATIONS, TopBar, type Destination } from './TopBar.tsx'

const ROWS = 3

type Cursor = { frame: number; col: number; row: number }

type Dir = 'left' | 'right' | 'up' | 'down'

export function AppShelf() {
  const [destination, setDestination] = useState<Destination>('browse')
  const [online, setOnline] = useState(true)
  const [cursor, setCursor] = useState<Cursor | null>({ frame: 0, col: 0, row: 0 })
  const [opened, setOpened] = useState(false)
  const preferredRow = useRef(0)
  const stripRef = useRef<HTMLDivElement>(null)
  const rootRef = useRef<HTMLDivElement>(null)

  const frames = useMemo(() => framesFor(destination), [destination])
  const focused = cursor ? entryAt(frames, cursor) : null
  const title = focused?.name ?? destinationTitle(destination)
  const libraryCount =
    CATALOG.filter((entry) => entry.state === 'update' || entry.state === 'downloading').length

  useEffect(() => {
    rootRef.current?.focus()
  }, [destination])

  useEffect(() => {
    if (!focused) return
    stripRef.current
      ?.querySelector<HTMLElement>(`[data-entry-id="${focused.id}"]`)
      ?.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' })
  }, [focused])

  function setFocus(next: Cursor | null) {
    setCursor(next)
    setOpened(false)
    if (next) preferredRow.current = next.row
  }

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key === '[' || event.key === 'l') {
      event.preventDefault()
      cycleDestination(-1)
      return
    }
    if (event.key === ']' || event.key === 'r') {
      event.preventDefault()
      cycleDestination(1)
      return
    }
    if (destination === 'settings') return

    if (event.key === 'Escape') {
      event.preventDefault()
      setFocus(null)
      return
    }
    if (event.key === 'Enter' && focused) {
      event.preventDefault()
      setOpened(true)
      return
    }

    const dir = keyDir(event.key)
    if (!dir) return
    event.preventDefault()
    const start = cursor ?? { frame: 0, col: 0, row: preferredRow.current }
    const next = moveCursor(frames, start, dir, preferredRow.current)
    preferredRow.current = next.preferredRow
    setCursor(next.cursor)
    setOpened(false)
  }

  function cycleDestination(step: number) {
    const index = DESTINATIONS.indexOf(destination)
    const next = DESTINATIONS[(index + step + DESTINATIONS.length) % DESTINATIONS.length]
    setDestination(next)
    setCursor(next === 'settings' ? null : { frame: 0, col: 0, row: 0 })
    setOpened(false)
    preferredRow.current = 0
  }

  return (
    <div className="tshop-shelf" ref={rootRef} tabIndex={0} onKeyDown={onKeyDown}>
      <TopBar
        destination={destination}
        title={opened && focused ? `${focused.name} · ${focused.version}` : title}
        opened={opened}
        online={online}
        libraryCount={libraryCount}
        onDestination={(next) => {
          setDestination(next)
          setCursor(next === 'settings' ? null : { frame: 0, col: 0, row: 0 })
          setOpened(false)
        }}
        onToggleOnline={() => setOnline((value) => !value)}
      />
      {destination === 'settings' ? (
        <section className="tshop-settings">
          <h2>Settings</h2>
          <p>Privacy Mode. Off by default. Catalog and artwork stay on tShop either way.</p>
          <Toggle />
        </section>
      ) : frames.length === 0 ? (
        <section className="tshop-empty">
          <h2>Library</h2>
          <p>Nothing installed yet.</p>
        </section>
      ) : (
        <div className="tshop-shelf__strip" ref={stripRef}>
          {frames.map((frame) => (
            <CategoryFrame
              key={frame.label}
              label={frame.label}
              entries={frame.entries}
              focusedId={focused?.id}
              onFocus={(id) => {
                const next = cursorOf(frames, id)
                if (next) setFocus(next)
              }}
              onOpen={() => setOpened(true)}
            />
          ))}
        </div>
      )}
      <div className="tshop-dots-row">
        {frames.map((frame, index) => (
          <button
            key={frame.label}
            type="button"
            className={['tshop-page-dot', cursor?.frame === index ? 'is-active' : ''].filter(Boolean).join(' ')}
            aria-label={frame.label}
            onClick={() => setFocus({ frame: index, col: 0, row: 0 })}
          />
        ))}
      </div>
      <ButtonLegend />
    </div>
  )
}

function framesFor(destination: Destination): { label: string; entries: CatalogEntry[] }[] {
  switch (destination) {
    case 'browse':
      return CATEGORIES.map((category) => ({
        label: category,
        entries: entriesByCategory(category),
      })).filter((frame) => frame.entries.length > 0)
    case 'library':
      return libraryFrames()
    case 'settings':
      return []
    default: {
      const _never: never = destination
      return _never
    }
  }
}

function destinationTitle(destination: Destination): string {
  switch (destination) {
    case 'browse':
      return 'Browse'
    case 'library':
      return 'Library'
    case 'settings':
      return 'Settings'
    default: {
      const _never: never = destination
      return _never
    }
  }
}

function keyDir(key: string): Dir | null {
  switch (key) {
    case 'ArrowLeft':
      return 'left'
    case 'ArrowRight':
      return 'right'
    case 'ArrowUp':
      return 'up'
    case 'ArrowDown':
      return 'down'
    default:
      return null
  }
}

function moveCursor(
  frames: { entries: CatalogEntry[] }[],
  cursor: Cursor,
  dir: Dir,
  preferredRow: number,
): { cursor: Cursor; preferredRow: number } {
  if (frames.length === 0) return { cursor, preferredRow }

  switch (dir) {
    case 'up':
      return clampCursor(frames, { ...cursor, row: cursor.row - 1 }, cursor.row - 1)
    case 'down':
      return clampCursor(frames, { ...cursor, row: cursor.row + 1 }, cursor.row + 1)
    case 'left':
      if (cursor.col > 0) {
        return clampCursor(frames, { ...cursor, col: cursor.col - 1 }, preferredRow)
      }
      if (cursor.frame > 0) {
        const frame = cursor.frame - 1
        return clampCursor(
          frames,
          { frame, col: columnsIn(frames[frame].entries.length) - 1, row: preferredRow },
          preferredRow,
        )
      }
      return { cursor, preferredRow }
    case 'right':
      if (cursor.col < columnsIn(frames[cursor.frame].entries.length) - 1) {
        return clampCursor(frames, { ...cursor, col: cursor.col + 1 }, preferredRow)
      }
      if (cursor.frame < frames.length - 1) {
        return clampCursor(frames, { frame: cursor.frame + 1, col: 0, row: preferredRow }, preferredRow)
      }
      return { cursor, preferredRow }
    default: {
      const _never: never = dir
      return _never
    }
  }
}

function clampCursor(
  frames: { entries: CatalogEntry[] }[],
  next: Cursor,
  preferredRow: number,
): { cursor: Cursor; preferredRow: number } {
  const frame = Math.max(0, Math.min(next.frame, frames.length - 1))
  const count = frames[frame].entries.length
  const col = Math.max(0, Math.min(next.col, columnsIn(count) - 1))
  const row = Math.max(0, Math.min(preferredRow, rowsInCol(count, col) - 1))
  return { cursor: { frame, col, row }, preferredRow }
}

function entryAt(frames: { entries: CatalogEntry[] }[], cursor: Cursor): CatalogEntry | null {
  const frame = frames[cursor.frame]
  if (!frame) return null
  return frame.entries[cursor.col * ROWS + cursor.row] ?? null
}

function cursorOf(frames: { entries: CatalogEntry[] }[], id: string): Cursor | null {
  for (let frame = 0; frame < frames.length; frame += 1) {
    const index = frames[frame].entries.findIndex((entry) => entry.id === id)
    if (index === -1) continue
    return { frame, col: Math.floor(index / ROWS), row: index % ROWS }
  }
  return null
}

function columnsIn(count: number): number {
  return Math.max(1, Math.ceil(count / ROWS))
}

function rowsInCol(count: number, col: number): number {
  const rem = count % ROWS
  if (col < columnsIn(count) - 1) return ROWS
  return rem === 0 ? ROWS : rem
}

