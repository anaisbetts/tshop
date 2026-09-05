import { AppTile } from './AppTile.tsx'
import type { CatalogEntry } from './catalog.ts'

export function CategoryFrame({
  label,
  entries,
  focusedId,
  onFocus,
  onOpen,
}: {
  label: string
  entries: CatalogEntry[]
  focusedId?: string | null
  onFocus?: (id: string) => void
  onOpen?: (id: string) => void
}) {
  return (
    <section className="tshop-frame" aria-label={label}>
      <div className="tshop-frame__label">{label}</div>
      <div className="tshop-frame__grid">
        {entries.map((entry) => (
          <AppTile
            key={entry.id}
            entry={entry}
            focused={entry.id === focusedId}
            onFocus={onFocus ? () => onFocus(entry.id) : undefined}
            onOpen={onOpen ? () => onOpen(entry.id) : undefined}
          />
        ))}
      </div>
    </section>
  )
}
