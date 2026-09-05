import type { CatalogEntry, TileState } from './catalog.ts'

const ARC_R = 18
const ARC_C = 2 * Math.PI * ARC_R

export function AppTile({
  entry,
  focused,
  onFocus,
  onOpen,
}: {
  entry: CatalogEntry
  focused?: boolean
  onFocus?: () => void
  onOpen?: () => void
}) {
  return (
    <button
      type="button"
      className={['tshop-tile', focused ? 'is-focused' : '', entry.state === 'greyed' ? 'is-greyed' : '']
        .filter(Boolean)
        .join(' ')}
      data-entry-id={entry.id}
      aria-label={entry.name}
      aria-current={focused || undefined}
      tabIndex={-1}
      onMouseEnter={onFocus}
      onFocus={onFocus}
      onClick={() => {
        onFocus?.()
        onOpen?.()
      }}
    >
      <img className="tshop-tile__art" src={entry.icon} alt="" draggable={false} />
      <TileChrome state={entry.state} progress={entry.progress} />
    </button>
  )
}

function TileChrome({ state, progress }: { state: TileState; progress?: number }) {
  switch (state) {
    case 'installed':
      return (
        <span className="tshop-tile__mark" aria-hidden="true">
          ✓
        </span>
      )
    case 'update':
      return (
        <span className="tshop-tile__badge" aria-hidden="true">
          ↑
        </span>
      )
    case 'downloading':
      return <ProgressArc value={progress ?? 0} />
    case 'greyed':
    case 'none':
      return null
    default: {
      const _never: never = state
      return _never
    }
  }
}

function ProgressArc({ value }: { value: number }) {
  const offset = ARC_C * (1 - Math.min(1, Math.max(0, value)))
  return (
    <svg className="tshop-tile__progress" viewBox="0 0 44 44" aria-hidden="true">
      <circle className="track" cx="22" cy="22" r={ARC_R} />
      <circle
        className="value"
        cx="22"
        cy="22"
        r={ARC_R}
        strokeDasharray={ARC_C}
        strokeDashoffset={offset}
      />
    </svg>
  )
}
