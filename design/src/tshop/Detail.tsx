import { useEffect, useRef, type CSSProperties, type KeyboardEvent } from 'react'

import { DETAIL_ART, libraryCount, type Entry } from './catalog.ts'
import { Legend, Pad, Screen, TopBar, type Canvas, type Mode } from './Chrome.tsx'
import { PrimaryAction } from './PrimaryAction.tsx'

export type DetailProps = {
  entry: Entry
  canvas?: Canvas
  mode?: Mode
  online?: boolean
  onBack?: () => void
}

/** Where tShop spends screen space on artwork. Scrolls vertically; this is the first fold. */
export function Detail({ entry, canvas = 'thor', mode = 'day', online = true, onBack }: DetailProps) {
  const art = DETAIL_ART[entry.id]
  const rootRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    rootRef.current?.focus({ preventScroll: true })
  }, [])

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key === 'Escape' || event.key === 'Backspace') {
      event.preventDefault()
      onBack?.()
    }
  }

  return (
    <Screen canvas={canvas} mode={mode} onKeyDown={onKeyDown} rootRef={rootRef}>
      <TopBar destination="browse" libraryCount={libraryCount()} online={online} />
      <article className="ts-detail">
        <div className="ts-detail__banner" aria-hidden="true">
          {art ? <img src={art.feature} alt="" /> : <Wash entry={entry} />}
        </div>
        <div className="ts-detail__head">
          <span className="ts-tile" style={tileStyle(entry)}>
            <span className="ts-tile__clip">
              <img className="ts-tile__art" src={entry.icon} alt="" />
            </span>
          </span>
          <div className="ts-detail__title">
            <h1 className="ts-detail__name">{entry.name}</h1>
            <div className="ts-detail__meta">
              <span>{entry.publisher}</span>
              <span className="ts-detail__dot">•</span>
              <span>{entry.category}</span>
              <span className="ts-detail__dot">•</span>
              <span>v{entry.version}</span>
            </div>
          </div>
          <div className="ts-detail__actions">
            <PrimaryAction entry={entry} online={online} />
          </div>
        </div>
        <div className="ts-shots">
          {art
            ? art.shots.map((shot) => (
                <button type="button" className="ts-shot" key={shot} tabIndex={-1}>
                  <img src={shot} alt="" />
                </button>
              ))
            : [0, 1, 2, 3].map((n) => (
                <span className="ts-shot ts-shot--empty" key={n}>
                  Screenshot
                </span>
              ))}
        </div>
        <div className="ts-cards">
          <section className="ts-card">
            <h3>About</h3>
            <p className="ts-card__lead">{entry.summary}</p>
            {(art?.description ?? []).map((paragraph) => (
              <p key={paragraph}>{paragraph}</p>
            ))}
          </section>
          <section className="ts-card">
            <h3>New in {entry.version}</h3>
            {art ? (
              <ul>
                {art.changelog.map((line) => (
                  <li key={line}>{line}</li>
                ))}
              </ul>
            ) : (
              <p>Release notes from upstream.</p>
            )}
          </section>
          <section className="ts-card">
            <h3>Details</h3>
            <dl className="ts-facts">
              <dt>Released</dt>
              <dd>{entry.released}</dd>
              <dt>Size</dt>
              <dd>{entry.size}</dd>
              {entry.installedVersion ? (
                <>
                  <dt>Installed</dt>
                  <dd>{entry.installedVersion}</dd>
                </>
              ) : null}
              <dt>Needs</dt>
              <dd>{entry.unmet?.length ? `✕ ${entry.unmet.join(', ')}` : '✓ Nothing special'}</dd>
            </dl>
          </section>
        </div>
      </article>
      <Legend
        left={[
          { button: 'A', label: 'Select' },
          { button: 'dpad', label: 'Screenshots' },
          { button: 'X', label: 'Upstream page' },
        ]}
        right={[{ button: 'B', label: 'Back' }]}
        middle={entry.status === 'installed' ? <UninstallHint /> : null}
      />
    </Screen>
  )
}

function Wash({ entry }: { entry: Entry }) {
  return (
    <span className="ts-detail__wash" style={{ background: entry.backdrop }}>
      <img src={entry.icon} alt="" />
    </span>
  )
}

function UninstallHint() {
  return (
    <span className="ts-legend__item">
      <Pad button="+" /> Uninstall
    </span>
  )
}

function tileStyle(entry: Entry): CSSProperties {
  return { '--ts-tile-bg': entry.backdrop, '--ts-tile-scale': entry.scale } as CSSProperties
}
