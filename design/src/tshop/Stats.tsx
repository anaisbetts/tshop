import type { CSSProperties } from 'react'

import { PolicyCard } from './About.tsx'
import { CATALOG, type Entry } from './catalog.ts'
import type { Mode } from './Chrome.tsx'

/** Illustrative totals. The real page reads the same daily aggregates that order the grid. */
const TOTALS: Record<string, { week: number; all: number }> = {
  retroarch: { week: 4120, all: 61880 },
  dolphin: { week: 3310, all: 52404 },
  ppsspp: { week: 2875, all: 47112 },
  lemuroid: { week: 1460, all: 18930 },
  melonds: { week: 1302, all: 16288 },
  'pixel-dungeon': { week: 988, all: 12406 },
  flycast: { week: 870, all: 11953 },
  mindustry: { week: 744, all: 9617 },
  syncthing: { week: 610, all: 8022 },
  scummvm: { week: 502, all: 7311 },
  vita3k: { week: 455, all: 5208 },
  supertuxkart: { week: 431, all: 6650 },
  unciv: { week: 398, all: 4870 },
  amaze: { week: 214, all: 3102 },
  moonlight: { week: 190, all: 2766 },
}

/** First-party web page, not an in-app screen. The whole dataset, no login. Opened from About. */
export function Stats({ mode = 'day' }: { mode?: Mode }) {
  const rows = CATALOG.filter((entry) => TOTALS[entry.id]).sort((a, b) => TOTALS[b.id].week - TOTALS[a.id].week)
  const week = rows.reduce((sum, entry) => sum + TOTALS[entry.id].week, 0)
  const all = rows.reduce((sum, entry) => sum + TOTALS[entry.id].all, 0)
  const peak = TOTALS[rows[0].id].week

  return (
    <div className="ts-root ts-web" data-mode={mode}>
      <header className="ts-web__head">
        <span className="ts-logo ts-logo--big" aria-hidden="true">
          t
        </span>
        <div>
          <h1 className="ts-web__title">tShop download counts</h1>
          <p className="ts-row__desc">Completed APK downloads from tShop’s host, per app. This page is the whole dataset.</p>
        </div>
        <span className="ts-topbar__spacer" />
        <span className="ts-chip">Updated daily · 6 Oct 2026 UTC</span>
      </header>
      <div className="ts-web__totals">
        <Total label="Last 7 days" value={week} />
        <Total label="All time" value={all} />
        <Total label="Apps" value={rows.length} />
      </div>
      <div className="ts-web__body">
        <section className="ts-card ts-web__table">
          <h3>Popularity order, as shipped in the catalog</h3>
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>App</th>
                <th>Category</th>
                <th className="num">Last 7 days</th>
                <th className="num">All time</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((entry, index) => (
                <tr key={entry.id}>
                  <td className="rank">{index + 1}</td>
                  <td>
                    <span className="ts-web__app">
                      <MiniTile entry={entry} />
                      {entry.name}
                    </span>
                  </td>
                  <td className="muted">{entry.category}</td>
                  <td className="num">
                    <span className="ts-web__bar">
                      <span style={{ width: `${(TOTALS[entry.id].week / peak) * 100}%` }} />
                    </span>
                    {format(TOTALS[entry.id].week)}
                  </td>
                  <td className="num">{format(TOTALS[entry.id].all)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <aside className="ts-web__side">
          <PolicyCard />
          <section className="ts-card">
            <h3>Not counted</h3>
            <p>
              Publisher-only apps (tShop never serves them) and Privacy Mode downloads (they go straight to the publisher).
            </p>
          </section>
        </aside>
      </div>
    </div>
  )
}

function Total({ label, value }: { label: string; value: number }) {
  return (
    <div className="ts-card ts-web__total">
      <h3>{label}</h3>
      <p>{format(value)}</p>
    </div>
  )
}

function MiniTile({ entry }: { entry: Entry }) {
  return (
    <span className="ts-tile ts-web__tile" style={{ '--ts-tile-bg': entry.backdrop, '--ts-tile-scale': entry.scale } as CSSProperties}>
      <span className="ts-tile__clip">
        <img className="ts-tile__art" src={entry.icon} alt="" />
      </span>
    </span>
  )
}

function format(value: number): string {
  return value.toLocaleString('en-US')
}
