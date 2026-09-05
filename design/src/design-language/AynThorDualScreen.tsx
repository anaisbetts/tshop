import { useState } from 'react';
import { ConsoleHeader, type ReachabilityStatus } from './ConsoleHeader';
import { ScrollableAppList } from './ScrollableAppList';
import { getMockAppCatalog } from './mockData';
import { AppDetailHero } from './AppDetailHero';
import { ControllerHints } from './ControllerHints';
import type { AppTileData } from './AppTile';
import './tshop-theme.css';

// 2. Constants
const AYN_THOR_SPEC = {
  top: {
    physical: '1920 × 1080',
    ppi: 367,
    logical: '837 × 471 px',
    ratio: '16:9',
    rate: '120 Hz AMOLED',
  },
  bottom: {
    physical: '1240 × 1080',
    ppi: 335,
    logical: '592 × 516 px (or ~541 × 471 px scaled)',
    ratio: '31:27 (near-square)',
    rate: '60 Hz AMOLED Touch',
  },
};

// 3. Types and Interfaces
export interface AynThorDualScreenProps {
  initialStatus?: ReachabilityStatus;
  theme?: 'dark' | 'light';
}

// 4. The most important class / function in the file - the theme of what this file is about
export function AynThorDualScreen({
  initialStatus = 'online',
  theme = 'dark',
}: AynThorDualScreenProps) {
  const sections = getMockAppCatalog();
  const [selectedApp, setSelectedApp] = useState<AppTileData>(
    sections[0]?.apps[0] || {
      id: 'retroarch',
      name: 'RetroArch',
      category: 'Emulators',
      version: '1.19.1',
      iconBg: 'linear-gradient(135deg, #1e293b, #0f172a)',
      iconSymbol: 'RA',
      badge: 'update',
      downloadsRecent: 1420,
    }
  );
  const [activeTab, setActiveTab] = useState<'browse' | 'library' | 'settings'>('browse');
  const [currentTheme, setCurrentTheme] = useState<'dark' | 'light'>(theme);

  return (
    <div className="ayn-thor-simulator tshop-theme" data-theme={currentTheme}>
      {/* Device Form Factor Frame */}
      <div className="ayn-thor-chassis">
        <div className="chassis-header">
          <div className="chassis-badge">AYN Thor Dual-Screen Clamshell Handheld</div>
          <button
            type="button"
            className="theme-toggle-btn"
            onClick={() => setCurrentTheme(currentTheme === 'dark' ? 'light' : 'dark')}
          >
            Switch to {currentTheme === 'dark' ? 'Light' : 'Dark'} Mode
          </button>
        </div>

        {/* TOP SCREEN CONTAINER: 837 x 471 logical viewport */}
        <section className="screen-container top-screen" aria-label="AYN Thor Top Screen (Gaming & Hero Detail View)">
          <div className="screen-label">
            <span>TOP SCREEN (1920×1080 @ 367 DPI → 837×471 logical px)</span>
            <span className="spec-tag">{AYN_THOR_SPEC.top.rate}</span>
          </div>

          <div className="viewport top-viewport">
            <ConsoleHeader
              title="tShop"
              activeTab={activeTab}
              onTabChange={setActiveTab}
              status={initialStatus}
              libraryBadgeCount={2}
            />

            <main className="top-main-content">
              <AppDetailHero
                name={selectedApp.name}
                category={selectedApp.category}
                version={selectedApp.version}
                author={selectedApp.category === 'Emulators' ? 'Libretro / FOSS' : 'Independent'}
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

              {/* Console Spec and Telemetry Strip */}
              <div className="stats-ticker-strip">
                <span className="ticker-item">
                  <strong>7-Day Velocity:</strong> {selectedApp.downloadsRecent || 320} completions
                </span>
                <span className="ticker-item">
                  <strong>Signature:</strong> Verified (v2/v3 Block OK)
                </span>
                <span className="ticker-item">
                  <strong>ABI:</strong> arm64-v8a (16KB Aligned)
                </span>
              </div>
            </main>

            <ControllerHints
              prompts={[
                { button: 'a', label: 'Launch / Action' },
                { button: 'x', label: 'Changelog' },
                { button: 'y', label: 'Commit Search' },
                { button: 'l2', label: 'Prev' },
                { button: 'r2', label: 'Next' },
              ]}
            />
          </div>
        </section>

        {/* HINGE DIVIDER */}
        <div className="hardware-hinge">
          <div className="hinge-groove" />
        </div>

        {/* BOTTOM SCREEN CONTAINER: 592 x 516 logical viewport (or 1240x1080 @ ~335 dpi) */}
        <section className="screen-container bottom-screen" aria-label="AYN Thor Bottom Screen (Touch & 3DS App Grid)">
          <div className="screen-label">
            <span>BOTTOM SCREEN (1240×1080 @ 335 DPI → 592×516 logical px)</span>
            <span className="spec-tag">{AYN_THOR_SPEC.bottom.rate}</span>
          </div>

          <div className="viewport bottom-viewport">
            <div className="bottom-screen-header">
              <div className="bottom-title">
                <span className="dpad-icon">✚</span>
                <span>Category App Grid (3DS Continuous Frame)</span>
              </div>
              <div className="bottom-search-chip">
                <span>Y</span>
                <span>Filter / Search</span>
              </div>
            </div>

            <div className="bottom-grid-container">
              <ScrollableAppList
                sections={sections}
                selectedAppId={selectedApp.id}
                onSelectApp={(app) => setSelectedApp(app)}
                onHoverApp={(app) => setSelectedApp(app)}
              />
            </div>

            <ControllerHints
              prompts={[
                { button: 'dpad', label: 'Navigate Grid' },
                { button: 'a', label: 'Inspect App' },
                { button: 'b', label: 'Exit to Root' },
                { button: 'select', label: 'Privacy Mode' },
              ]}
            />
          </div>
        </section>
      </div>

      <style>{`
        .ayn-thor-simulator {
          display: flex;
          justify-content: center;
          padding: 24px;
          min-height: 100vh;
          background: #06070a;
          color: var(--ts-text-primary);
          font-family: var(--ts-font-display);
        }

        .ayn-thor-chassis {
          display: flex;
          flex-direction: column;
          align-items: center;
          width: 890px;
          padding: 20px 24px;
          border-radius: 28px;
          background: #11131c;
          border: 2px solid #232738;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.8), 0 0 0 1px rgba(255, 255, 255, 0.05);
        }

        .chassis-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          width: 100%;
          margin-bottom: 16px;
        }

        .chassis-badge {
          font-family: var(--ts-font-mono);
          font-size: 11px;
          font-weight: 700;
          color: var(--ts-accent-cyan);
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }

        .theme-toggle-btn {
          padding: 4px 10px;
          border-radius: 6px;
          border: 1px solid var(--ts-border-subtle);
          background: rgba(255, 255, 255, 0.05);
          color: var(--ts-text-secondary);
          font-size: 11px;
          font-family: var(--ts-font-display);
          cursor: pointer;
        }

        .theme-toggle-btn:hover {
          color: var(--ts-text-primary);
          background: rgba(255, 255, 255, 0.1);
        }

        .screen-container {
          display: flex;
          flex-direction: column;
          align-items: center;
          width: 100%;
        }

        .screen-label {
          display: flex;
          justify-content: space-between;
          align-items: center;
          width: 100%;
          max-width: 837px;
          margin-bottom: 6px;
          font-family: var(--ts-font-mono);
          font-size: 10px;
          font-weight: 600;
          color: var(--ts-text-muted);
        }

        .spec-tag {
          color: var(--ts-accent-purple);
        }

        /* Top Viewport: exact 837 x 471 logical px matching AYN Thor */
        .top-viewport {
          width: 837px;
          height: 471px;
          border-radius: 12px;
          background: var(--ts-bg-canvas);
          border: 2px solid var(--ts-border-subtle);
          overflow: hidden;
          display: flex;
          flex-direction: column;
          position: relative;
          box-shadow: inset 0 0 20px rgba(0, 0, 0, 0.6);
        }

        .top-main-content {
          padding: 16px 20px;
          flex-grow: 1;
          display: flex;
          flex-direction: column;
          gap: 12px;
          overflow-y: auto;
        }

        .stats-ticker-strip {
          display: flex;
          align-items: center;
          gap: 16px;
          padding: 8px 14px;
          border-radius: 8px;
          background: rgba(255, 255, 255, 0.03);
          border: 1px solid var(--ts-border-subtle);
          font-family: var(--ts-font-mono);
          font-size: 11px;
          color: var(--ts-text-secondary);
        }

        .ticker-item strong {
          color: var(--ts-accent-cyan);
        }

        /* Hinge Styling */
        .hardware-hinge {
          width: 860px;
          height: 22px;
          margin: 10px 0;
          background: linear-gradient(180deg, #181a26 0%, #0d0e14 50%, #181a26 100%);
          border-radius: 6px;
          border-top: 1px solid rgba(255, 255, 255, 0.08);
          border-bottom: 1px solid rgba(0, 0, 0, 0.8);
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .hinge-groove {
          width: 240px;
          height: 4px;
          border-radius: 2px;
          background: #090a0f;
        }

        /* Bottom Viewport: 592 x 516 logical px matching AYN Thor bottom touchscreen */
        .bottom-viewport {
          width: 592px;
          height: 516px;
          border-radius: 12px;
          background: var(--ts-bg-canvas);
          border: 2px solid var(--ts-border-subtle);
          overflow: hidden;
          display: flex;
          flex-direction: column;
          position: relative;
          box-shadow: inset 0 0 20px rgba(0, 0, 0, 0.6);
        }

        .bottom-screen-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 10px 16px;
          background: var(--ts-bg-surface);
          border-bottom: 1px solid var(--ts-border-subtle);
          font-size: 13px;
        }

        .bottom-title {
          display: flex;
          align-items: center;
          gap: 8px;
          font-weight: 700;
        }

        .dpad-icon {
          color: var(--ts-accent-cyan);
          font-size: 14px;
        }

        .bottom-search-chip {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          padding: 3px 8px;
          border-radius: 6px;
          background: rgba(255, 255, 255, 0.08);
          font-family: var(--ts-font-mono);
          font-size: 11px;
          color: var(--ts-text-secondary);
        }

        .bottom-grid-container {
          flex-grow: 1;
          overflow-y: auto;
          display: flex;
        }
      `}</style>
    </div>
  );
}

// 5. Second-most important classes/functions
// (none)

// 6. At the end, we find utility functions, helpers
// (none)
