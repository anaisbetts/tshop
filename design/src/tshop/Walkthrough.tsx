import { useState } from 'react'

import { Browse } from './Browse.tsx'
import type { Entry } from './catalog.ts'
import type { Canvas, Mode } from './Chrome.tsx'
import { Detail } from './Detail.tsx'
import { Library } from './Library.tsx'
import { DESTINATIONS, type Destination } from './nav.ts'
import { Settings } from './Settings.tsx'

/**
 * All screens behind one keyboard: arrows move, Enter opens, Escape backs out,
 * [ / ] are L / R, Y commits a sample search, X clears it.
 */
export function Walkthrough({ canvas = 'thor', mode = 'day' }: { canvas?: Canvas; mode?: Mode }) {
  const [destination, setDestination] = useState<Destination>('browse')
  const [detail, setDetail] = useState<Entry | null>(null)
  const [query, setQuery] = useState<string | undefined>()

  function switchBy(step: number) {
    const index = DESTINATIONS.indexOf(destination)
    setDestination(DESTINATIONS[(index + step + DESTINATIONS.length) % DESTINATIONS.length])
  }

  if (detail) return <Detail key={detail.id} entry={detail} canvas={canvas} mode={mode} onBack={() => setDetail(null)} />

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
      return <Settings key="settings" canvas={canvas} mode={mode} onSwitch={switchBy} />
    default: {
      const never: never = destination
      return never
    }
  }
}
