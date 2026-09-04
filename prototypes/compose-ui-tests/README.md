# Handheld input prototypes (Compose)

Throwaway Material3 harness matching [prototypes/flutter-ui-tests](../flutter-ui-tests) for [specs/98-prototype-this-first.md](../../specs/98-prototype-this-first.md) items **#2** (controller input) and **#12** (IME shape), plus a stock-widget focus kitchen. Phone Compose only — no `androidx.tv`. Nothing here ships.

## Run

From this folder, with the Android SDK installed:

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
./gradlew installDebug
```

Install on a Retroid, Odin, or Thor. The home screen lists the pages; d-pad should move between the cards.

## #2 Controller input

Press every control on the built-in pad, then one Bluetooth pad.

Record per device × pad:

- Did `KEYCODE_DPAD_*` arrive as DPAD keys?
- Did `AXIS_HAT_X/Y` motion events arrive? If keys are empty and hat stays `none`, Compose never saw the d-pad.
- Hold the d-pad: repeat count and last interval (ms).
- Hold A: does it repeat? 04 wants d-pad repeats and face buttons never.
- Key-up names vs key-down (Thor mismatch).
- Can the stock "Install unknown apps" page be toggled with the d-pad alone? Use the button on this page.

## Focus kitchen

D-pad through stock Material3. No remaps, no Compose TV.

Record per device:

- Can every control take focus, or do some get skipped?
- Do Left/Right follow the 2-column grid?
- Does the text field trap arrow keys?
- Does the slider steal Left/Right?
- Can you enter and leave the expansion and the dialog? Does focus return?
- Is this already better than Flutter, or still worse than Compose TV?

## #12 IME shape

Open the search field. Photograph the screen.

Record per device:

- Verdict on the banner: `DOCKS`, `COVERS`, or `NO IME`.
- Screen size, aspect, IME inset, remaining height.
- Is any catalog tile still visible?
- Can the system IME type a query with the d-pad alone?

If the IME is a fullscreen modal, the Compose view is covered and the photo is the result.

## Gates

- **#2** — whether keys and hat axes reach the app without a plugin, Thor key-up mismatch, Onboarding touch warning, focus-spec repeat/cooldown.
- **#12** — one line in 02 about optional live filtering.
- **Focus** — whether Browse/Library can live on stock Material3 focus, or tShop still needs Compose TV widgets.
