import type { Entry } from './catalog.ts'
import { Pad } from './Chrome.tsx'

type Action =
  | { kind: 'install' }
  | { kind: 'update' }
  | { kind: 'open' }
  | { kind: 'progress'; value: number; label: string }
  | { kind: 'retry' }
  | { kind: 'other-source' }
  | { kind: 'publisher' }
  | { kind: 'offline' }

/** Detail shows exactly one of these. The explainer line carries anything the label can't. */
export function PrimaryAction({ entry, online = true, focused = true }: { entry: Entry; online?: boolean; focused?: boolean }) {
  const action = actionFor(entry, online)
  const explainer = explainerFor(action, entry)
  return (
    <>
      <ActionButton action={action} entry={entry} focused={focused} />
      {explainer ? <p className="ts-explain">{explainer}</p> : null}
    </>
  )
}

function ActionButton({ action, entry, focused }: { action: Action; entry: Entry; focused: boolean }) {
  const focus = focused ? ' is-focused' : ''

  switch (action.kind) {
    case 'install':
      return (
        <button type="button" className={`ts-btn${focus}`}>
          <Pad button="A" /> Install <span className="ts-btn__sub">{entry.size}</span>
        </button>
      )
    case 'update':
      return (
        <button type="button" className={`ts-btn${focus}`}>
          <Pad button="A" /> Update <span className="ts-btn__sub">to {entry.version}</span>
        </button>
      )
    case 'open':
      return (
        <button type="button" className={`ts-btn ts-btn--open${focus}`}>
          <Pad button="A" /> Open
        </button>
      )
    case 'progress':
      return (
        <button type="button" className={`ts-btn ts-btn--progress${focus}`} aria-disabled="true">
          <span className="ts-btn__fill" style={{ width: `${Math.round(action.value * 100)}%` }} />
          <span className="ts-btn__label">{action.label}</span>
        </button>
      )
    case 'retry':
      return (
        <button type="button" className={`ts-btn ts-btn--retry${focus}`}>
          <Pad button="A" /> Retry
        </button>
      )
    case 'other-source':
      return (
        <button type="button" className={`ts-btn ts-btn--quiet${focus}`}>
          <Pad button="A" /> Installed from another source
        </button>
      )
    case 'publisher':
      return (
        <button type="button" className={`ts-btn${focus}`}>
          <Pad button="A" /> Go to Publisher
        </button>
      )
    case 'offline':
      return (
        <button type="button" className={`ts-btn ts-btn--disabled${focus}`} aria-disabled="true">
          <Pad button="A" /> Install when online
        </button>
      )
    default: {
      const never: never = action
      return never
    }
  }
}

function explainerFor(action: Action, entry: Entry): string | null {
  switch (action.kind) {
    case 'install':
      return entry.unmet?.length ? `Needs ${entry.unmet.join(', ')}. This device doesn’t report it.` : null
    case 'open':
    case 'progress':
      return null
    case 'update':
      return `Installed ${entry.installedVersion}`
    case 'retry':
      return entry.failure ?? null
    case 'other-source':
      return 'Signed by someone else (likely Play Store). Uninstall it so tShop can manage updates.'
    case 'publisher':
      return entry.landingPage ?? null
    case 'offline':
      return 'You’re offline. Browsing still works from the saved catalog.'
    default: {
      const never: never = action
      return never
    }
  }
}

function actionFor(entry: Entry, online: boolean): Action {
  if (entry.landingPage) return { kind: 'publisher' }
  switch (entry.status) {
    case 'available':
      return online ? { kind: 'install' } : { kind: 'offline' }
    case 'installed':
      return { kind: 'open' }
    case 'update':
      return online ? { kind: 'update' } : { kind: 'offline' }
    case 'downloading':
      return { kind: 'progress', value: entry.progress ?? 0, label: `Downloading ${Math.round((entry.progress ?? 0) * 100)}%` }
    case 'confirm':
      return { kind: 'progress', value: 1, label: 'Ready · confirm in Library' }
    case 'failed':
      return { kind: 'retry' }
    case 'other-source':
      return { kind: 'other-source' }
    default: {
      const never: never = entry.status
      return never
    }
  }
}
