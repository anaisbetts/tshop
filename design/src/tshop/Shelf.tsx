import { useEffect, useRef, type ReactNode } from 'react'

import type { Entry } from './catalog.ts'
import type { Focus, Frame } from './nav.ts'
import { Tile, type TileContext } from './Tile.tsx'

/** Horizontal strip of framed groups. Column-major so a frame grows sideways, like a 3DS page. */
export function Shelf({
  frames,
  focus,
  context,
  onFocus,
  onOpen,
  empty,
}: {
  frames: Frame[]
  focus: Focus
  context: TileContext
  onFocus: (focus: Focus) => void
  onOpen?: (entry: Entry) => void
  /** Shown in a frame of ghost slots when there are no frames at all. */
  empty?: ReactNode
}) {
  const stripRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!focus) return
    stripRef.current
      ?.querySelector<HTMLElement>(`[data-entry-id="${focus}"]`)
      ?.scrollIntoView({ inline: 'nearest', block: 'nearest', behavior: 'smooth' })
  }, [focus])

  return (
    <div className="ts-strip" ref={stripRef}>
      {frames.length === 0 && empty ? <EmptyFrame>{empty}</EmptyFrame> : null}
      {frames.map((frame) => (
        <section className="ts-frame" key={frame.id}>
          <div className="ts-frame__head">
            <h2 className="ts-frame__label">{frame.label}</h2>
            <span className="ts-frame__count">{frame.entries.length}</span>
          </div>
          <div className="ts-frame__grid">
            {frame.lead ? (
              <span data-entry-id={frame.lead.id} onMouseEnter={() => onFocus(frame.lead?.id ?? null)}>
                {frame.lead.render(focus === frame.lead.id)}
              </span>
            ) : null}
            {frame.entries.map((entry) => (
              <Tile
                key={entry.id}
                entry={entry}
                context={context}
                focused={focus === entry.id}
                onFocus={() => onFocus(entry.id)}
                onOpen={() => onOpen?.(entry)}
              />
            ))}
          </div>
        </section>
      ))}
    </div>
  )
}

function EmptyFrame({ children }: { children: ReactNode }) {
  return (
    <section className="ts-frame ts-frame--empty">
      <div className="ts-frame__grid" aria-hidden="true">
        {Array.from({ length: 40 }, (_, n) => (
          <span className="ts-ghost" key={n} />
        ))}
      </div>
      <div className="ts-empty">{children}</div>
    </section>
  )
}
