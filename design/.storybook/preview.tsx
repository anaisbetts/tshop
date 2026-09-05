import type { Decorator, Preview } from '@storybook/react-vite'
import '../src/design-language/tshop-theme.css'

const TSHOP_BACKGROUNDS = {
  dark: { name: 'dark', value: '#0c0d14' },
  light: { name: 'light', value: '#f1f5f9' },
} as const

type TshopTheme = 'dark' | 'light'

const preview: Preview = {
  decorators: [withTshopTheme],
  initialGlobals: {
    backgrounds: { value: 'dark' },
  },
  parameters: {
    backgrounds: {
      options: TSHOP_BACKGROUNDS,
    },

    controls: {
      matchers: {
       color: /(background|color)$/i,
       date: /Date$/i,
      },
    },

    viewport: {
      viewports: {
        aynThorTop: {
          name: 'AYN Thor - Top Screen (6.0" 16:9 @ ~367 dpi)',
          styles: {
            width: '837px',
            height: '471px',
          },
          type: 'tablet',
        },
        aynThorBottom: {
          name: 'AYN Thor - Bottom Screen (3.92" 31:27 @ ~335 dpi)',
          styles: {
            width: '592px',
            height: '516px',
          },
          type: 'mobile',
        },
        aynThorBottomAlt: {
          name: 'AYN Thor - Bottom Screen (Logical 541x471 match)',
          styles: {
            width: '541px',
            height: '471px',
          },
          type: 'mobile',
        },
        retroid43: {
          name: 'Retroid Pocket (4:3 Handheld)',
          styles: {
            width: '640px',
            height: '480px',
          },
          type: 'mobile',
        },
        odin2: {
          name: 'AYN Odin 2 (16:9 Handheld 1080p)',
          styles: {
            width: '854px',
            height: '480px',
          },
          type: 'tablet',
        },
      },
    },

    a11y: {
      // 'todo' - show a11y violations in the test UI only
      // 'error' - fail CI on a11y violations
      // 'off' - skip a11y checks entirely
      test: 'todo'
    }
  },
};

export default preview;

function withTshopTheme(Story: Parameters<Decorator>[0], context: Parameters<Decorator>[1]) {
  const theme = tshopThemeFromBackgrounds(context.globals.backgrounds)

  return (
    <div className="tshop-theme" data-theme={theme}>
      <Story />
    </div>
  )
}

function tshopThemeFromBackgrounds(backgrounds: unknown): TshopTheme {
  if (typeof backgrounds === 'string') {
    return backgrounds === 'light' ? 'light' : 'dark'
  }

  if (backgrounds && typeof backgrounds === 'object' && 'value' in backgrounds) {
    return (backgrounds as { value?: string }).value === 'light' ? 'light' : 'dark'
  }

  return 'dark'
}
