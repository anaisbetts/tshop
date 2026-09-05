import { Glyph, type GlyphName } from './Glyph.tsx'

const ITEMS: { name: GlyphName; label: string }[] = [
  { name: 'Y', label: 'Search' },
  { name: 'B', label: 'Back' },
  { name: 'A', label: 'Select' },
  { name: '+', label: 'Menu' },
]

export function ButtonLegend() {
  return (
    <footer className="tshop-legend">
      <div className="tshop-legend__group">
        {ITEMS.slice(0, 2).map((item) => (
          <LegendItem key={item.name} name={item.name} label={item.label} />
        ))}
      </div>
      <div className="tshop-legend__group">
        {ITEMS.slice(2).map((item) => (
          <LegendItem key={item.name} name={item.name} label={item.label} />
        ))}
      </div>
    </footer>
  )
}

function LegendItem({ name, label }: { name: GlyphName; label: string }) {
  return (
    <span className="tshop-legend__item">
      <Glyph name={name} />
      {label}
    </span>
  )
}
