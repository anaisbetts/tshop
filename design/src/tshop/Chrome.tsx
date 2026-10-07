import { useContext, type KeyboardEvent, type ReactNode, type Ref } from 'react'

import { DESTINATIONS, PadLayoutContext, type Destination, type PadLayout } from './nav.ts'

/** 3DS-style bitmapped Wi-Fi: 9×7 pixel fan, drawn as rects so it stays crisp. */
const WIFI_PIXELS = [
  '..#####..',
  '.#.....#.',
  '#..###..#',
  '..#...#..',
  '...###...',
  '.........',
  '....#....',
]

/** Face-button positions in the Settings diamond: top, right, bottom, left. */
const DIAMOND: Record<PadLayout, PadButton[]> = {
  nintendo: ['X', 'A', 'B', 'Y'],
  xbox: ['Y', 'B', 'A', 'X'],
}

/** Thor top panel is 837 × 471 dp. Square is a feasibility study for near-1:1 panels. */
export type Canvas = 'thor' | 'square'

export type Mode = 'day' | 'night'

export type PadButton = 'A' | 'B' | 'X' | 'Y' | 'L' | 'R' | '+' | 'dpad'

export type LegendItem = { button: PadButton; label: string }

export function Screen({
  canvas,
  mode,
  pad,
  children,
  onKeyDown,
  rootRef,
}: {
  canvas: Canvas
  mode: Mode
  pad?: PadLayout
  children: ReactNode
  onKeyDown?: (event: KeyboardEvent<HTMLDivElement>) => void
  rootRef?: Ref<HTMLDivElement>
}) {
  const contextPad = useContext(PadLayoutContext)
  return (
    <div
      ref={rootRef}
      className={`ts-root ts-root--${canvas}`}
      data-mode={mode}
      data-pad={pad ?? contextPad}
      tabIndex={0}
      onKeyDown={onKeyDown}
      style={{ ['--ts-rows' as string]: canvas === 'square' ? 4 : 3 }}
    >
      {children}
    </div>
  )
}

export function TopBar({
  destination,
  libraryCount,
  online,
  query,
  showSearch,
  onDestination,
}: {
  destination: Destination
  libraryCount: number
  online: boolean
  query?: string
  showSearch?: boolean
  onDestination?: (next: Destination) => void
}) {
  return (
    <header className="ts-topbar">
      <span className="ts-logo" aria-label="tShop">
        t
      </span>
      <Pad button="L" />
      <nav className="ts-tabs" aria-label="Destinations">
        {DESTINATIONS.map((item) => (
          <button
            key={item}
            type="button"
            className={`ts-tab${item === destination ? ' is-active' : ''}`}
            onClick={() => onDestination?.(item)}
          >
            {destinationLabel(item)}
            {item === 'library' && libraryCount > 0 ? <span className="ts-count">{libraryCount}</span> : null}
          </button>
        ))}
      </nav>
      <Pad button="R" />
      <span className="ts-topbar__spacer" />
      {showSearch ? <SearchPill query={query} /> : null}
      <StatusCluster online={online} />
    </header>
  )
}

/** Wi-Fi, clock, battery. Every screen carries it, including ones without tabs. */
export function StatusCluster({ online }: { online: boolean }) {
  return (
    <div className="ts-status">
      <WifiGlyph online={online} />
      <span>9:41</span>
      <Battery />
    </div>
  )
}

export function PadDiamond({ layout }: { layout: PadLayout }) {
  const [top, right, bottom, left] = DIAMOND[layout]
  return (
    <span className="ts-diamond" data-pad={layout} aria-label={`${layout} layout`}>
      <span className="ts-diamond__top"><Pad button={top} /></span>
      <span className="ts-diamond__right"><Pad button={right} /></span>
      <span className="ts-diamond__bottom"><Pad button={bottom} /></span>
      <span className="ts-diamond__left"><Pad button={left} /></span>
    </span>
  )
}

export function Legend({ left, right, middle }: { left: LegendItem[]; right?: LegendItem[]; middle?: ReactNode }) {
  return (
    <footer className="ts-legend">
      <div className="ts-legend__group">
        {left.map((item) => (
          <LegendHint key={item.label} {...item} />
        ))}
      </div>
      <span className="ts-legend__spacer" />
      {middle}
      <span className="ts-legend__spacer" />
      <div className="ts-legend__group">
        {(right ?? []).map((item) => (
          <LegendHint key={item.label} {...item} />
        ))}
      </div>
    </footer>
  )
}

export function Pad({ button }: { button: PadButton }) {
  switch (button) {
    case 'A':
    case 'B':
    case 'X':
    case 'Y':
      return <span className={`ts-pad ts-pad--face ts-pad--${button.toLowerCase()}`}>{button}</span>
    case 'L':
    case 'R':
    case '+':
      return <span className="ts-pad ts-pad--neutral">{button}</span>
    case 'dpad':
      return (
        <span className="ts-pad ts-pad--dpad" aria-label="D-pad">
          <DpadIcon />
        </span>
      )
    default: {
      const never: never = button
      return never
    }
  }
}

export function WifiGlyph({ online }: { online: boolean }) {
  return (
    <svg className="ts-wifi" viewBox="0 0 9 7" aria-label={online ? 'Online' : 'Offline'}>
      {WIFI_PIXELS.flatMap((row, y) =>
        [...row].map((cell, x) =>
          cell === '#' ? (
            <rect key={`${x}-${y}`} className={online || y >= 6 ? 'on' : 'off'} x={x} y={y} width={1} height={1} />
          ) : null,
        ),
      )}
      {online ? null : (
        <>
          <rect className="x" x={6} y={4} width={1} height={1} />
          <rect className="x" x={8} y={4} width={1} height={1} />
          <rect className="x" x={7} y={5} width={1} height={1} />
          <rect className="x" x={6} y={6} width={1} height={1} />
          <rect className="x" x={8} y={6} width={1} height={1} />
        </>
      )}
    </svg>
  )
}

function destinationLabel(destination: Destination): string {
  switch (destination) {
    case 'browse':
      return 'Browse'
    case 'library':
      return 'Library'
    case 'settings':
      return 'Settings'
    default: {
      const never: never = destination
      return never
    }
  }
}

function SearchPill({ query }: { query?: string }) {
  if (!query) {
    return (
      <span className="ts-search">
        <Pad button="Y" />
        Search
      </span>
    )
  }
  return (
    <span className="ts-search is-active">
      <SearchIcon />
      <span className="ts-search__query">{query}</span>
      <Pad button="X" />
    </span>
  )
}

function LegendHint({ button, label }: LegendItem) {
  return (
    <span className="ts-legend__item">
      <Pad button={button} />
      {label}
    </span>
  )
}

function Battery() {
  return (
    <svg className="ts-battery" viewBox="0 0 22 12" aria-hidden="true">
      <rect x="0.75" y="1.25" width="18" height="9.5" rx="3" fill="none" stroke="currentColor" strokeWidth="1.5" />
      <rect x="19.5" y="4" width="2" height="4" rx="1" fill="currentColor" />
      <rect x="3" y="3.5" width="11" height="5" rx="1.5" fill="currentColor" />
    </svg>
  )
}

function DpadIcon() {
  return (
    <svg viewBox="0 0 18 18" width="18" height="18" aria-hidden="true">
      <path
        d="M6.5 1.5h5v5h5v5h-5v5h-5v-5h-5v-5h5z"
        fill="var(--ts-pad-neutral)"
        stroke="var(--ts-pad-neutral)"
        strokeWidth="1"
        strokeLinejoin="round"
      />
      <circle cx="9" cy="9" r="1.6" fill="#fff" opacity="0.7" />
    </svg>
  )
}

function SearchIcon() {
  return (
    <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true">
      <circle cx="7" cy="7" r="4.5" fill="none" stroke="currentColor" strokeWidth="2" />
      <path d="M10.5 10.5 14 14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  )
}
