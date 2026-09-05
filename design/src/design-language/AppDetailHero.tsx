import './tshop-theme.css';

// 2. Constants
const PRIMARY_ACTION_LABELS = {
  install: 'Install',
  update: 'Update Available',
  open: 'Open',
  retry: 'Retry Install',
  landing: 'Go to Publisher',
  mismatch: 'Uninstall Other Source',
};

// 3. Types and Interfaces
export type PrimaryActionType =
  | 'install'
  | 'update'
  | 'open'
  | 'retry'
  | 'landing'
  | 'mismatch';

export interface AppDetailHeroProps {
  name: string;
  category: string;
  version: string;
  author: string;
  summary: string;
  primaryAction: PrimaryActionType;
  iconBg: string;
  iconSymbol: string;
  isDownloading?: boolean;
  downloadProgress?: number;
  onPrimaryAction?: () => void;
  onSecondaryAction?: () => void;
}

// 4. The most important class / function in the file - the theme of what this file is about
export function AppDetailHero({
  name,
  category,
  version,
  author,
  summary,
  primaryAction = 'install',
  iconBg,
  iconSymbol,
  isDownloading = false,
  downloadProgress = 45,
  onPrimaryAction,
  onSecondaryAction,
}: AppDetailHeroProps) {
  const actionLabel = PRIMARY_ACTION_LABELS[primaryAction] || 'Install';

  return (
    <div className="ts-detail-hero">
      <div className="ts-hero-background-gradient" />

      <div className="ts-hero-content">
        <div className="ts-hero-icon" style={{ background: iconBg }}>
          <div className="ts-hero-icon-shine" />
          <span className="ts-hero-symbol">{iconSymbol}</span>
        </div>

        <div className="ts-hero-info">
          <div className="ts-hero-tags">
            <span className="ts-tag ts-tag--category">{category}</span>
            <span className="ts-tag ts-tag--version">v{version}</span>
            <span className="ts-tag ts-tag--author">{author}</span>
          </div>

          <h1 className="ts-hero-title">{name}</h1>
          <p className="ts-hero-summary">{summary}</p>

          <div className="ts-hero-actions">
            {isDownloading ? (
              <div className="ts-download-progress-bar">
                <div
                  className="ts-download-fill"
                  style={{ width: `${downloadProgress}%` }}
                />
                <span className="ts-download-text">Downloading… {downloadProgress}%</span>
              </div>
            ) : (
              <button
                type="button"
                className={`ts-primary-btn ts-primary-btn--${primaryAction}`}
                onClick={onPrimaryAction}
              >
                {actionLabel}
              </button>
            )}

            <button
              type="button"
              className="ts-secondary-btn"
              onClick={onSecondaryAction}
            >
              Changelog & Notes
            </button>
          </div>
        </div>
      </div>

      <style>{`
        .ts-detail-hero {
          position: relative;
          padding: 24px;
          border-radius: 16px;
          background: rgba(24, 26, 38, 0.7);
          border: 1px solid var(--ts-border-subtle);
          overflow: hidden;
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.35);
        }

        .ts-hero-background-gradient {
          position: absolute;
          top: -50px;
          right: -50px;
          width: 250px;
          height: 250px;
          border-radius: 50%;
          background: radial-gradient(circle, rgba(157, 78, 221, 0.25) 0%, rgba(0, 240, 255, 0.05) 50%, transparent 70%);
          filter: blur(40px);
          pointer-events: none;
        }

        .ts-hero-content {
          position: relative;
          display: flex;
          align-items: flex-start;
          gap: 20px;
        }

        .ts-hero-icon {
          position: relative;
          width: 96px;
          height: 96px;
          border-radius: 20px;
          display: flex;
          align-items: center;
          justify-content: center;
          flex-shrink: 0;
          box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
          border: 1px solid rgba(255, 255, 255, 0.2);
          overflow: hidden;
        }

        .ts-hero-icon-shine {
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          height: 45%;
          background: linear-gradient(180deg, rgba(255, 255, 255, 0.3) 0%, rgba(255, 255, 255, 0) 100%);
        }

        .ts-hero-symbol {
          font-family: var(--ts-font-mono);
          font-weight: 800;
          font-size: 32px;
          color: #ffffff;
        }

        .ts-hero-info {
          display: flex;
          flex-direction: column;
          gap: 6px;
          flex-grow: 1;
        }

        .ts-hero-tags {
          display: flex;
          align-items: center;
          gap: 8px;
        }

        .ts-tag {
          font-family: var(--ts-font-mono);
          font-size: 11px;
          font-weight: 600;
          padding: 2px 8px;
          border-radius: 6px;
          background: rgba(255, 255, 255, 0.08);
          color: var(--ts-text-secondary);
        }

        .ts-tag--category {
          color: var(--ts-accent-cyan);
          background: rgba(0, 240, 255, 0.1);
        }

        .ts-hero-title {
          margin: 0;
          font-family: var(--ts-font-display);
          font-size: 24px;
          font-weight: 800;
          color: var(--ts-text-primary);
          letter-spacing: -0.5px;
        }

        .ts-hero-summary {
          margin: 0;
          font-size: 13px;
          line-height: 1.4;
          color: var(--ts-text-secondary);
          max-width: 520px;
        }

        .ts-hero-actions {
          display: flex;
          align-items: center;
          gap: 12px;
          margin-top: 10px;
        }

        .ts-primary-btn {
          padding: 8px 20px;
          border-radius: 8px;
          border: none;
          font-family: var(--ts-font-display);
          font-weight: 700;
          font-size: 13px;
          cursor: pointer;
          transition: all 0.2s ease;
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        }

        .ts-primary-btn--install {
          background: linear-gradient(135deg, var(--ts-accent-cyan), #0284c7);
          color: #0c0d14;
        }

        .ts-primary-btn--update {
          background: linear-gradient(135deg, var(--ts-accent-magenta), #c026d3);
          color: #ffffff;
        }

        .ts-primary-btn--open {
          background: linear-gradient(135deg, var(--ts-accent-green), #059669);
          color: #ffffff;
        }

        .ts-primary-btn--landing {
          background: linear-gradient(135deg, var(--ts-accent-amber), #d97706);
          color: #0c0d14;
        }

        .ts-primary-btn--mismatch {
          background: linear-gradient(135deg, var(--ts-accent-red), #b91c1c);
          color: #ffffff;
        }

        .ts-primary-btn:hover {
          transform: translateY(-1px);
          filter: brightness(1.1);
        }

        .ts-primary-btn:focus-visible {
          outline: 2px solid #ffffff;
          outline-offset: 2px;
        }

        .ts-secondary-btn {
          padding: 8px 16px;
          border-radius: 8px;
          border: 1px solid var(--ts-border-subtle);
          background: rgba(255, 255, 255, 0.05);
          color: var(--ts-text-primary);
          font-family: var(--ts-font-display);
          font-weight: 600;
          font-size: 13px;
          cursor: pointer;
          transition: background 0.2s ease;
        }

        .ts-secondary-btn:hover {
          background: rgba(255, 255, 255, 0.12);
        }

        .ts-download-progress-bar {
          position: relative;
          width: 180px;
          height: 34px;
          border-radius: 8px;
          background: rgba(0, 0, 0, 0.4);
          border: 1px solid var(--ts-border-subtle);
          overflow: hidden;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .ts-download-fill {
          position: absolute;
          left: 0;
          top: 0;
          bottom: 0;
          background: linear-gradient(90deg, var(--ts-accent-cyan), var(--ts-accent-purple));
          transition: width 0.3s ease;
        }

        .ts-download-text {
          position: relative;
          z-index: 1;
          font-family: var(--ts-font-mono);
          font-size: 11px;
          font-weight: 700;
          color: #ffffff;
        }
      `}</style>
    </div>
  );
}

// 5. Second-most important classes/functions
// (none)

// 6. At the end, we find utility functions, helpers
// (none)
