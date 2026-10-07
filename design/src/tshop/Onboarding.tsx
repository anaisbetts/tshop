import { useEffect, useRef, useState, type CSSProperties, type KeyboardEvent, type ReactNode } from 'react'

import { byId } from './catalog.ts'
import { Legend, Pad, Screen, StatusCluster, type Canvas, type Mode } from './Chrome.tsx'

const STEPS = ['welcome', 'install', 'notifications'] as const

const WELCOME_TILES = ['retroarch', 'dolphin', 'ppsspp', 'pixel-dungeon', 'mindustry', 'melonds', 'syncthing', 'moonlight', 'unciv'].map(byId)

export type OnboardingStep = (typeof STEPS)[number]

export type Permission = 'install' | 'notifications'

export type OnboardingProps = {
  canvas?: Canvas
  mode?: Mode
  online?: boolean
  step?: OnboardingStep
  /** Permissions Android already reports as granted. */
  granted?: Permission[]
  /** Re-shown later for one revoked permission, right before tShop needs it. */
  revoked?: { permission: Permission; forApp: string }
  onFinish?: () => void
}

/** First launch only: what tShop is, then the two permissions the store can't work without. */
export function Onboarding({ canvas = 'thor', mode = 'day', online = true, step = 'welcome', granted = [], revoked, onFinish }: OnboardingProps) {
  const [current, setCurrent] = useState<OnboardingStep>(revoked ? revoked.permission : step)
  const [allowed, setAllowed] = useState<Permission[]>(granted)
  const rootRef = useRef<HTMLDivElement>(null)
  const index = STEPS.indexOf(current)
  const permission = current === 'welcome' ? null : current
  const done = permission ? allowed.includes(permission) : true
  const last = revoked ? true : index === STEPS.length - 1

  useEffect(() => {
    rootRef.current?.focus({ preventScroll: true })
  }, [])

  function confirm() {
    if (!done && permission) {
      setAllowed((list) => [...list, permission])
      return
    }
    if (last) onFinish?.()
    else setCurrent(STEPS[index + 1])
  }

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    switch (event.key) {
      case 'Enter':
        confirm()
        break
      case 'Escape':
      case 'Backspace':
        if (revoked) onFinish?.()
        else if (index > 0) setCurrent(STEPS[index - 1])
        break
      default:
        return
    }
    event.preventDefault()
  }

  return (
    <Screen canvas={canvas} mode={mode} onKeyDown={onKeyDown} rootRef={rootRef}>
      <header className="ts-topbar ts-topbar--bare">
        <span className="ts-logo" aria-label="tShop">
          t
        </span>
        <span className="ts-wordmark">tShop</span>
        <span className="ts-topbar__spacer" />
        <StatusCluster online={online} />
      </header>
      <section className="ts-onboard">
        <div className="ts-onboard__art">{permission ? <PermissionTile permission={permission} done={done} /> : <WelcomeTiles />}</div>
        <div className="ts-onboard__card">
          {revoked ? (
            <p className="ts-onboard__kicker">Needed to install {revoked.forApp}</p>
          ) : (
            <p className="ts-onboard__kicker">
              {index + 1} of {STEPS.length}
            </p>
          )}
          <StepCopy step={current} revoked={Boolean(revoked)} />
          <div className="ts-onboard__actions">
            <StepButton permission={permission} done={done} last={last} revoked={Boolean(revoked)} />
            {permission ? <PermissionNote permission={permission} done={done} /> : null}
          </div>
        </div>
      </section>
      <Legend
        left={[{ button: 'A', label: buttonLabel(permission, done, last, Boolean(revoked)) }]}
        middle={revoked ? null : <Dots index={index} />}
        right={revoked ? [{ button: 'B', label: 'Not now' }] : index > 0 ? [{ button: 'B', label: 'Back' }] : []}
      />
    </Screen>
  )
}

function StepCopy({ step, revoked }: { step: OnboardingStep; revoked: boolean }) {
  switch (step) {
    case 'welcome':
      return (
        <Copy title="A shop for your handheld">
          Emulators, frontends, games and utilities, picked and checked by the tShop project. Open a tile, read about it,
          install it. No GitHub releases, no manifests.
        </Copy>
      )
    case 'install':
      return (
        <Copy title={revoked ? 'Install unknown apps was turned off' : 'Let tShop install apps'}>
          Android asks before any store other than Play installs an app. On the next screen, turn on{' '}
          <b>Allow from this source</b> for tShop, then come back.
        </Copy>
      )
    case 'notifications':
      return (
        <Copy title={revoked ? 'Notifications were turned off' : 'Hear about updates'}>
          tShop checks the catalog in the background and sends one notice when updates are ready. Nothing downloads until
          you say so.
        </Copy>
      )
    default: {
      const never: never = step
      return never
    }
  }
}

function StepButton({ permission, done, last, revoked }: { permission: Permission | null; done: boolean; last: boolean; revoked: boolean }) {
  const label = buttonLabel(permission, done, last, revoked)
  return (
    <button type="button" className={`ts-btn is-focused${done && permission ? ' ts-btn--open' : ''}`}>
      <Pad button="A" /> {label}
    </button>
  )
}

function PermissionNote({ permission, done }: { permission: Permission; done: boolean }) {
  if (done) return <span className="ts-chip ts-chip--good">✓ Allowed</span>
  return (
    <p className="ts-explain">
      {permission === 'install' ? 'Opens Android Settings › Install unknown apps' : 'Android shows its own prompt'}
    </p>
  )
}

function WelcomeTiles() {
  return (
    <div className="ts-onboard__tiles" aria-hidden="true">
      {WELCOME_TILES.map((entry, n) => (
        <span
          className={`ts-tile${n === 4 ? ' is-focused' : ''}`}
          key={entry.id}
          style={{ '--ts-tile-bg': entry.backdrop, '--ts-tile-scale': entry.scale } as CSSProperties}
        >
          <span className="ts-tile__clip">
            <img className="ts-tile__art" src={entry.icon} alt="" />
          </span>
        </span>
      ))}
    </div>
  )
}

function PermissionTile({ permission, done }: { permission: Permission; done: boolean }) {
  return (
    <span className="ts-tile ts-action-tile ts-onboard__glyph" aria-hidden="true">
      <svg viewBox="0 0 24 24" width="64" height="64">
        {permission === 'install' ? (
          <path d="M12 3v11M7 9.5l5 5 5-5M5 20h14" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
        ) : (
          <path
            d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinejoin="round"
          />
        )}
      </svg>
      {done ? <span className="ts-tile__mark ts-tile__mark--installed ts-onboard__check">✓</span> : null}
    </span>
  )
}

function Copy({ title, children }: { title: string; children: ReactNode }) {
  return (
    <>
      <h1 className="ts-onboard__title">{title}</h1>
      <p className="ts-onboard__body">{children}</p>
    </>
  )
}

function Dots({ index }: { index: number }) {
  return (
    <span className="ts-viewer__dots ts-onboard__dots" aria-hidden="true">
      {STEPS.map((step, n) => (
        <span key={step} className={n === index ? 'is-on' : undefined} />
      ))}
    </span>
  )
}

function buttonLabel(permission: Permission | null, done: boolean, last: boolean, revoked: boolean): string {
  if (permission && !done) return permission === 'install' ? 'Open Settings' : 'Allow notifications'
  if (revoked) return 'Continue'
  return last ? 'Finish' : 'Next'
}
