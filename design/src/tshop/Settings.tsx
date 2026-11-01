import { useContext, useEffect, useRef, useState, type KeyboardEvent } from 'react'

import { libraryCount } from './catalog.ts'
import { Legend, PadDiamond, Screen, TopBar, type Canvas, type Mode } from './Chrome.tsx'
import { PadLayoutContext, type PadLayout } from './nav.ts'

const ROWS = ['notifications', 'privacy', 'layout', 'check', 'catalog', 'about'] as const

type Row = (typeof ROWS)[number]

export type SettingsProps = {
  canvas?: Canvas
  mode?: Mode
  online?: boolean
  initialFocus?: Row
  privacy?: boolean
  notifications?: boolean
  padLayout?: PadLayout
  onSwitch?: (step: number) => void
  onAbout?: () => void
  onPadLayout?: (layout: PadLayout) => void
}

export function Settings({
  canvas = 'thor',
  mode = 'day',
  online = true,
  initialFocus = 'privacy',
  privacy: initialPrivacy = false,
  notifications: initialNotifications = true,
  padLayout,
  onSwitch,
  onAbout,
  onPadLayout,
}: SettingsProps) {
  const contextPad = useContext(PadLayoutContext)
  const [focus, setFocus] = useState<Row>(initialFocus)
  const [notifications, setNotifications] = useState(initialNotifications)
  const [privacy, setPrivacy] = useState(initialPrivacy)
  const [layout, setLayout] = useState<PadLayout>(padLayout ?? contextPad)
  const rootRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    rootRef.current?.focus({ preventScroll: true })
  }, [])

  function toggleLayout() {
    const next = layout === 'nintendo' ? 'xbox' : 'nintendo'
    setLayout(next)
    onPadLayout?.(next)
  }

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    const index = ROWS.indexOf(focus)
    switch (event.key) {
      case 'ArrowUp':
        setFocus(ROWS[Math.max(0, index - 1)])
        break
      case 'ArrowDown':
        setFocus(ROWS[Math.min(ROWS.length - 1, index + 1)])
        break
      case 'Enter':
        if (focus === 'notifications') setNotifications((value) => !value)
        if (focus === 'privacy') setPrivacy((value) => !value)
        if (focus === 'layout') toggleLayout()
        if (focus === 'about') onAbout?.()
        break
      case '[':
        onSwitch?.(-1)
        break
      case ']':
        onSwitch?.(1)
        break
      default:
        return
    }
    event.preventDefault()
  }

  const row = (id: Row) => `ts-row${focus === id ? ' is-focused' : ''}`

  return (
    <Screen canvas={canvas} mode={mode} pad={layout} onKeyDown={onKeyDown} rootRef={rootRef}>
      <TopBar destination="settings" libraryCount={libraryCount()} online={online} />
      <section className="ts-settings">
        <div className={row('notifications')} onMouseEnter={() => setFocus('notifications')}>
          <div>
            <p className="ts-row__title">Update notifications</p>
            <p className="ts-row__desc">One summary when catalog updates are ready.</p>
          </div>
          <span className={`ts-switch${notifications ? ' is-on' : ''}`} role="switch" aria-checked={notifications} />
        </div>
        <div className={row('privacy')} onMouseEnter={() => setFocus('privacy')}>
          <div>
            <p className="ts-row__title">Privacy Mode</p>
            <p className="ts-row__desc">
              Do not send any anonymized information to the shop.
              {privacy ? <span className="ts-row__warn"> Downloads come from each publisher and fail if it is down.</span> : null}
            </p>
          </div>
          <span className={`ts-switch${privacy ? ' is-on' : ''}`} role="switch" aria-checked={privacy} />
        </div>
        <div className={row('layout')} onMouseEnter={() => setFocus('layout')}>
          <div>
            <p className="ts-row__title">Button layout</p>
            <p className="ts-row__desc">{layout === 'nintendo' ? 'Nintendo: A on the right confirms' : 'Xbox: A on the bottom confirms'}</p>
          </div>
          <span className="ts-row__value ts-row__layout">
            <span className={layout === 'nintendo' ? 'is-on' : undefined}>Nintendo</span>
            <PadDiamond layout={layout} />
            <span className={layout === 'xbox' ? 'is-on' : undefined}>Xbox</span>
          </span>
        </div>
        <div className={row('check')} onMouseEnter={() => setFocus('check')}>
          <p className="ts-row__title">Check for updates now</p>
          <span className="ts-row__value">Last checked 9:12</span>
        </div>
        <div className={row('catalog')} onMouseEnter={() => setFocus('catalog')}>
          <p className="ts-row__title">Catalog</p>
          <span className="ts-row__value">Published 6 Oct 2026, 08:00</span>
        </div>
        <div className={row('about')} onMouseEnter={() => setFocus('about')}>
          <div>
            <p className="ts-row__title">About tShop</p>
            <p className="ts-row__desc">What tShop knows about you, licenses, source, public stats</p>
          </div>
          <span className="ts-row__value">›</span>
        </div>
      </section>
      <Legend
        left={[
          { button: 'dpad', label: 'Move' },
          { button: 'A', label: focus === 'about' ? 'Open' : 'Change' },
        ]}
        right={[{ button: 'B', label: 'Back' }]}
      />
    </Screen>
  )
}
