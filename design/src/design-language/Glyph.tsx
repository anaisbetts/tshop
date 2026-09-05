const FACE = {
  A: 'a',
  B: 'b',
  X: 'x',
  Y: 'y',
} as const

export type GlyphName = 'A' | 'B' | 'X' | 'Y' | 'L' | 'R' | '+' | '-'

export type WifiState = 'online' | 'offline'

export function Glyph({ name }: { name: GlyphName }) {
  const face = name === 'A' || name === 'B' || name === 'X' || name === 'Y'
  const tone = face ? FACE[name] : undefined
  const className = ['tshop-glyph', face ? `tshop-glyph--face tshop-glyph--${tone}` : '']
    .filter(Boolean)
    .join(' ')

  return <span className={className}>{name}</span>
}

export function WifiIcon({ state }: { state: WifiState }) {
  return (
    <svg
      className={['tshop-wifi', state === 'offline' ? 'is-offline' : ''].filter(Boolean).join(' ')}
      viewBox="0 0 16 16"
      aria-hidden="true"
      shapeRendering="crispEdges"
    >
      <rect x="7" y="13" width="2" height="2" fill="currentColor" />
      {state === 'online' ? (
        <>
          <rect x="5" y="10" width="6" height="2" fill="currentColor" />
          <rect x="3" y="7" width="10" height="2" fill="currentColor" />
          <rect x="1" y="4" width="14" height="2" fill="currentColor" />
        </>
      ) : (
        <>
          <rect x="5" y="10" width="6" height="2" fill="currentColor" />
          <rect x="3" y="3" width="2" height="8" fill="currentColor" transform="rotate(45 4 7)" />
        </>
      )}
    </svg>
  )
}
