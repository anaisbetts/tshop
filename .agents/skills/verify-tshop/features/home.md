# Home identity

Home is the only shipped screen. Opening the app shows a Material storefront whose AppBar title is `tShop`. There is no catalog grid and no other destination.

## Sub-features

- `home-open` loads `/` and paints the AppBar title `tShop`.
- `home-reload` still shows `tShop` after a full browser reload.

## How to get to it (user POV)

- Open the served app URL (default `http://127.0.0.1:4173/`).
- Reload the tab while already on `/`.

## Driving it with control-tshop

Preconditions:

- `control-tshop doctor` reports `ok` for this run's URL.
- The browser is pointed at that URL, not a stale preview on another port.

- **Open home.** Navigate to the URL from `control-tshop url`. Wait until `document.title` is `tShop` and the Flutter view has painted. The AppBar heading on the canvas reads `tShop`. The path is `/`.
- **Reload home.** Reload the tab. After the engine boots again, `document.title` is `tShop` and the AppBar still reads `tShop`.
- **Proof.** Capture `.cursor/skills/verify-tshop/artifacts/home/ready.png` and `reload.png` (AppBar `tShop` visible in both) plus `ready.title.txt` and `reload.title.txt` containing the exact `document.title` and URL. All four artifacts identify tShop and `/`.

## Gotchas

- The HTML shell title is `tshop` (lowercase) until Flutter mounts. A screenshot of a blank canvas or a tab titled `tshop` is not a pass.
- Flutter web draws the AppBar on a canvas. Accessibility snapshots are usually empty besides a document named `tShop` and an `Enable accessibility` button that `flutter-view` intercepts. Do not fail the run for a missing ARIA name; fail if the screenshot does not show `tShop`.
- `flutter_test` finding `tShop` in `test/widget_test.dart` is not this feature. Live proof is the served web build in a browser.
- A leftover server on port 4173 that `control-tshop doctor` rejects is not this instance. Stop only what this run started, or pick `TSHOP_VERIFY_PORT`.
