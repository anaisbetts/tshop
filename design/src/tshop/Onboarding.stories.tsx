import type { Meta, StoryObj } from '@storybook/react-vite'

import { Onboarding } from './Onboarding.tsx'

const meta = {
  title: 'tShop Theme/Onboarding',
  component: Onboarding,
  parameters: { layout: 'centered' },
  args: { canvas: 'thor', mode: 'day', step: 'welcome' },
  argTypes: {
    canvas: { control: 'inline-radio', options: ['thor', 'square'] },
    mode: { control: 'inline-radio', options: ['day', 'night'] },
    step: { control: 'inline-radio', options: ['welcome', 'install', 'notifications'] },
  },
} satisfies Meta<typeof Onboarding>

export default meta

type Story = StoryObj<typeof meta>

export const Welcome: Story = {}

export const WelcomeNight: Story = { args: { mode: 'night' } }

/** Android 8+: a per-app toggle inside Android Settings. */
export const InstallUnknownApps: Story = { args: { step: 'install' } }

export const InstallUnknownAppsAllowed: Story = { args: { step: 'install', granted: ['install'] } }

/** Android 13+: a runtime permission, so Android shows its own prompt. */
export const Notifications: Story = { args: { step: 'notifications', granted: ['install'] } }

export const NotificationsAllowed: Story = { args: { step: 'notifications', granted: ['install', 'notifications'], mode: 'night' } }

/** Shown again only when a needed permission was revoked and is about to be used. */
export const RevokedInstallPermission: Story = { args: { revoked: { permission: 'install', forApp: 'Shattered Pixel Dungeon' } } }

export const RevokedNotifications: Story = { args: { revoked: { permission: 'notifications', forApp: 'update notices' }, mode: 'night' } }

export const Square: Story = { args: { canvas: 'square' } }

export const SquareInstall: Story = { args: { canvas: 'square', step: 'install', mode: 'night' } }
