import './tshop-theme.css';

// 2. Constants
const STATUS_COLORS: Record<string, string> = {
  online: 'var(--ts-accent-cyan)',
  offline: 'var(--ts-text-muted)',
  probing: 'var(--ts-accent-amber)',
  error: 'var(--ts-accent-red)',
};

// 3. Types and Interfaces
export type ReachabilityStatus = 'online' | 'offline' | 'probing' | 'error';

export interface ConsoleHeaderProps {
  title: string;
  activeTab?: 'browse' | 'library' | 'settings';
  onTabChange?: (tab: 'browse' | 'library' | 'settings') => void;
  status?: ReachabilityStatus;
  libraryBadgeCount?: number;
  batteryPercentage?: number;
  timeString?: string;
}

// 4. The most important class / function in the file - the theme of what this file is about
export function ConsoleHeader({
  title = 'tShop',
  activeTab = 'browse',
  onTabChange,
  status = 'online',
  libraryBadgeCount = 2,
  batteryPercentage = 84,
  timeString = '14:28',
}: ConsoleHeaderProps) {
  return (
    <header className="ts-console-header">
      <div className="ts-header-left">
        <div className="ts-header-brand">
          <span className="ts-logo-box">t</span>
          <span className="ts-header-title">{title}</span>
        </div>

        <nav className="ts-header-tabs" aria-label="Console Navigation">
          <button
            type="button"
            className={`ts-tab-btn ${activeTab === 'browse' ? 'is-active' : ''}`}
            onClick={() => onTabChange?.('browse')}
          >
            Browse
          </button>
          <button
            type="button"
            className={`ts-tab-btn ${activeTab === 'library' ? 'is-active' : ''}`}
            onClick={() => onTabChange?.('library')}
          >
            Library
            {libraryBadgeCount > 0 && (
              <span className="ts-tab-badge" aria-label={`${libraryBadgeCount} updates available`}>
                {libraryBadgeCount}
              </span>
            )}
          </button>
          <button
            type="button"
            className={`ts-tab-btn ${activeTab === 'settings' ? 'is-active' : ''}`}
            onClick={() => onTabChange?.('settings')}
          >
            Settings
          </button>
        </nav>
      </div>

      <div className="ts-header-right">
        {/* Reachability Probe 3DS Bitmapped Wi-Fi Icon */}
        <div
          className="ts-status-indicator"
          title={`Reachability Probe: ${status.toUpperCase()} (catalog verified)`}
        >
          {render3DSWifiGlyph(status)}
        </div>

        {/* Battery Indicator */}
        <div className="ts-battery-indicator" title={`Battery: ${batteryPercentage}%`}>
          <div className="ts-battery-shell">
            <div
              className="ts-battery-fill"
              style={{ width: `${Math.min(100, Math.max(0, batteryPercentage))}%` }}
            />
          </div>
          <span className="ts-battery-text">{batteryPercentage}%</span>
        </div>

        {/* Console Clock */}
        <div className="ts-header-time">{timeString}</div>
      </div>

      <style>{`
        .ts-console-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          height: 48px;
          padding: 0 16px;
          background: rgba(18, 20, 30, 0.88);
          backdrop-filter: blur(12px);
          border-bottom: 1px solid var(--ts-border-subtle);
          color: var(--ts-text-primary);
          user-select: none;
        }

        .ts-header-left {
          display: flex;
          align-items: center;
          gap: 20px;
        }

        .ts-header-brand {
          display: flex;
          align-items: center;
          gap: 8px;
        }

        .ts-logo-box {
          display: flex;
          align-items: center;
          justify-content: center;
          width: 24px;
          height: 24px;
          border-radius: 6px;
          background: linear-gradient(135deg, var(--ts-accent-cyan), var(--ts-accent-purple));
          color: #0c0d14;
          font-family: var(--ts-font-display);
          font-weight: 800;
          font-size: 15px;
          box-shadow: 0 0 10px rgba(0, 240, 255, 0.4);
        }

        .ts-header-title {
          font-weight: 700;
          font-size: 16px;
          letter-spacing: -0.3px;
        }

        .ts-header-tabs {
          display: flex;
          gap: 4px;
          background: rgba(0, 0, 0, 0.3);
          padding: 3px;
          border-radius: 8px;
          border: 1px solid rgba(255, 255, 255, 0.05);
        }

        .ts-tab-btn {
          position: relative;
          display: inline-flex;
          align-items: center;
          gap: 6px;
          padding: 4px 12px;
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

        .ts-tab-btn:hover {
          color: var(--ts-text-primary);
          background: rgba(255, 255, 255, 0.05);
        }

        .ts-tab-btn.is-active {
          color: #ffffff;
          background: var(--ts-accent-purple);
          box-shadow: 0 0 10px rgba(157, 78, 221, 0.5);
        }

        .ts-tab-badge {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          min-width: 16px;
          height: 16px;
          padding: 0 4px;
          border-radius: 9999px;
          background: var(--ts-accent-magenta);
          color: #ffffff;
          font-size: 10px;
          font-weight: 700;
        }

        .ts-header-right {
          display: flex;
          align-items: center;
          gap: 14px;
          font-family: var(--ts-font-mono);
          font-size: 12px;
          color: var(--ts-text-secondary);
        }

        .ts-status-indicator {
          display: flex;
          align-items: center;
        }

        .ts-battery-indicator {
          display: flex;
          align-items: center;
          gap: 5px;
        }

        .ts-battery-shell {
          width: 22px;
          height: 11px;
          border: 1px solid var(--ts-text-secondary);
          border-radius: 2px;
          padding: 1px;
          position: relative;
        }

        .ts-battery-shell::after {
          content: '';
          position: absolute;
          right: -3px;
          top: 2px;
          width: 2px;
          height: 5px;
          background: var(--ts-text-secondary);
          border-radius: 0 1px 1px 0;
        }

        .ts-battery-fill {
          height: 100%;
          background: var(--ts-accent-green);
          border-radius: 1px;
        }

        .ts-header-time {
          font-weight: 700;
          color: var(--ts-text-primary);
        }
      `}</style>
    </header>
  );
}

// 5. Second-most important classes/functions
// (none)

// 6. At the end, we find utility functions, helpers
function render3DSWifiGlyph(status: ReachabilityStatus) {
  const color = STATUS_COLORS[status] || STATUS_COLORS.online;
  return (
    <svg
      width="20"
      height="16"
      viewBox="0 0 20 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-label={`Wi-Fi status: ${status}`}
    >
      {/* 3DS bitmapped stepped waves */}
      <circle cx="10" cy="14" r="2" fill={color} />
      <path
        d="M6 10C7.2 8.8 8.5 8.2 10 8.2C11.5 8.2 12.8 8.8 14 10"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        opacity={status === 'offline' ? 0.2 : 1}
      />
      <path
        d="M2 6C4.4 3.8 7.1 2.5 10 2.5C12.9 2.5 15.6 3.8 18 6"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        opacity={status === 'offline' ? 0.15 : 1}
      />
    </svg>
  );
}
