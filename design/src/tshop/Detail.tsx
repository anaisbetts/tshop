import { useEffect, useRef, useState, type CSSProperties, type KeyboardEvent } from 'react'

import { DETAIL_ART, libraryCount, type Entry, type Variant } from './catalog.ts'
import { Legend, Pad, Screen, TopBar, type Canvas, type Mode } from './Chrome.tsx'
import { PrimaryAction } from './PrimaryAction.tsx'

/** `action` is the one primary button; a number is a screenshot in the strip. */
export type DetailFocus = 'action' | number

export type DetailProps = {
  entry: Entry
  canvas?: Canvas
  mode?: Mode
  online?: boolean
  initialFocus?: DetailFocus
  /** Start with the variant dialog open (only for entries whose catalog marks variants as a choice). */
  choosingVariant?: boolean
  onBack?: () => void
  onShot?: (index: number) => void
}

/** Where tShop spends screen space on artwork. Scrolls vertically; this is the first fold. */
export function Detail({
  entry,
  canvas = 'thor',
  mode = 'day',
  online = true,
  initialFocus = 'action',
  choosingVariant = false,
  onBack,
  onShot,
}: DetailProps) {
  const art = DETAIL_ART[entry.id]
  const shotCount = art?.shots.length ?? 0
  const [focus, setFocus] = useState<DetailFocus>(initialFocus)
  const [picking, setPicking] = useState(choosingVariant && Boolean(entry.variants))
  const [variant, setVariant] = useState(0)
  const rootRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    rootRef.current?.focus({ preventScroll: true })
  }, [])

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (picking) {
      onVariantKey(event)
      return
    }
    switch (event.key) {
      case 'Escape':
      case 'Backspace':
        onBack?.()
        break
      case 'ArrowDown':
        if (focus === 'action' && shotCount > 0) setFocus(0)
        break
      case 'ArrowUp':
        setFocus('action')
        break
      case 'ArrowLeft':
        if (typeof focus === 'number') setFocus(Math.max(0, focus - 1))
        break
      case 'ArrowRight':
        if (typeof focus === 'number') setFocus(Math.min(shotCount - 1, focus + 1))
        break
      case 'Enter':
        if (typeof focus === 'number') onShot?.(focus)
        else if (entry.variants && entry.status === 'available' && online) setPicking(true)
        break
      default:
        return
    }
    event.preventDefault()
  }

  function onVariantKey(event: KeyboardEvent<HTMLDivElement>) {
    const count = entry.variants?.length ?? 0
    switch (event.key) {
      case 'ArrowUp':
        setVariant((value) => Math.max(0, value - 1))
        break
      case 'ArrowDown':
        setVariant((value) => Math.min(count - 1, value + 1))
        break
      case 'Enter':
      case 'Escape':
      case 'Backspace':
        setPicking(false)
        break
      default:
        return
    }
    event.preventDefault()
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
              {entry.landingPage ? null : (
                <>
                  <span className="ts-detail__dot">•</span>
                  <span>v{entry.version}</span>
                </>
              )}
            </div>
          </div>
          <div className="ts-detail__actions">
            <PrimaryAction entry={entry} online={online} focused={focus === 'action' && !picking} />
          </div>
        </div>
        <div className="ts-shots">
          {art
            ? art.shots.map((shot, index) => (
                <button
                  type="button"
                  className={`ts-shot${focus === index ? ' is-focused' : ''}`}
                  key={shot}
                  tabIndex={-1}
                  onMouseEnter={() => setFocus(index)}
                  onClick={() => onShot?.(index)}
                >
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
            <h3>{entry.landingPage ? 'Release notes' : `New in ${entry.version}`}</h3>
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
              <dd>{entry.landingPage ? 'From the publisher' : entry.size}</dd>
              {entry.installedVersion ? (
                <>
                  <dt>Installed</dt>
                  <dd>{entry.installedVersion}</dd>
                </>
              ) : null}
              <dt>Needs</dt>
              <dd>
                {entry.unmet?.length
                  ? entry.unmet.map((need) => (
                      <span className="ts-need ts-need--unmet" key={need}>
                        ✕ {need}
                      </span>
                    ))
                  : '✓ Nothing special'}
              </dd>
            </dl>
          </section>
        </div>
      </article>
      <Legend
        left={[
          { button: 'A', label: typeof focus === 'number' ? 'View' : 'Select' },
          { button: 'dpad', label: 'Screenshots' },
          { button: 'X', label: 'Upstream page' },
        ]}
        right={[{ button: 'B', label: 'Back' }]}
        middle={entry.status === 'installed' ? <UninstallHint /> : null}
      />
      {picking && entry.variants ? <VariantDialog entry={entry} variants={entry.variants} selected={variant} /> : null}
    </Screen>
  )
}

/** Only when the catalog marks variants as a genuine choice. Otherwise the client picks by ABI and SDK. */
function VariantDialog({ entry, variants, selected }: { entry: Entry; variants: Variant[]; selected: number }) {
  return (
    <div className="ts-dialog" role="dialog" aria-label={`Choose a ${entry.name} build`}>
      <div className="ts-dialog__card">
        <p className="ts-dialog__kicker">Install {entry.name}</p>
        <h2 className="ts-dialog__title">Which build?</h2>
        <div className="ts-dialog__rows">
          {variants.map((variant, index) => (
            <div className={`ts-row${index === selected ? ' is-focused' : ''}`} key={variant.label}>
              <div>
                <p className="ts-row__title">{variant.label}</p>
                <p className="ts-row__desc">{variant.note}</p>
              </div>
              <span className="ts-row__value">{variant.size}</span>
            </div>
          ))}
        </div>
        <Legend left={[{ button: 'A', label: 'Install' }]} right={[{ button: 'B', label: 'Cancel' }]} />
      </div>
    </div>
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
