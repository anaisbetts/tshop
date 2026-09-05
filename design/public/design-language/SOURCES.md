# Design language study — asset credits

This is an iiSU / Nintendo 3DS-inspired visual study, not an approved tShop
catalog. Names, descriptions, device compatibility, installation state, and
progress are illustrative. No downloads or launches occur.

The reference image is `design/inspo/iisu-is-ambitious-as-hell-lets-see-how-it-goes-v0-zvxmvjycfg3g1.jpg`.
It is inspiration only, not bundled into the rendered page. Its mixed-size tiles
are deliberately replaced with the square, category-framed grid in `specs/02-screens.md`.

## Fonts

Self-hosted via `@fontsource-variable/nunito`; no runtime font requests leave
Storybook.

- **Nunito Variable**, by Vernon Adams, Cyreal, Jacques Le Bailly — SIL Open
  Font License. Display, body, legends, and numerals.
  https://github.com/google/fonts/tree/main/ofl/nunito

## App artwork

Local copies from the official repositories below, fetched for this study.
Project names and marks belong to their respective owners. Use here identifies
the apps, not endorsement. Repository licenses do not necessarily license
trademarks; this is source attribution, **not a completed production artwork
rights audit**. Complete that per-entry audit before reusing these in a shipped catalog.

Paths are relative to `https://github.com/<repository>/blob/HEAD/`.

| Local file | Repository | Source path |
|---|---|---|
| dolphin.png | dolphin-emu/dolphin | Source/Android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png |
| ppsspp.png | hrydgard/ppsspp | android/normal/res/mipmap-xxxhdpi/ic_launcher.png |
| retroarch.png | libretro/RetroArch | media/icons/playstore/icon.png |
| melonds.png | rafaelvcaetano/melonDS-android | app/src/main/res/mipmap-xxxhdpi/ic_launcher.png |
| flycast.png | flyinghead/flycast | shell/apple/emulator-osx/emulator-osx/Images.xcassets/AppIcon.appiconset/Icon-256.png |
| lemuroid.png | Swordfish90/Lemuroid | lemuroid-app/src/main/res/mipmap-xxxhdpi/lemuroid_launcher.png |
| scummvm.png | scummvm/scummvm | dists/android/store/scummvm_icon_512.png |
| vita3k.png | Vita3K/Vita3K | android/app/src/main/res/mipmap/ic_launcher.png |
| supertuxkart.png | supertuxkart/stk-code | android/icon.png |
| mindustry.png | Anuken/Mindustry | android/res/mipmap-xxxhdpi/ic_launcher.png |
| pixel-dungeon.png | 00-Evan/shattered-pixel-dungeon | android/src/main/res/mipmap-xxxhdpi/ic_launcher.png |
| unciv.png | yairm210/Unciv | android/res/mipmap-xxxhdpi/uncivicon.png |
| moonlight.png | moonlight-stream/moonlight-android | app/src/main/res/mipmap-xxxhdpi/ic_launcher.png |
| syncthing.png | syncthing/syncthing | assets/logo-256.png |
| amaze.png | TeamAmaze/AmazeFileManager | app/src/main/res/mipmap-xxxhdpi/ic_launcher.png |

## Scope

The live grid uses keyboard arrows / Enter / Escape and pointer/touch input.
Controller glyphs model the future handheld affordances; a physical Gamepad API
adapter is not part of this Storybook study. Shoulder navigation and download
progress are isolated state specimens, not a working Library or installer.

The offline control simulates catalog reachability; it is not a network probe.
Privacy Mode models the setting only. All artwork and fonts remain local.
