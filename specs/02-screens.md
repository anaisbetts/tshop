# tShop v1 screens

> Every screen in the first release, what you can do on it, and what
> that forces on the server side.

This document lists the screens of tShop version one and the actions
available on each. It is not a visual design. Its purpose is to make
the client concrete enough that the catalog and server requirements
fall out of it rather than being guessed at. It follows
[01-prd.md](01-prd.md) and assumes its scope and exclusions.

## Top-level structure

tShop has three top-level destinations the user switches between
directly, for example with shoulder buttons or tabs:

- **Browse** — the storefront grid, and the default screen
- **Library** — what is on this device and what needs updating
- **Settings** — the few switches tShop has, plus About

Everything else is reached by drilling in and left with Back. Search is
part of Browse rather than a destination of its own, so there is only
one layer of tab-like navigation; category filtering deliberately does
not add a second one.

A small bitmapped Wi-Fi icon in a corner of every screen shows whether
the device is online, in the manner of the 3DS home menu. tShop does
not use banners or blocking dialogs to report connectivity.

## Screens

### Onboarding

Shown once, on first launch. It explains what tShop is and then walks
through the two permissions the store cannot function without:

- **Install unknown apps.** On Android 8 and later this is a per-app
  toggle inside Android Settings. Onboarding explains why it is needed
  and offers a button that opens the correct Settings page.
- **Notifications.** On Android 13 and later this is a runtime
  permission. Onboarding requests it so update notices can be shown.

Actions: Next, Open Settings (per permission), Finish. Onboarding
appears again only if a permission tShop needs has been revoked and is
about to be used.

### Browse

The default screen. One continuous, d-pad-friendly grid of square tiles
sectioned into framed category groups. Each frame carries its category
label; every app belongs to exactly one category. There are no filter
chips and no sort controls.

Tile order within a frame, and the order of the frames themselves, is
decided by the catalog based on popularity. The client renders the
order it is given.

Each tile can show:

- An installed mark, when the package is on the device
- An update-available badge, when the installed version is older than
  the approved release
- A greyed-out appearance, when the device does not meet the app's
  capability requirements

Actions:

- Move focus with the d-pad or touch; confirm opens App Detail.
- **Search.** A search button opens the system keyboard. On landscape
  handhelds the IME is expected to cover the whole screen, so search
  is a commit-then-view flow rather than filter-as-you-type. After the
  query is committed, Browse re-renders in place showing only tiles
  whose name, summary, or description match. Category frames are
  preserved and empty frames disappear. A visible clear-search control
  returns to the full grid.
- While downloads are active, a small status strip points to Library.

Offline, Browse renders from the last cached catalog, including tile
artwork. Install is disabled until connectivity returns.

### App Detail

Opened from any tile. This is where tShop spends screen space on
artwork and on explaining the app.

Shown:

- Name, larger icon or artwork
- Screenshot thumbnail strip
- Short summary and full description
- Category
- Capability requirements, each marked met or unmet for this device.
  This is also where a greyed-out tile is explained.
- Latest approved version and release date
- Changelog for the latest approved release only
- Upstream project or publisher
- Installed version and update status, when the package is present

One primary action is visible at a time:

- **Install** — package not present
- **Update** — present, matching signature, older than the approved
  release
- **Open** — present and current
- **Retry** — the last download or install for this app failed
- **Installed from another source** — the package is present but its
  signing certificate does not match the catalog's expected signing
  identity. Android will refuse an update signed by a different key,
  so this state explains that the existing copy (typically from the
  Play Store) must be uninstalled before tShop can manage the app.

Secondary actions:

- **Uninstall**, when the app is installed with a matching signature
- **Open upstream page**, which launches the external browser

Install and Update enqueue a background download. The primary button
becomes a progress indicator and the user is free to leave the screen
and keep browsing. Multiple installs queue.

When a release provides more than one APK, the client chooses
automatically by ABI and minimum Android version. tShop should almost
never ask. Only when the catalog marks the variants as a genuine user
choice, such as different renderer builds, does a variant dialog
appear before the download starts.

### Screenshot viewer

Opened by confirming a screenshot in the Detail strip. Fullscreen; left
and right page through the set; Back returns to Detail.

### Library

Visually the same framed grid as Browse, but the frames are states
rather than categories:

- **Queue** — downloads in progress, downloaded and awaiting
  confirmation, and failed items
- **Updates available** — this frame carries the **Update All** action
- **Up to date**
- **Other source** — greyed tiles for packages that match a catalog
  entry but carry a different signing certificate

Any installed package that matches a catalog entry appears in Library.
When the signature matches, tShop does not distinguish between apps it
installed and apps that were already present; it simply offers updates
for both.

The Library tab shows a badge counting queued items plus available
updates.

Queue item actions:

- **Cancel**, in any state
- **Retry**, for a failed item

Failed items show a reason and remain until dismissed. A failure never
stalls the rest of the queue.

Without Shizuku or root, tShop cannot install anything itself. It hands
each APK to Android's package installer, which shows its own
confirmation dialog, one per app, that the user must accept. tShop
fires these dialogs automatically, one after another, while the user is
on Library. Leaving Library pauses the chain; returning resumes it.
These dialogs never appear while the user is browsing.

Selecting any tile opens App Detail.

### Settings

- Update notifications on or off. Background update checks are always
  on; there is no switch for them and no automatic application of
  updates in version one. There is also no Wi-Fi-only download switch:
  APKs are only fetched when the user explicitly Installs, Updates, or
  runs Update All, so they already control when cellular data is used.
- **Privacy Mode**, off by default. Label: "Do not send any anonymized
  information to the shop." When on, Install, Update, and Update All
  use each variant's upstream URL instead of tShop's counted download
  URL. Catalog and artwork fetches are unchanged. If upstream is
  unreachable, the queue item fails; it must not fall back to the
  counted host.
- Check for updates now
- Catalog last-updated timestamp
- About: app version, open-source licenses, source repository link,
  support link, the "What tShop knows about you" policy from the PRD,
  and a link that opens the public stats dashboard in the external
  browser

### Surfaces that are not screens

- **Update notification.** One summary notification, for example
  "3 updates available: RetroArch, Dolphin, +1", opening Library. The
  background check does not pre-download APKs; downloads begin when the
  user acts.
- **Wi-Fi status icon**, described above.
- **Public stats dashboard.** A first-party web page, not an in-app
  screen. It lists per-app download totals (all-time and recent) from
  the same daily aggregates that produce popularity rank. It also
  quotes the privacy policy. No login. No extra fields for operators.

## What the screens require from the server

At runtime the client needs exactly two things from tShop's
infrastructure: a **catalog document** and **hosted files**. Search and
category grouping run on the device against a catalog of 30 to 50
entries, and every state shown in Library or on a tile is computed
locally. No screen needs a per-request API.

This resolves the delivery question left open during planning: the
server side is a publishing pipeline that emits a signed catalog
document, static assets, and a public stats page, plus a download
host. The download host is the only live request path. It exists so
tShop can count completed APK downloads. Those counts are the
analytics system described in the PRD. They are not an undecided
side effect.

### Catalog entry fields

Each entry must carry what the screens above display or compute
against:

- **Identity**: Android package name and expected signing identity.
  Used for the installed and update-available marks, for Library
  adoption of existing installs, and for the "other source" state.
- **Category**: exactly one.
- **Popularity rank**: computed server-side from download counts and
  published as an explicit order. The client never sorts.
- **Capability requirements**: a closed, client-detectable tag list.
  Only tags the client can evaluate are allowed; the pipeline rejects
  unknown ones. Version one starts with an empty vocabulary and adds a
  tag when a catalog entry cannot usefully run without that hardware.
  Optional enhancements are written as notes, not tags. Drives greyed
  tiles and the met or unmet list on Detail.
- **Localizable text**, with English as the fallback: name, summary,
  full description, compatibility notes, changelog. The schema carries
  a language key per text field even if version one ships English
  only.
- **Latest approved release only**: version name and code, release
  date, changelog, and a list of **APK variants**. Each variant has
  supported ABIs, minimum SDK, size, hash, tShop download URL,
  upstream download URL, and an optional human-readable label. The
  client uses the tShop URL unless Privacy Mode is on. A flag on the
  release marks whether the variants represent a user choice worth a
  dialog.
- **Assets**: square tile, larger icon or artwork, and screenshots as
  thumbnail plus full-size pairs.
- **Upstream project URL.**

### Pipeline and hosting

- Release monitoring and validation, as described in the PRD, produces
  the signed catalog document.
- APK downloads are **rehosted or proxied** through tShop so completed
  downloads can be counted, unless Privacy Mode is on. The host
  increments a daily total for package, version, and variant, then
  forgets the request. Popularity is recomputed from those totals and
  baked into the next published catalog order. The same totals are
  published on the public stats page. Privacy Mode downloads never
  hit this host.
- Catalog documents, tiles, artwork, and screenshot pairs are ordinary
  static files. Fetching them is not an analytics event.
- Static assets use cache-friendly headers so the client can keep
  Browse working offline.
- The catalog carries a published timestamp, shown in Settings.

### Client-only concerns

The following need no server support and are listed so they are not
mistaken for catalog work: package scanning, signing-certificate
comparison, device capability detection, the download queue,
PackageInstaller sessions and the confirmation chain, notification
scheduling, and the catalog and artwork cache.

Catalog signing and verification is not a screen question. It belongs
to the infrastructure plan.
