import { useRef, useState, type ReactNode } from 'react'

import type { Entry } from './catalog.ts'

export const DESTINATIONS = ['browse', 'library', 'settings'] as const

export type Destination = (typeof DESTINATIONS)[number]

export type Frame = {
  id: string
  label: string
  entries: Entry[]
  /** A square action cell ahead of the tiles (Library's Update All). Navigates like a tile. */
  lead?: { id: string; render: (focused: boolean) => ReactNode }
}

/** Id of the focused cell: an entry id or a frame's lead id. */
export type Focus = string | null

export type Dir = 'left' | 'right' | 'up' | 'down'

type Cursor = { frame: number; col: number; row: number }

export function useShelfFocus(frames: Frame[], rows: number, initial?: Focus) {
  const [focus, setFocus] = useState<Focus>(initial === undefined ? firstCell(frames) : initial)
  const memory = useRef({ row: 0 })

  const visible = focus && cursorOf(frames, focus, rows) ? focus : firstCell(frames)

  function move(dir: Dir) {
    setFocus(moveFocus(frames, visible, dir, rows, memory.current))
  }

  function pick(next: Focus) {
    const cursor = next ? cursorOf(frames, next, rows) : null
    if (cursor) memory.current.row = cursor.row
    setFocus(next)
  }

  return { focus: visible, move, pick }
}

/**
 * Neighbour-graph movement over column-major frames, with row memory: crossing
 * into the next frame keeps the row you were on even if a short column clamped it.
 */
export function moveFocus(frames: Frame[], focus: Focus, dir: Dir, rows: number, memory: { row: number }): Focus {
  if (frames.length === 0) return null
  const cursor = focus ? cursorOf(frames, focus, rows) : null
  if (!cursor) return firstCell(frames)
  const frame = frames[cursor.frame]

  switch (dir) {
    case 'up':
      if (cursor.row === 0) return focus
      memory.row = cursor.row - 1
      return cellAt(frames, { ...cursor, row: cursor.row - 1 }, rows)
    case 'down':
      if (cursor.row + 1 >= rowsInCol(frame, cursor.col, rows)) return focus
      memory.row = cursor.row + 1
      return cellAt(frames, { ...cursor, row: cursor.row + 1 }, rows)
    case 'left':
      if (cursor.col > 0) return cellAt(frames, { ...cursor, col: cursor.col - 1, row: memory.row }, rows)
      if (cursor.frame === 0) return focus
      return cellAt(
        frames,
        { frame: cursor.frame - 1, col: lastCol(frames[cursor.frame - 1], rows), row: memory.row },
        rows,
      )
    case 'right':
      if (cursor.col < lastCol(frame, rows)) return cellAt(frames, { ...cursor, col: cursor.col + 1, row: memory.row }, rows)
      if (cursor.frame === frames.length - 1) return focus
      return cellAt(frames, { frame: cursor.frame + 1, col: 0, row: memory.row }, rows)
    default: {
      const never: never = dir
      return never
    }
  }
}

export function keyDir(key: string): Dir | null {
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

function firstCell(frames: Frame[]): Focus {
  return frames[0] ? (cellIds(frames[0])[0] ?? null) : null
}

function cellIds(frame: Frame): string[] {
  return [...(frame.lead ? [frame.lead.id] : []), ...frame.entries.map((entry) => entry.id)]
}

function cellAt(frames: Frame[], cursor: Cursor, rows: number): Focus {
  const frame = frames[cursor.frame]
  const col = Math.min(cursor.col, lastCol(frame, rows))
  const row = Math.min(cursor.row, rowsInCol(frame, col, rows) - 1)
  return cellIds(frame)[col * rows + row] ?? null
}

function cursorOf(frames: Frame[], id: string, rows: number): Cursor | null {
  for (let frame = 0; frame < frames.length; frame += 1) {
    const index = cellIds(frames[frame]).indexOf(id)
    if (index !== -1) return { frame, col: Math.floor(index / rows), row: index % rows }
  }
  return null
}

function lastCol(frame: Frame, rows: number): number {
  return Math.max(0, Math.ceil(cellIds(frame).length / rows) - 1)
}

function rowsInCol(frame: Frame, col: number, rows: number): number {
  const remainder = cellIds(frame).length - col * rows
  return Math.max(1, Math.min(rows, remainder))
}
