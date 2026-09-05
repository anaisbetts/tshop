import './tshop-theme.css';

// 2. Constants
const BADGE_COLORS = {
  update: {
    bg: 'var(--ts-accent-magenta)',
    text: '#ffffff',
    label: 'UPDATE',
  },
  installed: {
    bg: 'rgba(16, 185, 129, 0.25)',
    text: 'var(--ts-accent-green)',
    label: 'INSTALLED',
  },
  landing: {
    bg: 'rgba(245, 158, 11, 0.25)',
    text: 'var(--ts-accent-amber)',
    label: 'PUBLISHER',
  },
  incompatible: {
    bg: 'rgba(239, 68, 68, 0.25)',
    text: 'var(--ts-accent-red)',
    label: 'UNMET',
  },
};

// 3. Types and Interfaces
export type TileBadge = 'update' | 'installed' | 'landing' | 'incompatible' | 'none';

export interface AppTileData {
  id: string;
  name: string;
  category: string;
  version: string;
  iconBg: string;
  iconSymbol: string;
  badge?: TileBadge;
  isGreyed?: boolean;
  downloadsRecent?: number;
  unmetCapability?: string;
}

export interface AppTileProps {
  app: AppTileData;
  isFocused?: boolean;
  isSelected?: boolean;
  onSelect?: (app: AppTileData) => void;
  onFocus?: (app: AppTileData) => void;
}

// 4. The most important class / function in the file - the theme of what this file is about
export function AppTile({
  app,
  isFocused = false,
  isSelected = false,
  onSelect,
  onFocus,
}: AppTileProps) {
  const badgeInfo = app.badge && app.badge !== 'none' ? BADGE_COLORS[app.badge] : null;

  return (
    <button
      type="button"
      className={`ts-app-tile ${isFocused ? 'is-focused' : ''} ${isSelected ? 'is-selected' : ''} ${
        app.isGreyed ? 'is-greyed' : ''
      }`}
      onClick={() => onSelect?.(app)}
      onMouseEnter={() => onFocus?.(app)}
      onFocus={() => onFocus?.(app)}
      tabIndex={0}
      aria-label={`${app.name}, Category: ${app.category}, Version: ${app.version}${
        app.badge ? `, Status: ${app.badge}` : ''
      }`}
    >
      <div className="ts-tile-artwork" style={{ background: app.iconBg }}>
        {/* Subtle grid pattern / 3DS cartridge shine */}
        <div className="ts-tile-shine" />
        <span className="ts-tile-symbol">{app.iconSymbol}</span>

        {badgeInfo && (
          <span
            className="ts-tile-badge"
            style={{ backgroundColor: badgeInfo.bg, color: badgeInfo.text }}
          >
            {badgeInfo.label}
          </span>
        )}
      </div>

      <div className="ts-tile-meta">
        <span className="ts-tile-name" title={app.name}>
          {app.name}
        </span>
        <span className="ts-tile-sub">v{app.version}</span>
      </div>

      <style>{`
        .ts-app-tile {
          display: flex;
          flex-direction: column;
          align-items: center;
          width: 96px;
          padding: 6px;
          border-radius: 14px;
          border: 2px solid transparent;
          background: rgba(255, 255, 255, 0.03);
          cursor: pointer;
          transition: transform 0.15s cubic-bezier(0.2, 0.8, 0.2, 1),
                      border-color 0.15s ease,
                      box-shadow 0.15s ease,
                      background 0.15s ease;
          outline: none;
          user-select: none;
          position: relative;
        }

        .ts-app-tile:hover {
          background: rgba(255, 255, 255, 0.08);
          transform: translateY(-2px);
        }

        /* 3DS/R-Shop Neutral High-Contrast Focus Ring */
        .ts-app-tile.is-focused,
        .ts-app-tile:focus-visible {
          border-color: #ffffff;
          box-shadow: 0 0 0 3px var(--ts-accent-cyan), 0 0 16px rgba(0, 240, 255, 0.5);
          transform: scale(1.06);
          background: rgba(0, 240, 255, 0.1);
          z-index: 2;
        }

        .ts-app-tile.is-greyed {
          opacity: 0.45;
          filter: grayscale(0.8);
        }

        .ts-tile-artwork {
          position: relative;
          width: 80px;
          height: 80px;
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          overflow: hidden;
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
          border: 1px solid rgba(255, 255, 255, 0.15);
        }

        .ts-tile-shine {
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          height: 40%;
          background: linear-gradient(180deg, rgba(255, 255, 255, 0.25) 0%, rgba(255, 255, 255, 0) 100%);
          pointer-events: none;
        }

        .ts-tile-symbol {
          font-family: var(--ts-font-mono);
          font-weight: 800;
          font-size: 26px;
          color: #ffffff;
          text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
        }

        .ts-tile-badge {
          position: absolute;
          top: 4px;
          right: 4px;
          padding: 2px 4px;
          border-radius: 4px;
          font-family: var(--ts-font-mono);
          font-size: 8px;
          font-weight: 700;
          letter-spacing: 0.3px;
          box-shadow: 0 1px 3px rgba(0, 0, 0, 0.5);
        }

        .ts-tile-meta {
          margin-top: 6px;
          width: 100%;
          text-align: center;
          display: flex;
          flex-direction: column;
          gap: 1px;
        }

        .ts-tile-name {
          font-family: var(--ts-font-display);
          font-size: 11px;
          font-weight: 700;
          color: var(--ts-text-primary);
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
          line-height: 1.2;
        }

        .ts-tile-sub {
          font-family: var(--ts-font-mono);
          font-size: 9px;
          color: var(--ts-text-muted);
        }
      `}</style>
    </button>
  );
}

// 5. Second-most important classes/functions
// (none)

// 6. At the end, we find utility functions, helpers
// (none)
