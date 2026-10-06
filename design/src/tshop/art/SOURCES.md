# tShop theme v2 — asset credits

Visual study, not an approved catalog. Names, versions, sizes, dates,
changelog lines, install states, and progress are illustrative.

Project names and marks belong to their owners. This is source attribution,
**not a production artwork rights audit**. Do that per entry before any of
these reach a shipped catalog.

## Font

**M PLUS Rounded 1c** by Coji Morishita and M+ Fonts Project, SIL Open Font
License. Self-hosted through `@fontsource/m-plus-rounded-1c`; Storybook makes
no runtime font requests.

## Tile icons (`icons/`)

Launcher icons copied from Ani's earlier study on `design-fable-grok`
(`design/public/design-language/SOURCES.md` lists each upstream path). These
four were replaced with the 512 px store icon from the F-Droid repository
metadata (`https://f-droid.org/repo/<package>/en-US/icon_*.png`):

| File | Package |
|---|---|
| mindustry.png | io.anuke.mindustry |
| moonlight.png | com.limelight |
| retroarch.png | com.retroarch |
| pixel-dungeon.png | com.shatteredpixel.shatteredpixeldungeon |

Each tile's backdrop colour and icon scale live in `catalog.ts`. They stand in
for the square tile the catalog pipeline would bake.

## Feature graphics and screenshots (`shots/`)

From the F-Droid repository metadata, which mirrors each project's own store
listing. Resized to at most 1280 px and re-encoded as JPEG.

| Files | Package | License of the app |
|---|---|---|
| pixel-dungeon-* | com.shatteredpixel.shatteredpixeldungeon | GPL-3.0-only |
| mindustry-* | io.anuke.mindustry | GPL-3.0-or-later |
| unciv-* | com.unciv.app | MPL-2.0 |
