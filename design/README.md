# design

Storybook-only visual playground for tShop UI, separate from the Flutter client.
No standalone app lives here; Vite powers Storybook and its browser tests.

```bash
bun install
bun dev
```

Storybook serves at <http://localhost:6006>. `bun run storybook` is an alias.

```bash
bun run build      # Type-check and build Storybook into storybook-static/
bun run typecheck  # Check components, stories, and configuration
bun run lint
bun run test       # Run Storybook browser tests (requires Playwright Chromium)
```

Install the browser once with `bunx playwright install chromium`.
`bun run build-storybook` is an alias for the same checked Storybook build.
The npm equivalents (`npm install`, `npm run dev`, etc.) also work.

The current theme study lives in `src/tshop/` under **tShop Theme** in the
sidebar. Start with **Overview**, then **Walkthrough** for keyboard
navigation.
