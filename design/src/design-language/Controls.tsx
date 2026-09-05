import { useState } from 'react'

export type PrimaryAction = 'install' | 'update' | 'open' | 'retry' | 'other-source'

export function PrimaryButton({
  action,
  progress,
}: {
  action: PrimaryAction
  progress?: number
}) {
  if (progress !== undefined) {
    const pct = Math.round(progress * 100)
    return (
      <button className="tshop-btn tshop-btn--progress" type="button" disabled>
        <span className="tshop-btn__bar" style={{ width: `${pct}%` }} />
        <span className="tshop-btn__label">Downloading {pct}%</span>
      </button>
    )
  }

  return (
    <button className={['tshop-btn', toneClass(action)].join(' ')} type="button">
      {actionLabel(action)}
    </button>
  )
}

export function Toggle({
  label = 'Do not send any anonymized information to the shop.',
  checked: checkedProp,
  onChange,
}: {
  label?: string
  checked?: boolean
  onChange?: (next: boolean) => void
}) {
  const [internal, setInternal] = useState(false)
  const checked = checkedProp ?? internal

  return (
    <label className="tshop-toggle">
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => {
          onChange?.(event.target.checked)
          if (checkedProp === undefined) setInternal(event.target.checked)
        }}
      />
      <span className="tshop-toggle__track" />
      <span>{label}</span>
    </label>
  )
}

function actionLabel(action: PrimaryAction): string {
  switch (action) {
    case 'install':
      return 'Install'
    case 'update':
      return 'Update'
    case 'open':
      return 'Open'
    case 'retry':
      return 'Retry'
    case 'other-source':
      return 'Installed from another source'
    default: {
      const _never: never = action
      return _never
    }
  }
}

function toneClass(action: PrimaryAction): string {
  switch (action) {
    case 'install':
    case 'open':
      return ''
    case 'update':
      return 'tshop-btn--update'
    case 'retry':
      return 'tshop-btn--retry'
    case 'other-source':
      return 'tshop-btn--other-source'
    default: {
      const _never: never = action
      return _never
    }
  }
}
