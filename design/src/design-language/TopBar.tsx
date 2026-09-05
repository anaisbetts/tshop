import { Glyph, WifiIcon, type WifiState } from './Glyph.tsx'

export const DESTINATIONS = ['browse', 'library', 'settings'] as const

export type Destination = (typeof DESTINATIONS)[number]

export function TopBar({
  destination,
  title,
  opened,
  online,
  libraryCount,
  onDestination,
  onToggleOnline,
}: {
  destination: Destination
  title: string
  opened?: boolean
  online: boolean
  libraryCount?: number
  onDestination: (next: Destination) => void
  onToggleOnline?: () => void
}) {
  const wifi: WifiState = online ? 'online' : 'offline'

  return (
    <header className="tshop-topbar">
      <div className="tshop-topbar__side">
        <Glyph name="L" />
        <nav className="tshop-topbar__tabs" aria-label="Destinations">
          {DESTINATIONS.map((item) => (
            <button
              key={item}
              type="button"
              className={['tshop-tab', item === destination ? 'is-active' : ''].filter(Boolean).join(' ')}
              onClick={() => onDestination(item)}
            >
              {tabLabel(item)}
              {item === 'library' && libraryCount ? (
                <span className="tshop-tab__count">{libraryCount}</span>
              ) : null}
            </button>
          ))}
        </nav>
      </div>
      <div className={['tshop-title-pill', opened ? 'is-open' : ''].filter(Boolean).join(' ')}>
        {title}
      </div>
      <div className="tshop-topbar__side tshop-topbar__side--end">
        <Glyph name="R" />
        <div className="tshop-status">
          <button type="button" onClick={onToggleOnline} aria-label={online ? 'Online' : 'Offline'}>
            <WifiIcon state={wifi} />
          </button>
          <span>12:00 PM</span>
          <BatteryIcon />
        </div>
      </div>
    </header>
  )
}

function tabLabel(destination: Destination): string {
  switch (destination) {
    case 'browse':
      return 'Browse'
    case 'library':
      return 'Library'
    case 'settings':
      return 'Settings'
    default: {
      const _never: never = destination
      return _never
    }
  }
}

function BatteryIcon() {
  return (
    <svg className="tshop-battery" viewBox="0 0 22 12" aria-hidden="true">
      <rect x="0.5" y="1.5" width="18" height="9" rx="2" fill="none" stroke="currentColor" />
      <rect x="19" y="4" width="2" height="4" rx="0.5" fill="currentColor" />
      <rect x="2.5" y="3.5" width="12" height="5" rx="1" fill="currentColor" />
    </svg>
  )
}
