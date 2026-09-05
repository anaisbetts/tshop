import type { ReactNode } from 'react'

export function DeviceFrame({ children }: { children: ReactNode }) {
  return <div className="tshop-device tshop-dots">{children}</div>
}
