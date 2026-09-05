import './tshop-theme.css';

// 2. Constants
const GLYPH_MAP: Record<string, string> = {
  a: 'A',
  b: 'B',
  x: 'X',
  y: 'Y',
  l1: 'L1',
  r1: 'R1',
  l2: 'L2',
  r2: 'R2',
  start: 'START',
  select: 'SELECT',
  dpad: '✚',
};

// 3. Types and Interfaces
export type PromptButton =
  | 'a'
  | 'b'
  | 'x'
  | 'y'
  | 'l1'
  | 'r1'
  | 'l2'
  | 'r2'
  | 'start'
  | 'select'
  | 'dpad';

export interface ControllerPromptItem {
  button: PromptButton;
  label: string;
}

export interface ControllerHintsProps {
  prompts: ControllerPromptItem[];
  theme?: 'dark' | 'light';
  layout?: 'nintendo' | 'xbox';
}

// 4. The most important class / function in the file - the theme of what this file is about
export function ControllerHints({
  prompts,
  theme,
  layout = 'nintendo',
}: ControllerHintsProps) {
  return (
    <footer
      className="ts-controller-hints"
      data-theme={theme}
      data-layout={layout}
      aria-label="Controller navigation shortcuts"
    >
      <div className="ts-hints-container">
        {prompts.map((prompt, index) => (
          <div key={`${prompt.button}-${index}`} className="ts-hint-item">
            <span
              className={`ts-button-glyph ts-button-glyph--${prompt.button}`}
              aria-hidden="true"
            >
              {GLYPH_MAP[prompt.button] || prompt.button.toUpperCase()}
            </span>
            <span className="ts-hint-label">{prompt.label}</span>
          </div>
        ))}
      </div>

      <style>{`
        .ts-controller-hints {
          display: flex;
          align-items: center;
          padding: 8px 16px;
          background: var(--ts-bg-surface);
          backdrop-filter: blur(8px);
          border-top: 1px solid var(--ts-border-subtle);
          font-family: var(--ts-font-display);
          font-size: 13px;
          color: var(--ts-text-secondary);
        }

        .ts-hints-container {
          display: flex;
          flex-wrap: wrap;
          align-items: center;
          gap: 16px;
        }

        .ts-hint-item {
          display: inline-flex;
          align-items: center;
          gap: 6px;
        }

        .ts-button-glyph {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          min-width: 20px;
          height: 20px;
          padding: 0 4px;
          border-radius: 9999px;
          font-family: var(--ts-font-mono);
          font-size: 11px;
          font-weight: 700;
          line-height: 1;
          color: #ffffff;
          background: #334155;
          border: 1px solid rgba(255, 255, 255, 0.2);
          box-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
        }

        .ts-button-glyph--a {
          background: #ef4444; /* Nintendo Red A */
        }

        .ts-button-glyph--b {
          background: #eab308; /* Nintendo Yellow B */
        }

        .ts-button-glyph--x {
          background: #3b82f6; /* Nintendo Blue X */
        }

        .ts-button-glyph--y {
          background: #10b981; /* Nintendo Green Y */
        }

        .ts-button-glyph--l1,
        .ts-button-glyph--r1,
        .ts-button-glyph--l2,
        .ts-button-glyph--r2 {
          border-radius: 4px;
          background: #475569;
          font-size: 10px;
        }

        .ts-button-glyph--start,
        .ts-button-glyph--select {
          border-radius: 4px;
          background: #1e293b;
          font-size: 9px;
        }

        .ts-hint-label {
          font-weight: 500;
          color: var(--ts-text-primary);
        }
      `}</style>
    </footer>
  );
}

// 5. Second-most important classes/functions
// (none)

// 6. At the end, we find utility functions, helpers
// (none)
