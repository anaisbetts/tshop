import { useState } from 'react';
import { ConsoleHeader } from './ConsoleHeader';
import { ScrollableAppList } from './ScrollableAppList';
import { getMockAppCatalog } from './mockData';
import { AppDetailHero } from './AppDetailHero';
import { ControllerHints } from './ControllerHints';
import type { AppTileData } from './AppTile';
import './tshop-theme.css';

// 2. Constants
const COLOR_SWATCHES = [
  { name: 'Cyan Accent', value: '#00f0ff', token: '--ts-accent-cyan', role: 'Primary focus, Wi-Fi online, active indicators' },
  { name: 'Purple Accent', value: '#9d4edd', token: '--ts-accent-purple', role: 'Active tab pill, hero background radial glow' },
  { name: 'Magenta Accent', value: '#f72585', token: '--ts-accent-magenta', role: 'Update available badge, alerts' },
  { name: 'Green Accent', value: '#10b981', token: '--ts-accent-green', role: 'Installed badge, battery healthy, success' },
  { name: 'Amber Accent', value: '#f59e0b', token: '--ts-accent-amber', role: 'Publisher/Landing page redirect, probe warning' },
  { name: 'Red Accent', value: '#ef4444', token: '--ts-accent-red', role: 'Signature mismatch, incompatible requirement' },
  { name: 'Deep Canvas', value: '#0c0d14', token: '--ts-bg-canvas', role: 'AMOLED dark background (battery efficient)' },
  { name: 'Frosted Surface', value: 'rgba(24, 26, 38, 0.75)', token: '--ts-bg-surface', role: 'Glass panels with 16px blur backdrop' },
];

const TYPOGRAPHY_SAMPLES = [
  { label: 'Display Hero H1 (Plus Jakarta Sans 800)', sample: 'RetroArch Frontend', size: '24px / 800', tracking: '-0.5px' },
  { label: 'Category Frame Title (Plus Jakarta Sans 700)', sample: 'Emulators & Frontends', size: '15px / 700', tracking: '-0.2px' },
  { label: 'Body Summary (Plus Jakarta Sans 500)', sample: 'A curated app store for Android game consoles. Browse tiles, verify signatures.', size: '13px / 500', tracking: '0px' },
  { label: 'Console Monospace (JetBrains Mono 700)', sample: 'v1.19.1 • 367 DPI • arm64-v8a • 7d EWMA', size: '11px / 700', tracking: '+0.5px' },
  { label: 'Controller Button Glyph (Mono 800)', sample: 'A B X Y L1 R1 START SELECT ✚', size: '11px / 800', tracking: '0px' },
];

// 3. Types and Interfaces
export interface DesignLanguageShowcaseProps {
  initialTheme?: 'dark' | 'light';
}

// 4. The most important class / function in the file - the theme of what this file is about
export function DesignLanguageShowcase({
  initialTheme = 'dark',
}: DesignLanguageShowcaseProps) {
  const [theme, setTheme] = useState<'dark' | 'light'>(initialTheme);
  const [activeTab, setActiveTab] = useState<'overview' | 'typography' | 'controls' | 'hardware'>('overview');
  const sections = getMockAppCatalog();
  const [selectedApp, setSelectedApp] = useState<AppTileData>(sections[0]!.apps[0]!);

  return (
    <div className="ts-showcase-container tshop-theme" data-theme={theme}>
      {/* Showcase Hero Header */}
      <header className="ts-showcase-hero">
        <div className="ts-showcase-hero-inner">
          <div className="ts-showcase-badge">tShop System Design Language</div>
          <h1 className="ts-showcase-title">Handheld Console Store Experience</h1>
          <p className="ts-showcase-lede">
            Rooted in the Nintendo 3DS home menu aesthetics and modern launcher cues from iiSU.
            Crafted with exact physical and logical viewport constraints for the dual-screen <strong>AYN Thor</strong>.
          </p>

          <div className="ts-showcase-nav-bar">
            <div className="ts-showcase-tabs">
              <button
                type="button"
                className={`ts-showcase-tab ${activeTab === 'overview' ? 'is-active' : ''}`}
                onClick={() => setActiveTab('overview')}
              >
                1. System Overview
              </button>
              <button
                type="button"
                className={`ts-showcase-tab ${activeTab === 'typography' ? 'is-active' : ''}`}
                onClick={() => setActiveTab('typography')}
              >
                2. Fonts & Colors
              </button>
              <button
                type="button"
                className={`ts-showcase-tab ${activeTab === 'controls' ? 'is-active' : ''}`}
                onClick={() => setActiveTab('controls')}
              >
                3. Main 3DS Controls
              </button>
              <button
                type="button"
                className={`ts-showcase-tab ${activeTab === 'hardware' ? 'is-active' : ''}`}
                onClick={() => setActiveTab('hardware')}
              >
                4. AYN Thor Viewports
              </button>
            </div>

            <button
              type="button"
              className="ts-theme-toggle"
              onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            >
              Toggle {theme === 'dark' ? 'Light' : 'Dark'} Mode
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="ts-showcase-main">
        {activeTab === 'overview' && (
          <div className="ts-showcase-section">
            <h2 className="ts-section-heading">Design Principles & Lineage</h2>
            <div className="ts-overview-cards">
              <div className="ts-card">
                <div className="ts-card-icon">🎮</div>
                <h3>3DS Home Menu Homage</h3>
                <p>
                  Square tile grids arranged into framed category sections. Single continuous D-Pad focus graph
                  with neutral high-contrast focus rings and zero arrow-key leakage.
                </p>
              </div>

              <div className="ts-card">
                <div className="ts-card-icon">✨</div>
                <h3>iiSU Launcher Atmosphere</h3>
                <p>
                  Vibrant cyan/purple/magenta gradient accents, frosted glass panels with blur, clean rounded badges,
                  and dual-screen DS layout ergonomics designed specifically for handheld gamers.
                </p>
              </div>

              <div className="ts-card">
                <div className="ts-card-icon">📱</div>
                <h3>AYN Thor Calibration</h3>
                <p>
                  Calibrated for 367 DPI top panel (837×471 logical px) and 335 DPI bottom panel (592×516 logical px),
                  respecting Android 13/14 full-screen modal IME constraints and controller input handling.
                </p>
              </div>
            </div>

            <div className="ts-demo-preview-frame">
              <h3 className="ts-frame-title">Interactive Console Header Preview</h3>
              <ConsoleHeader
                title="tShop"
                activeTab="browse"
                status="online"
                libraryBadgeCount={3}
                batteryPercentage={92}
                timeString="16:42"
              />
            </div>
          </div>
        )}

        {activeTab === 'typography' && (
          <div className="ts-showcase-section">
            <h2 className="ts-section-heading">Color Palette & iiSU Vibe</h2>
            <div className="ts-swatches-grid">
              {COLOR_SWATCHES.map((swatch) => (
                <div key={swatch.token} className="ts-swatch-card">
                  <div className="ts-swatch-box" style={{ background: swatch.value }} />
                  <div className="ts-swatch-info">
                    <span className="ts-swatch-name">{swatch.name}</span>
                    <code className="ts-swatch-token">{swatch.token}</code>
                    <p className="ts-swatch-role">{swatch.role}</p>
                  </div>
                </div>
              ))}
            </div>

            <h2 className="ts-section-heading" style={{ marginTop: '36px' }}>
              Typography Hierarchy
            </h2>
            <div className="ts-typography-list">
              {TYPOGRAPHY_SAMPLES.map((item) => (
                <div key={item.label} className="ts-type-row">
                  <div className="ts-type-meta">
                    <span className="ts-type-label">{item.label}</span>
                    <code className="ts-type-stats">{item.size}</code>
                  </div>
                  <div className="ts-type-preview">{item.sample}</div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'controls' && (
          <div className="ts-showcase-section">
            <h2 className="ts-section-heading">3DS Scrollable Category List</h2>
            <p className="ts-section-sub">
              Apps live in square tiles framed by category. Click or navigate with keyboard arrows (D-Pad).
            </p>

            <div className="ts-controls-split">
              <div className="ts-split-left">
                <ScrollableAppList
                  sections={sections}
                  selectedAppId={selectedApp.id}
                  onSelectApp={(app) => setSelectedApp(app)}
                  onHoverApp={(app) => setSelectedApp(app)}
                />
              </div>

              <div className="ts-split-right">
                <h3 className="ts-panel-title">Selected App Details (Hover / Focused)</h3>
                <AppDetailHero
                  name={selectedApp.name}
                  category={selectedApp.category}
                  version={selectedApp.version}
                  author={selectedApp.category === 'Emulators' ? 'Libretro / FOSS' : 'FOSS Community'}
                  summary={
                    selectedApp.id === 'retroarch'
                      ? 'Cross-platform frontend for emulators, game engines, and media players. Enables running classic games with unified shader presets and controller bindings.'
                      : selectedApp.id === 'iisu'
                      ? 'Nintendo 3DS / Wii U inspired Android launcher with frosted glass panels and full dual-screen DS mode.'
                      : `Verified catalog release for ${selectedApp.name}. Built and tested for handheld controller navigation.`
                  }
                  primaryAction={
                    selectedApp.badge === 'update'
                      ? 'update'
                      : selectedApp.badge === 'installed'
                      ? 'open'
                      : selectedApp.badge === 'landing'
                      ? 'landing'
                      : selectedApp.isGreyed
                      ? 'mismatch'
                      : 'install'
                  }
                  iconBg={selectedApp.iconBg}
                  iconSymbol={selectedApp.iconSymbol}
                />

                <div className="ts-controller-hints-box">
                  <ControllerHints
                    prompts={[
                      { button: 'a', label: 'Install / Action' },
                      { button: 'b', label: 'Back' },
                      { button: 'y', label: 'Search' },
                      { button: 'select', label: 'Privacy Mode' },
                    ]}
                  />
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'hardware' && (
          <div className="ts-showcase-section">
            <h2 className="ts-section-heading">AYN Thor Dual-Screen Architecture</h2>
            <p className="ts-section-sub">
              Detailed breakdown of why web viewports must not be 1920px wide on Android handhelds.
            </p>

            <div className="ts-viewport-spec-table">
              <table>
                <thead>
                  <tr>
                    <th>Display Panel</th>
                    <th>Physical Resolution</th>
                    <th>Display Density</th>
                    <th>Logical Viewport</th>
                    <th>Aspect Ratio & Refresh</th>
                    <th>UI Role</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>
                      <strong>Top Screen</strong>
                    </td>
                    <td>1920 × 1080 px</td>
                    <td>367 PPI (~2.29x density)</td>
                    <td>
                      <code className="ts-highlight">837 × 471 px</code>
                    </td>
                    <td>16:9 • 120 Hz AMOLED</td>
                    <td>Console Header, App Detail Hero, Artwork & Screenshots, Status Strip</td>
                  </tr>
                  <tr>
                    <td>
                      <strong>Bottom Screen</strong>
                    </td>
                    <td>1240 × 1080 px</td>
                    <td>335 PPI (~2.09x density)</td>
                    <td>
                      <code className="ts-highlight">592 × 516 px</code>
                    </td>
                    <td>31:27 (Near 1:1) • 60 Hz Touch</td>
                    <td>Continuous Category Tile Grid, Touch Navigation, Search IME & Filter</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div className="ts-card" style={{ marginTop: '24px' }}>
              <h3>Why 1920px Desktop Layouts Fail on Handhelds</h3>
              <p>
                A 6-inch 1080p panel at arms length has Android density scaling set to ~367 DPI (density bucket ~2.3x).
                If a web viewport is set to 1920px wide, touch targets and fonts shrink down to microscopic sizes (a 16px font
                becomes physically 1.1mm tall). By designing with an 837×471 logical canvas, UI elements remain comfortably
                legible, and button touch targets exceed the minimum 48dp Android requirement.
              </p>
            </div>
          </div>
        )}
      </main>

      <style>{`
        .ts-showcase-container {
          min-height: 100vh;
          background: var(--ts-bg-canvas);
          color: var(--ts-text-primary);
          padding: 32px 40px;
          font-family: var(--ts-font-display);
        }

        .ts-showcase-hero {
          margin-bottom: 32px;
          border-bottom: 1px solid var(--ts-border-subtle);
          padding-bottom: 24px;
        }

        .ts-showcase-badge {
          display: inline-block;
          font-family: var(--ts-font-mono);
          font-size: 11px;
          font-weight: 700;
          color: var(--ts-accent-cyan);
          background: rgba(0, 240, 255, 0.1);
          padding: 4px 10px;
          border-radius: 6px;
          margin-bottom: 12px;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }

        .ts-showcase-title {
          margin: 0 0 10px;
          font-size: 32px;
          font-weight: 800;
          letter-spacing: -0.8px;
          background: linear-gradient(135deg, #ffffff, var(--ts-text-secondary));
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }

        .ts-showcase-lede {
          margin: 0 0 20px;
          font-size: 15px;
          color: var(--ts-text-secondary);
          max-width: 760px;
          line-height: 1.5;
        }

        .ts-showcase-nav-bar {
          display: flex;
          align-items: center;
          justify-content: space-between;
          flex-wrap: wrap;
          gap: 16px;
          margin-top: 16px;
        }

        .ts-showcase-tabs {
          display: flex;
          gap: 6px;
          background: rgba(255, 255, 255, 0.04);
          padding: 4px;
          border-radius: 10px;
          border: 1px solid var(--ts-border-subtle);
        }

        .ts-showcase-tab {
          padding: 8px 16px;
          border-radius: 6px;
          border: none;
          background: transparent;
          color: var(--ts-text-secondary);
          font-family: var(--ts-font-display);
          font-size: 13px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.2s ease;
        }

        .ts-showcase-tab:hover {
          color: var(--ts-text-primary);
        }

        .ts-showcase-tab.is-active {
          color: #ffffff;
          background: var(--ts-accent-purple);
          box-shadow: 0 2px 8px rgba(157, 78, 221, 0.4);
        }

        .ts-theme-toggle {
          padding: 6px 14px;
          border-radius: 8px;
          border: 1px solid var(--ts-border-subtle);
          background: rgba(255, 255, 255, 0.05);
          color: var(--ts-text-primary);
          font-family: var(--ts-font-display);
          font-size: 12px;
          font-weight: 600;
          cursor: pointer;
        }

        .ts-section-heading {
          font-size: 20px;
          font-weight: 700;
          margin: 0 0 8px;
          letter-spacing: -0.3px;
        }

        .ts-section-sub {
          font-size: 14px;
          color: var(--ts-text-muted);
          margin: 0 0 24px;
        }

        .ts-overview-cards {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
          gap: 20px;
          margin-bottom: 32px;
        }

        .ts-card {
          padding: 24px;
          border-radius: 16px;
          background: var(--ts-bg-surface);
          border: 1px solid var(--ts-border-subtle);
          box-shadow: var(--ts-glow-card);
        }

        .ts-card-icon {
          font-size: 28px;
          margin-bottom: 12px;
        }

        .ts-card h3 {
          margin: 0 0 8px;
          font-size: 16px;
          font-weight: 700;
        }

        .ts-card p {
          margin: 0;
          font-size: 13px;
          line-height: 1.5;
          color: var(--ts-text-secondary);
        }

        .ts-demo-preview-frame {
          border-radius: 16px;
          border: 1px solid var(--ts-border-subtle);
          background: rgba(0, 0, 0, 0.3);
          padding: 20px;
          box-shadow: inset 0 0 20px rgba(0, 0, 0, 0.5);
        }

        .ts-frame-title {
          font-size: 13px;
          font-family: var(--ts-font-mono);
          color: var(--ts-accent-cyan);
          margin: 0 0 12px;
        }

        .ts-swatches-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
          gap: 16px;
        }

        .ts-swatch-card {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 12px;
          border-radius: 12px;
          background: var(--ts-bg-surface);
          border: 1px solid var(--ts-border-subtle);
        }

        .ts-swatch-box {
          width: 44px;
          height: 44px;
          border-radius: 10px;
          border: 1px solid rgba(255, 255, 255, 0.2);
          flex-shrink: 0;
        }

        .ts-swatch-info {
          display: flex;
          flex-direction: column;
          gap: 2px;
          overflow: hidden;
        }

        .ts-swatch-name {
          font-size: 13px;
          font-weight: 700;
        }

        .ts-swatch-token {
          font-size: 10px;
          color: var(--ts-accent-cyan);
        }

        .ts-swatch-role {
          font-size: 11px;
          color: var(--ts-text-muted);
          margin: 0;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }

        .ts-typography-list {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .ts-type-row {
          padding: 16px 20px;
          border-radius: 12px;
          background: var(--ts-bg-surface);
          border: 1px solid var(--ts-border-subtle);
          display: flex;
          flex-direction: column;
          gap: 6px;
        }

        .ts-type-meta {
          display: flex;
          justify-content: space-between;
          align-items: center;
        }

        .ts-type-label {
          font-size: 12px;
          font-weight: 600;
          color: var(--ts-text-secondary);
        }

        .ts-type-stats {
          font-size: 11px;
          color: var(--ts-accent-purple);
        }

        .ts-type-preview {
          font-size: 18px;
          font-weight: 600;
          color: var(--ts-text-primary);
        }

        .ts-controls-split {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 24px;
        }

        @media (max-width: 900px) {
          .ts-controls-split {
            grid-template-columns: 1fr;
          }
        }

        .ts-split-left {
          height: 520px;
          background: rgba(12, 13, 20, 0.7);
          border-radius: 16px;
          border: 1px solid var(--ts-border-subtle);
          overflow: hidden;
        }

        .ts-split-right {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .ts-panel-title {
          font-size: 14px;
          font-weight: 700;
          margin: 0;
          color: var(--ts-text-secondary);
        }

        .ts-controller-hints-box {
          border-radius: 12px;
          overflow: hidden;
          border: 1px solid var(--ts-border-subtle);
        }

        .ts-viewport-spec-table table {
          width: 100%;
          border-collapse: collapse;
          font-size: 13px;
          background: var(--ts-bg-surface);
          border-radius: 12px;
          overflow: hidden;
          border: 1px solid var(--ts-border-subtle);
        }

        .ts-viewport-spec-table th,
        .ts-viewport-spec-table td {
          padding: 12px 16px;
          text-align: left;
          border-bottom: 1px solid var(--ts-border-subtle);
        }

        .ts-viewport-spec-table th {
          background: rgba(255, 255, 255, 0.04);
          font-weight: 700;
          color: var(--ts-text-secondary);
        }

        .ts-highlight {
          color: var(--ts-accent-cyan);
          background: rgba(0, 240, 255, 0.1);
          padding: 2px 6px;
          border-radius: 4px;
          font-weight: 700;
        }
      `}</style>
    </div>
  );
}

// 5. Second-most important classes/functions
// (none)

// 6. At the end, we find utility functions, helpers
// (none)
