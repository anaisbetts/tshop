import type { Preview } from '@storybook/react-vite'
import '@fontsource-variable/nunito'
import '../src/design-language/tokens.css'
import '../src/design-language/ui.css'

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    a11y: {
      test: 'todo',
    },
    viewport: {
      options: {
        thorTop: {
          name: 'AYN Thor top (1920×1080 @ 367dpi)',
          styles: { width: '837px', height: '471px' },
          type: 'mobile',
        },
      },
    },
    backgrounds: {
      options: {
        tshop: { name: 'tShop grey', value: '#e9eaee' },
      },
    },
  },
  initialGlobals: {
    viewport: { value: 'thorTop', isRotated: false },
    backgrounds: { value: 'tshop' },
  },
}

export default preview
