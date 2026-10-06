import type { Entry } from './catalog.ts'
import type { TileContext } from './Tile.tsx'

type Tone = 'plain' | 'good' | 'accent' | 'bad'

/** The 3DS top-screen idea folded into one line: name, why it matters, its state. */
export function InfoStrip({
  entry,
  context,
  fallbackTitle,
  fallbackSummary,
}: {
  entry: Entry | null
  context: TileContext
  fallbackTitle: string
  fallbackSummary: string
}) {
  if (!entry) {
    return (
      <div className="ts-info">
        <h1 className="ts-info__name">{fallbackTitle}</h1>
        <p className="ts-info__summary">{fallbackSummary}</p>
      </div>
    )
  }
  const status = statusChip(entry, context)
  return (
    <div className="ts-info">
      <h1 className="ts-info__name">{entry.name}</h1>
      <p className="ts-info__summary">{infoLine(entry)}</p>
      <div className="ts-info__meta">
        <span className="ts-chip">{entry.category}</span>
        {status ? <Chip tone={status.tone}>{status.label}</Chip> : null}
      </div>
    </div>
  )
}

function Chip({ tone = 'plain', children }: { tone?: Tone; children: string }) {
  return <span className={`ts-chip${tone === 'plain' ? '' : ` ts-chip--${tone}`}`}>{children}</span>
}

function statusChip(entry: Entry, context: TileContext): { tone: Tone; label: string } | null {
  if (entry.unmet?.length) return { tone: 'bad', label: `Needs ${entry.unmet.join(', ')}` }
  if (entry.landingPage) return { tone: 'plain', label: 'From the publisher' }
  switch (entry.status) {
    case 'available':
      return { tone: 'plain', label: entry.size }
    case 'installed':
      return { tone: 'good', label: 'Installed' }
    case 'update':
      return { tone: 'accent', label: `Update ${entry.installedVersion} → ${entry.version}` }
    case 'downloading':
      return { tone: 'accent', label: `Downloading ${Math.round((entry.progress ?? 0) * 100)}%` }
    case 'confirm':
      return context === 'library'
        ? { tone: 'good', label: 'Confirm with Android' }
        : { tone: 'good', label: 'Downloaded · confirm in Library' }
    case 'failed':
      return { tone: 'bad', label: 'Download failed' }
    case 'other-source':
      return { tone: 'plain', label: 'Installed from another source' }
    default: {
      const never: never = entry.status
      return never
    }
  }
}

function infoLine(entry: Entry): string {
  if (entry.status === 'failed' && entry.failure) return entry.failure
  return entry.summary
}
