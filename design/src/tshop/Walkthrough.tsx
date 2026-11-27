import { useState } from 'react'

import { About } from './About.tsx'
import { Browse } from './Browse.tsx'
import type { Entry } from './catalog.ts'
import type { Canvas, Mode } from './Chrome.tsx'
import { Detail } from './Detail.tsx'
import { Library } from './Library.tsx'
import { DESTINATIONS, PadLayoutContext, type Destination, type PadLayout } from './nav.ts'
import { Onboarding } from './Onboarding.tsx'
import { ScreenshotViewer } from './ScreenshotViewer.tsx'
import { Settings } from './Settings.tsx'

/**
 * All screens behind one keyboard: arrows move, Enter opens, Escape backs out,
 * [ / ] are L / R, Y commits a sample search, X clears it.
 */
export function Walkthrough({ canvas = 'thor', mode = 'day', firstLaunch = false }: { canvas?: Canvas; mode?: Mode; firstLaunch?: boolean }) {
  const [onboarding, setOnboarding] = useState(firstLaunch)
  const [destination, setDestination] = useState<Destination>('browse')
  const [detail, setDetail] = useState<Entry | null>(null)
  const [shot, setShot] = useState<number | null>(null)
  const [about, setAbout] = useState(false)
  const [query, setQuery] = useState<string | undefined>()
  const [pad, setPad] = useState<PadLayout>('nintendo')

  function switchBy(step: number) {
    const index = DESTINATIONS.indexOf(destination)
    setDestination(DESTINATIONS[(index + step + DESTINATIONS.length) % DESTINATIONS.length])
  }

  return <PadLayoutContext.Provider value={pad}>{screen()}</PadLayoutContext.Provider>

  function screen() {
    if (onboarding) return <Onboarding canvas={canvas} mode={mode} onFinish={() => setOnboarding(false)} />
    if (detail && shot !== null)
      return <ScreenshotViewer key={`shot-${detail.id}`} entry={detail} canvas={canvas} mode={mode} initialIndex={shot} onBack={() => setShot(null)} />
    if (detail)
      return <Detail key={detail.id} entry={detail} canvas={canvas} mode={mode} onBack={() => setDetail(null)} onShot={setShot} />
    if (about) return <About canvas={canvas} mode={mode} onBack={() => setAbout(false)} />

    switch (destination) {
      case 'browse':
        return (
          <Browse
            key={`browse-${query ?? ''}`}
            canvas={canvas}
            mode={mode}
            query={query}
            onOpen={setDetail}
            onSwitch={switchBy}
            onQuery={setQuery}
          />
        )
      case 'library':
        return <Library key="library" canvas={canvas} mode={mode} onOpen={setDetail} onSwitch={switchBy} />
      case 'settings':
        return <Settings key="settings" canvas={canvas} mode={mode} onSwitch={switchBy} onAbout={() => setAbout(true)} onPadLayout={setPad} />
      default: {
        const never: never = destination
        return never
      }
    }
  }
}
