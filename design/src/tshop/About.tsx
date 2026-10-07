import { useEffect, useRef, useState, type KeyboardEvent } from 'react'

import { libraryCount } from './catalog.ts'
import { Legend, Screen, TopBar, type Canvas, type Mode } from './Chrome.tsx'

const ROWS = [
  { id: 'licenses', title: 'Open-source licenses', value: '›' },
  { id: 'source', title: 'Source code', value: 'github.com/anaisbetts/tshop ↗' },
  { id: 'support', title: 'Support', value: 'Opens in your browser ↗' },
  { id: 'stats', title: 'Public stats', value: 'Every number tShop has ↗' },
] as const

type Row = (typeof ROWS)[number]['id']

export type AboutProps = {
  canvas?: Canvas
  mode?: Mode
  online?: boolean
  initialFocus?: Row
  onBack?: () => void
}

/** Settings › About. Quotes the PRD's "What tShop knows about you" and links to the dashboard. */
export function About({ canvas = 'thor', mode = 'day', online = true, initialFocus = 'stats', onBack }: AboutProps) {
  const [focus, setFocus] = useState<Row>(initialFocus)
  const rootRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    rootRef.current?.focus({ preventScroll: true })
  }, [])

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    const index = ROWS.findIndex((row) => row.id === focus)
    switch (event.key) {
      case 'ArrowUp':
        setFocus(ROWS[Math.max(0, index - 1)].id)
        break
      case 'ArrowDown':
        setFocus(ROWS[Math.min(ROWS.length - 1, index + 1)].id)
        break
      case 'Escape':
      case 'Backspace':
        onBack?.()
        break
      default:
        return
    }
    event.preventDefault()
  }

  return (
    <Screen canvas={canvas} mode={mode} onKeyDown={onKeyDown} rootRef={rootRef}>
      <TopBar destination="settings" libraryCount={libraryCount()} online={online} />
      <section className="ts-about">
        <div className="ts-about__side">
          <div className="ts-about__brand">
            <span className="ts-logo ts-logo--big" aria-hidden="true">
              t
            </span>
            <div>
              <p className="ts-row__title">tShop 1.0.0</p>
              <p className="ts-row__desc">Free Software · catalog 6 Oct 2026</p>
            </div>
          </div>
          <div className="ts-settings ts-about__rows">
            {ROWS.map((row) => (
              <div className={`ts-row${focus === row.id ? ' is-focused' : ''}`} key={row.id} onMouseEnter={() => setFocus(row.id)}>
                <p className="ts-row__title">{row.title}</p>
                <span className="ts-row__value">{row.value}</span>
              </div>
            ))}
          </div>
        </div>
        <PolicyCard />
      </section>
      <Legend
        left={[
          { button: 'dpad', label: 'Move' },
          { button: 'A', label: 'Open' },
        ]}
        right={[{ button: 'B', label: 'Back' }]}
      />
    </Screen>
  )
}

/** Shortened from 01-prd.md; the dashboard quotes the same text. */
export function PolicyCard() {
  return (
    <section className="ts-card ts-policy">
      <h3>What tShop knows about you</h3>
      <p className="ts-card__lead">
        tShop counts completed APK downloads. That is the entire analytics system. No account, no device identifier, no
        crash reporter, no SDK phoning home.
      </p>
      <div className="ts-policy__cols">
        <div>
          <p className="ts-policy__head">Kept, per day</p>
          <ul>
            <li>App and version fetched</li>
            <li>APK variant, if there is a choice</li>
            <li>UTC day and a count</li>
          </ul>
        </div>
        <div>
          <p className="ts-policy__head">Never kept</p>
          <ul>
            <li>IP address or user-agent</li>
            <li>Device or advertising IDs</li>
            <li>Your other apps, searches, browsing</li>
            <li>Whether you accepted the install</li>
          </ul>
        </div>
      </div>
      <p>Everyone sees the same public page. Privacy Mode fetches from the publisher instead, so it isn’t counted at all.</p>
    </section>
  )
}
