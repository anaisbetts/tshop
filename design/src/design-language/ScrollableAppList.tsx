import { useRef, useState } from 'react';
import { AppTile, type AppTileData } from './AppTile';
import type { CategorySection } from './mockData';
import './tshop-theme.css';

// 2. Constants

// 3. Types and Interfaces
export interface ScrollableAppListProps {
  sections: CategorySection[];
  onSelectApp?: (app: AppTileData) => void;
  onHoverApp?: (app: AppTileData) => void;
  selectedAppId?: string;
}

// 4. The most important class / function in the file - the theme of what this file is about
export function ScrollableAppList({
  sections,
  onSelectApp,
  onHoverApp,
  selectedAppId,
}: ScrollableAppListProps) {
  const [internalFocusedId, setInternalFocusedId] = useState<string>(
    selectedAppId || sections[0]?.apps[0]?.id || ''
  );
  const containerRef = useRef<HTMLDivElement>(null);

  const focusedId = selectedAppId ?? internalFocusedId;

  // Flattened navigation logic for D-Pad keyboard handling
  const allApps = sections.flatMap((sec) => sec.apps);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    const currentIndex = allApps.findIndex((a) => a.id === focusedId);
    if (currentIndex === -1) return;

    if (e.key === 'ArrowRight') {
      e.preventDefault();
      const nextIndex = Math.min(allApps.length - 1, currentIndex + 1);
      const nextApp = allApps[nextIndex];
      if (nextApp) {
        setInternalFocusedId(nextApp.id);
        onHoverApp?.(nextApp);
      }
    } else if (e.key === 'ArrowLeft') {
      e.preventDefault();
      const prevIndex = Math.max(0, currentIndex - 1);
      const prevApp = allApps[prevIndex];
      if (prevApp) {
        setInternalFocusedId(prevApp.id);
        onHoverApp?.(prevApp);
      }
    } else if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      const activeApp = allApps[currentIndex];
      if (activeApp) {
        onSelectApp?.(activeApp);
      }
    }
  };

  return (
    <div
      className="ts-scrollable-app-list"
      ref={containerRef}
      onKeyDown={handleKeyDown}
      tabIndex={0}
      role="region"
      aria-label="3DS Scrollable Category Grid"
    >
      {sections.map((section) => (
        <div key={section.id} className="ts-category-frame">
          <div className="ts-category-header">
            <h3 className="ts-category-title">{section.title}</h3>
            {section.description && (
              <span className="ts-category-desc">{section.description}</span>
            )}
            <span className="ts-category-count">{section.apps.length} items</span>
          </div>

          <div className="ts-category-tiles">
            {section.apps.map((app) => (
              <AppTile
                key={app.id}
                app={app}
                isFocused={focusedId === app.id}
                isSelected={selectedAppId === app.id}
                onSelect={(selected) => {
                  setInternalFocusedId(selected.id);
                  onSelectApp?.(selected);
                }}
                onFocus={(focused) => {
                  setInternalFocusedId(focused.id);
                  onHoverApp?.(focused);
                }}
              />
            ))}
          </div>
        </div>
      ))}

      <style>{`
        .ts-scrollable-app-list {
          display: flex;
          flex-direction: column;
          gap: 20px;
          padding: 16px 20px;
          overflow-y: auto;
          overflow-x: hidden;
          width: 100%;
          height: 100%;
          outline: none;
          scroll-behavior: smooth;
        }

        /* 3DS Formed Category Frame */
        .ts-category-frame {
          background: rgba(255, 255, 255, 0.03);
          border: 1px solid var(--ts-border-subtle);
          border-radius: 16px;
          padding: 14px 16px;
          box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
        }

        .ts-category-header {
          display: flex;
          align-items: baseline;
          gap: 10px;
          margin-bottom: 12px;
          padding-bottom: 8px;
          border-bottom: 1px solid rgba(255, 255, 255, 0.06);
        }

        .ts-category-title {
          margin: 0;
          font-family: var(--ts-font-display);
          font-size: 15px;
          font-weight: 700;
          color: var(--ts-text-primary);
          letter-spacing: -0.2px;
        }

        .ts-category-desc {
          font-size: 12px;
          color: var(--ts-text-muted);
        }

        .ts-category-count {
          margin-left: auto;
          font-family: var(--ts-font-mono);
          font-size: 11px;
          color: var(--ts-accent-cyan);
          background: rgba(0, 240, 255, 0.1);
          padding: 2px 6px;
          border-radius: 4px;
        }

        /* Continuous scrollable horizontal row / grid */
        .ts-category-tiles {
          display: flex;
          flex-wrap: wrap;
          gap: 12px;
          align-items: flex-start;
        }
      `}</style>
    </div>
  );
}

// 5. Second-most important classes/functions
// (none)

// 6. At the end, we find utility functions, helpers
// (none)

