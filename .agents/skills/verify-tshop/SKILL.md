---
name: verify-tshop
description: Drive the tShop Flutter web storefront like a user — launch the local web build, exercise a mapped feature, and capture proof. Use when verifying tShop UI, routes, or storefront behavior.
---

# Verify tShop

tShop is a curated Android handheld app store. The product target is a Flutter Android client. Agents verify the **Flutter web build** in a browser: that is the only surface this environment can drive without stealing an emulator or desktop session. `client/tool/verify` (format, analyze, test, `build web`) is compile proof, not user-path proof.

Other surfaces that exist and are out of scope for this skill: Android (`dev.anais.tshop.dev` debug, `dev.anais.tshop` release) and Linux desktop (`./flutterw run -d linux`). Do not drive those from a web verification run.

There is no login, no seed catalog, and no API to curl for UI state. The implemented storefront is a single route `/` whose AppBar title is `tShop`. Browse, Library, Settings, App Detail, and Onboarding are specified in `specs/02-screens.md` and are **not implemented** — do not invent selectors for them.

## Launch

From the repo root:

```bash
.cursor/skills/verify-tshop/bin/control-tshop launch
```

That rebuilds `client/build/web` with `./flutterw` (never a global `flutter`), then serves it at `http://127.0.0.1:4173/` via `setsid` so the server outlives the launching shell. Ready means `control-tshop doctor` prints `ok`. The Flutter shell HTML answers immediately; the canvas AppBar title appears only after the engine boots in the browser (see Drive). Re-run `doctor` after launch — a `ok` printed by `launch` is not enough if you are not using this helper (a bare `python3 -m http.server &` dies with the parent shell).

Set `TSHOP_VERIFY_PORT` to run a second instance on another port. Set `TSHOP_VERIFY_SKIP_BUILD=1` only when `client/build/web` was just produced by this same run. Default port `4173` is reserved for verification — do not share it with a leftover `python3 -m http.server` or a user's own preview.

Two instances may serve the same `client/build/web` directory on different ports. They must not share a port. Do not rebuild `client/build/web` while another verification server is reading it. Do not drive an instance this run did not start.

Teardown: `.cursor/skills/verify-tshop/bin/control-tshop stop` (same `TSHOP_VERIFY_PORT`).

## Doctor

Run this first whenever anything looks off:

```bash
.cursor/skills/verify-tshop/bin/control-tshop doctor
```

Pass means: the pid file is live, that pid's cmdline is this helper's `http.server` for `client/build/web` on the expected port, `GET $url` is 200, and the HTML contains `<title>tshop</title>` plus `flutter_bootstrap.js`. Fail means stop and relaunch. Doctor does not prove Flutter has painted — only that the instance is ours and worth attaching a browser to.

## Drive

1. `control-tshop doctor` must already be `ok`.
2. Open `control-tshop url` (default `http://127.0.0.1:4173/`) in the Cursor browser or another Chromium. Wait until the Flutter view exists (`flutter-view`, `flt-glass-pane`, or a canvas child of the Flutter host) **and** the on-screen AppBar reads `tShop`. The HTML `<title>` is `tshop` before the engine starts; `document.title` becomes `tShop` after `MaterialApp` mounts. A load that only shows the lowercase HTML title is not ready.
3. Flutter web paints to canvas. Do not expect a useful ARIA tree. The snapshot is a document named `tShop` plus an `Enable accessibility` button that `flutter-view` covers — do not click it. Treat screenshots plus `document.title` and the URL as the handles.
4. Prefer the route path `/`, the visible AppBar string `tShop`, and `document.title === "tShop"` over coordinates. There are no `data-*` attributes and no Semantics labels yet.
5. Read `.cursor/skills/verify-tshop/features/README.md`, then the feature file. Drive every entry point that file lists. A proof that only hits one convenient path is incomplete when the map lists others.
6. Snap / screenshot before the action, perform one structural action, snap / screenshot after.

This checkout has no Playwright, Cypress, or Flutter Driver suite. Do not add one for a single probe.

## Evidence

Write proof under `.cursor/skills/verify-tshop/artifacts/<feature-id>/`. That directory survives `control-tshop stop`.

For every claim:

- Exercise the real browser path against the served web build. Do not pump `TshopApp` in `flutter_test` and call it live proof. `test/widget_test.dart` is unit coverage only.
- Capture the action and the resulting state (before + after), not just the last frame.
- A home proof must show the AppBar title `tShop` in a screenshot **and** record `document.title` of `tShop` **and** URL path `/`.
- There are no installs, files, or rows to check yet. When those exist, a visible button is not enough — prove the side effect from a second user-facing view.
- Do not mock the catalog or Dio. Nothing in the current UI talks to the network.

Name files with the feature id and step (`home/ready.png`, `home/ready.title.txt`).

## Cleanup

```bash
.cursor/skills/verify-tshop/bin/control-tshop stop
```

Kills only the pid recorded for this port, and only after the cmdline check. Removes `/tmp/tshop-verify-$PORT` (or `TSHOP_VERIFY_STATE_DIR`). Does **not** delete `artifacts/`, `client/build/web`, or anything in the repo.

If launch fails after the server process started, run the same `stop` before retrying so the port is not stranded.

## Helpers

`.cursor/skills/verify-tshop/bin/control-tshop` is executable. Invocation:

```bash
.cursor/skills/verify-tshop/bin/control-tshop launch
.cursor/skills/verify-tshop/bin/control-tshop doctor
.cursor/skills/verify-tshop/bin/control-tshop url
.cursor/skills/verify-tshop/bin/control-tshop stop
```

`launch` / `doctor` print `url=`, `pid=`, `port=`. `url` prints only the URL.
