export const SWATCHES = [
  { name: 'Background', value: '#e9eaee' },
  { name: 'Panel', value: '#ffffff' },
  { name: 'Ink', value: '#2b2b33' },
  { name: 'Muted', value: '#6b6d78' },
  { name: 'Focus', value: '#a58cff' },
  { name: 'Update', value: '#3cbf7a' },
  { name: 'Danger', value: '#e24b4b' },
] as const

export function Typography() {
  return (
    <div className="tshop-type">
      <p className="tshop-type__title">Browse the shop</p>
      <p className="tshop-type__section">Emulators</p>
      <p className="tshop-type__body">GameCube and Wii emulator. Install stays one action.</p>
      <p className="tshop-type__legend">A Select · Y Search</p>
      <p className="tshop-type__badge">Update available</p>
      <p className="tshop-type__nums">1.18.1 · 2509 · 146</p>
    </div>
  )
}

export function Palette() {
  return (
    <div className="tshop-palette">
      {SWATCHES.map((swatch) => (
        <div className="tshop-swatch" key={swatch.name}>
          <div className="tshop-swatch__chip" style={{ background: swatch.value }} />
          <span className="tshop-swatch__name">{swatch.name}</span>
          <span className="tshop-swatch__value">{swatch.value}</span>
        </div>
      ))}
    </div>
  )
}
