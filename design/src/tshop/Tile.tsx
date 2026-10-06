import type { CSSProperties } from 'react'

import type { Entry } from './catalog.ts'

const MARK_PATHS: Record<MarkKind, string> = {
  installed: 'M2.5 6.4 5 8.8l4.6-5.3',
  foreign: 'M2.5 6.4 5 8.8l4.6-5.3',
  update: 'M6 10V2.5M2.8 5.6 6 2.4l3.2 3.2',
  failed: 'M6 2.4v4.4M6 9.6v.01',
}

export type TileContext = 'browse' | 'library'

type MarkKind = 'installed' | 'foreign' | 'update' | 'failed'

export function Tile({
  entry,
  focused,
  context = 'browse',
  onFocus,
  onOpen,
}: {
  entry: Entry
  focused?: boolean
  context?: TileContext
  onFocus?: () => void
  onOpen?: () => void
}) {
  const dim = Boolean(entry.unmet?.length) || (context === 'library' && entry.status === 'other-source')
  const busy = entry.status === 'downloading' || entry.status === 'confirm'
  const className = ['ts-tile', focused && 'is-focused', dim && 'is-dim', busy && 'is-busy'].filter(Boolean).join(' ')
  const style = { '--ts-tile-bg': entry.backdrop, '--ts-tile-scale': entry.scale } as CSSProperties

  return (
    <button
      type="button"
      className={className}
      style={style}
      data-entry-id={entry.id}
      aria-label={entry.name}
      aria-current={focused || undefined}
      tabIndex={-1}
      onMouseEnter={onFocus}
      onClick={() => {
        onFocus?.()
        onOpen?.()
      }}
    >
      <span className="ts-tile__clip">
        <img className="ts-tile__art" src={entry.icon} alt="" draggable={false} />
      </span>
      <TileMark entry={entry} context={context} />
    </button>
  )
}

function TileMark({ entry, context }: { entry: Entry; context: TileContext }) {
  switch (entry.status) {
    case 'available':
      return null
    case 'installed':
      return context === 'library' ? null : <Mark kind="installed" />
    case 'update':
      return <Mark kind="update" />
    case 'downloading':
      return <Progress value={entry.progress ?? 0} />
    case 'confirm':
      return <Progress value={1} done />
    case 'failed':
      return <Mark kind="failed" />
    case 'other-source':
      return context === 'library' ? null : <Mark kind="foreign" />
    default: {
      const never: never = entry.status
      return never
    }
  }
}

function Mark({ kind }: { kind: MarkKind }) {
  return (
    <span className={`ts-tile__mark ts-tile__mark--${kind}`} aria-hidden="true">
      <svg viewBox="0 0 12 12" width="12" height="12">
        <path d={MARK_PATHS[kind]} fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </span>
  )
}

function Progress({ value, done }: { value: number; done?: boolean }) {
  return (
    <span className={`ts-tile__progress${done ? ' ts-tile__progress--done' : ''}`} aria-hidden="true">
      <span style={{ width: `${Math.round(Math.min(1, Math.max(0, value)) * 100)}%` }} />
    </span>
  )
}
