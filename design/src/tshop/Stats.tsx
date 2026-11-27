import type { CSSProperties } from 'react'

import { PolicyCard } from './About.tsx'
import { byId, type Entry } from './catalog.ts'
import type { Mode } from './Chrome.tsx'

/** Published counts from 1 to 4 show as "<5" so long-tail apps can't be read as live activity. */
const SUPPRESS_BELOW = 5

/**
 * Illustrative rows in catalog rank order. The real page reads the same daily aggregates that order the grid.
 * Vita3K is new, so it sits at its curator seed position with a suppressed count.
 */
const ROWS: { id: string; installs: number; updates: number; all: number }[] = [
  { id: 'retroarch', installs: 3020, updates: 1100, all: 61880 },
  { id: 'dolphin', installs: 2410, updates: 900, all: 52404 },
  { id: 'ppsspp', installs: 1650, updates: 1225, all: 47112 },
  { id: 'lemuroid', installs: 980, updates: 480, all: 18930 },
  { id: 'melonds', installs: 1010, updates: 292, all: 16288 },
  { id: 'pixel-dungeon', installs: 720, updates: 268, all: 12406 },
  { id: 'flycast', installs: 640, updates: 230, all: 11953 },
  { id: 'mindustry', installs: 410, updates: 334, all: 9617 },
  { id: 'syncthing', installs: 450, updates: 160, all: 8022 },
  { id: 'scummvm', installs: 380, updates: 122, all: 7311 },
  { id: 'vita3k', installs: 2, updates: 0, all: 3 },
  { id: 'supertuxkart', installs: 320, updates: 111, all: 6650 },
  { id: 'unciv', installs: 300, updates: 98, all: 4870 },
  { id: 'amaze', installs: 160, updates: 54, all: 3102 },
  { id: 'moonlight', installs: 150, updates: 40, all: 2766 },
]

/** First-party web page, not an in-app screen. The whole dataset, no login. Opened from About. */
export function Stats({ mode = 'day' }: { mode?: Mode }) {
  const rows = ROWS.map((row) => ({ ...row, entry: byId(row.id) }))
  const week = rows.reduce((sum, row) => sum + shown(row.installs) + shown(row.updates), 0)
  const all = rows.reduce((sum, row) => sum + shown(row.all), 0)
  const peak = Math.max(...rows.map((row) => shown(row.installs)))

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
                <th className="num">Installs · 7 days</th>
                <th className="num">Updates · 7 days</th>
                <th className="num">All time</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, index) => (
                <tr key={row.id}>
                  <td className="rank">{index + 1}</td>
                  <td>
                    <span className="ts-web__app">
                      <MiniTile entry={row.entry} />
                      {row.entry.name}
                    </span>
                  </td>
                  <td className="muted">{row.entry.category}</td>
                  <td className="num">
                    <span className="ts-web__bar">
                      <span style={{ width: `${(shown(row.installs) / peak) * 100}%` }} />
                    </span>
                    {format(row.installs)}
                  </td>
                  <td className="num muted">{format(row.updates)}</td>
                  <td className="num">{format(row.all)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <aside className="ts-web__side">
          <PolicyCard />
          <section className="ts-card">
            <h3>How the order works</h3>
            <p>
              Installs count fully and updates count a quarter, smoothed over about a week, so frequent releases don’t
              push an app up. New apps start at a position the curators pick until they have two weeks of downloads.
              Counts from 1 to 4 show as “&lt;5” and are left out of the totals.
            </p>
          </section>
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

function shown(value: number): number {
  return isSuppressed(value) ? 0 : value
}

function isSuppressed(value: number): boolean {
  return value >= 1 && value < SUPPRESS_BELOW
}

function format(value: number): string {
  return isSuppressed(value) ? `<${SUPPRESS_BELOW}` : value.toLocaleString('en-US')
}
