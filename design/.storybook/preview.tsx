import type { Preview } from '@storybook/react-vite'

const preview: Preview = {
  parameters: {
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