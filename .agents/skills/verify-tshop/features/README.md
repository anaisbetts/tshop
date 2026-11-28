# tShop verification map

This directory is the maintained source for verifying the user-facing behavior of tShop. Read the index before driving the app, then use the matching feature file as the recipe.

## Baseline preconditions

- Launch tShop with `.cursor/skills/verify-tshop/bin/control-tshop launch`.
- Doctor must report `url=http://127.0.0.1:4173/` (or the `TSHOP_VERIFY_PORT` you launched) and `web_dir` ending in `client/build/web`.
- Never drive an instance that was not started by this verification run.
- No catalog is seeded. The only implemented destination is `/`.

## Driving conventions

- Start every recipe from the baseline state unless its preconditions say otherwise.
- Prefer the route `/`, the visible AppBar text `tShop`, and `document.title` over coordinates or canvas pixel guesses.
- Treat every command as literal. Keep quoted names and flags unchanged.
- Run process control through `control-tshop`. Run page actions in the Cursor browser / Chromium against `control-tshop url`.
- Cleanup stops the server this run started. Do not remove proof artifacts.

## Proof and skip reporting

- Capture the user action and the resulting state, not only the final screen.
- UI proof includes a screenshot with the AppBar title `tShop` visible, plus a recorded `document.title` and URL.
- Record the feature ID and entry point used with every artifact.
- Report an unreachable path with the attempted command and the unmet precondition.
- Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behavior. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behavior.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with control-tshop` starts with `Preconditions:` and uses labeled bullets that pair each user action with an exact command and observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

Keep implementation details out of the map. Name only user paths, stable handles, required state, commands, and observable proof.

## Features

- [Home identity](./home.md) covers the placeholder storefront at `/`.

## Not implemented

These destinations are specified in `specs/02-screens.md` and have no route, widget, or selector yet. If the screen is only an AppBar titled `tShop`, they are not there. Do not invent tiles, tabs, or settings rows.

- Browse (category tile grid, search)
- App Detail and screenshot viewer
- Library (queue, updates, update all)
- Settings and About
- Onboarding / permissions
