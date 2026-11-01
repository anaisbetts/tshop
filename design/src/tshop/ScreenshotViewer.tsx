import { useEffect, useRef, useState, type KeyboardEvent } from 'react'

import { DETAIL_ART, type Entry } from './catalog.ts'
import { Legend, Pad, Screen, StatusCluster, type Canvas, type Mode } from './Chrome.tsx'

export type ScreenshotViewerProps = {
  entry: Entry
  canvas?: Canvas
  mode?: Mode
  online?: boolean
  initialIndex?: number
  onBack?: () => void
}

/** Fullscreen from the Detail strip. Left / right page through the set; Back returns to Detail. */
export function ScreenshotViewer({ entry, canvas = 'thor', mode = 'day', online = true, initialIndex = 0, onBack }: ScreenshotViewerProps) {
  const shots = DETAIL_ART[entry.id]?.shots ?? []
  const [index, setIndex] = useState(Math.min(initialIndex, Math.max(0, shots.length - 1)))
  const rootRef = useRef<HTMLDivElement>(null)
  const shot = shots[index]

  useEffect(() => {
    rootRef.current?.focus({ preventScroll: true })
  }, [])

  function page(step: number) {
    setIndex((value) => Math.min(shots.length - 1, Math.max(0, value + step)))
  }

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    switch (event.key) {
      case 'ArrowLeft':
      case '[':
        page(-1)
        break
      case 'ArrowRight':
      case ']':
        page(1)
        break
      case 'Escape':
      case 'Backspace':
        onBack?.()
        break
      default:
        return
    }
    event.preventDefault()
  }

  return (
    <Screen canvas={canvas} mode={mode} onKeyDown={onKeyDown} rootRef={rootRef}>
      <div className="ts-viewer">
        {shot ? <img className="ts-viewer__blur" src={shot} alt="" aria-hidden="true" /> : null}
        {shot ? <img className="ts-viewer__shot" src={shot} alt={`${entry.name} screenshot ${index + 1}`} /> : null}
        <header className="ts-viewer__bar">
          <span className="ts-viewer__pill">
            {entry.name}
            <span className="ts-viewer__count">
              {index + 1} / {shots.length}
            </span>
          </span>
          <span className="ts-viewer__pill ts-viewer__pill--status">
            <StatusCluster online={online} />
          </span>
        </header>
        <button type="button" className="ts-viewer__arrow ts-viewer__arrow--prev" disabled={index === 0} onClick={() => page(-1)} tabIndex={-1}>
          <Pad button="L" />
        </button>
        <button
          type="button"
          className="ts-viewer__arrow ts-viewer__arrow--next"
          disabled={index === shots.length - 1}
          onClick={() => page(1)}
          tabIndex={-1}
        >
          <Pad button="R" />
        </button>
        <footer className="ts-viewer__foot">
          <span className="ts-viewer__dots" aria-hidden="true">
            {shots.map((item, n) => (
              <span key={item} className={n === index ? 'is-on' : undefined} />
            ))}
          </span>
          <span className="ts-viewer__pill">
            <Legend left={[{ button: 'dpad', label: 'Page' }]} right={[{ button: 'B', label: 'Back' }]} />
          </span>
        </footer>
      </div>
    </Screen>
  )
}
