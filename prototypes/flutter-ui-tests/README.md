# Handheld input prototypes

Throwaway Flutter harness for [specs/98-prototype-this-first.md](../../specs/98-prototype-this-first.md) items **#2** (controller input) and **#12** (IME shape), plus a stock-widget focus kitchen. Same app, separate pages. Nothing here ships.

## Run

From this folder, with [fvm](https://fvm.app) installed:

```bash
./flutterw run
```

Install on a Retroid or Odin. The home screen lists the pages; d-pad should move between the cards.

## #2 Controller input

Press every control on the built-in pad, then one Bluetooth pad.

Record per device × pad:

- Did `KEYCODE_DPAD_*` arrive as arrow keys?
- Did `AXIS_HAT_X/Y` motion events arrive? If keys are empty and hat stays `none`, Dart never saw the d-pad.
- Hold the d-pad: repeat count and last interval (ms).
- Hold A: does it repeat? 04 wants d-pad repeats and face buttons never.
- Physical vs logical key names on key-up (Thor mismatch).
- Can the stock "Install unknown apps" page be toggled with the d-pad alone? Use the button on this page.

## Focus kitchen

D-pad through stock Material controls. Toggle **Stock** (Flutter already maps arrows to `DirectionalFocusIntent`) vs **Linear** (arrows become Next/Previous, the `flutter_gamepads` default).

Record per device:

- Can every control take focus, or do some get skipped?
- Do Left/Right follow the 2-column grid under Stock?
- Does the text field trap arrow keys?
- Does the slider steal Left/Right?
- Can you enter and leave the expansion tile and the dialog? Does focus return?
- Is Stock good enough, or is this still worse than Compose TV?

## #12 IME shape

Open the search field. Photograph the screen.

Record per device:

- Verdict on the banner: `DOCKS`, `COVERS`, or `NO IME`.
- Screen size, aspect, `viewInsets.bottom`, remaining height.
- Is any catalog tile still visible?
- Can the system IME type a query with the d-pad alone?

If the IME is a fullscreen modal, the Flutter view is covered and the photo is the result.

## Gates

- **#2** — whether the client needs a native input plugin, whether the Thor key-up shim is one device or a pattern, Onboarding touch warning, focus-spec repeat/cooldown.
- **#12** — one line in 02 about optional live filtering.
- **Focus** — whether Browse/Library can live on Flutter's stock directional arrows, or tShop needs a Compose-TV-style d-pad owner.
