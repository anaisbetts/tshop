# Lessons from the reference corpus

> What the 46 reference repositories in `tshop-oppo/refs` teach about
> building tShop, collated against the decisions already made in
> [01-prd.md](01-prd.md), [02-screens.md](02-screens.md),
> [03-hosting-and-bandwidth.md](03-hosting-and-bandwidth.md) and the open
> findings in [99-spec-critique.md](99-spec-critique.md).

Written September 2026. Every dated or platform-dependent claim below was
checked against a primary source on 2026-09-04; those checks are listed in
[Checked on the web](#checked-on-the-web-2026-09-04). Everything else is
traceable to a file under `refs/` and is cited as such.

## How to read this

The corpus is 258 markdown files, about 1.9 MB, in four folders that mirror
the spec documents: `10-store-clients` (02), `11-store-backends` (01 release
tracking, 02 pipeline and hosting), `12-install-and-packages` (99 findings
1, 13, 14, 18, 19, 22) and `13-console-ui-and-input` (01 controllers and
console look). Two synthesis documents already existed inside the corpus,
`refs/10-store-clients/BACKEND-ARCHITECTURE.md` and
`refs/11-store-backends/ARCHITECTURE/README.md`; they are treated as
sources here, not restated.

Each lesson carries one tag:

- **confirms** — supports a decision already in 01, 02 or 03
- **challenges** — argues against one
- **fills gap** — answers something 99 flagged as undecided

Where a lesson resolves a numbered critique finding, the finding is given as
`(99 §N)`.

Corpus hygiene, so nobody re-derives it: `client/` and `droid-ify-client/`
are the same commit and were read once; `.tmp-fdroidclient` is a broken
checkout with zero tracked files; `fdroiddata` and `Daijishou` are listed in
`refs.txt` but were never cloned. The `.pi-subagents/` folder holds the
scout transcripts behind `BACKEND-ARCHITECTURE.md`. iiSU's README does not
state its stack; `refs.txt` calls it Compose, which is unverified.

## Ten things that change the plan

These are the findings that alter a decision or add a requirement. The
detailed sections that follow carry the evidence.

1. **Android developer verification is not in any spec and is 26 days
   away.** Enforcement on certified devices starts 30 September 2026 in
   Brazil, Indonesia, Singapore and Thailand through seven OEM stores, then
   goes global in 2027 "regardless of your app's download source", with
   Google stating the verifier will be "expanded to all third-party Android
   app stores". Retroid, AYN and Play-equipped Anbernic devices are
   certified. This touches tShop itself (register `dev.anais.tshop`), every
   catalog entry (an unregistered upstream developer's app needs the
   "advanced flow": developer options, a coercion check, a reboot and a
   24-hour wait), and the pipeline (a public status API exists to check a
   package). F-Droid calls the program existential and advises developers
   not to register; Komi Store's README carries a `keepandroidopen.org`
   banner. tShop needs a position and a catalog field.
2. **The IME-covers-the-screen premise is device-dependent, and on the AYN
   Thor it holds.** Flutter's Android engine sets
   `EditorInfo.IME_FLAG_NO_FULLSCREEN` on every text field
   (`TextInputPlugin.java`, since 2016), and R-Shop, a Flutter handheld
   shop, filters live while typing on the strength of it. On the Thor the
   keyboard is a modal that covers the whole screen in every app, Flutter or
   not: the device's IME does this deliberately because its landscape or
   square panel would otherwise leave an unreadable strip of UI. Android
   documents the flag as "not a guarantee", and this is what that looks
   like. Expect the same policy on other handhelds with the same aspect
   ratios. 02's commit-then-view search stands; live filtering is not a
   safe default.
   What survives from R-Shop is the focus hand-off (Down or B leaves the
   field) and the need to stop arrow keys leaking from the field into the
   grid.
3. **About a quarter of the essential emulators are not on GitHub
   Releases.** In the Obtainium Emulation Pack, Dolphin, DuckStation, Eden,
   Play!, PPSSPP, RetroArch and ScummVM are HTML-scraped
   (`overrideSource:"HTML"`). RetroArch's GitHub releases carry only source
   tarballs; the APKs live on `buildbot.libretro.com`. Eden publishes its own
   `release.json`. The pipeline needs a directory-listing adapter and a
   JSON-feed adapter on day one, not as a later source.
4. **Cumulative download totals are a lagging signal.** Komi's feed-v2 brief,
   written after a 90k-user store killed client telemetry and ranked on
   GitHub download totals, says totals "favor old megaprojects and barely
   move day to day". Rank on a windowed rate (7-day half-life EWMA of daily
   counts), gate momentum on a minimum base, and fall back to a curated seed
   rank. The per-day counter tShop already specified is the snapshot table
   this needs; it cannot be backfilled, so it starts on day one (99 §9).
5. **Signing continuity is harder than "compare the cert hash".**
   fdroidserver's `AllowedAPKSigningKeys` was bypassable by v1-only APKs
   targeting SDK < 30 until 2.3.5 (January 2025), apksigner 33.x misverifies
   v3/v3.1 signatures, and IzzyOnDroid additionally scans the APK Signing
   Block for Play "Frosting" to catch re-wrapped uploads. The catalog needs
   an allowlist of certificates per package, not one expected cert, and the
   pipeline needs a pinned apksigner and a v2-or-better requirement
   (99 §13).
6. **Version comparison has three outcomes, and the client needs two more
   states.** IzzyOnDroid quarantines "same versionCode, different bytes" as
   its own failure; ObtainX replaced Obtainium's binary verdict with six
   states including *device is ahead* and *genuinely unclear*; EmuTran
   shipped a text-compare that put a permanent Update badge on "nearly every
   installed emulator". versionCode decides, and Detail needs "newer than
   catalog" and "cannot compare" (99 §13, §18).
7. **The installer is the most failure-prone subsystem in every peer.** Neo
   Store's changelog spends two years on installer types, false contexts,
   stuck sessions, semaphore deadlocks and retry counters; EmuTran shipped
   two install paths that silently did nothing because "Install unknown
   apps" was only checked in onboarding. The queue needs reboot recovery,
   a permission re-check at install time, a confirmation timeout, a mutex
   on Update All, and retries capped at three (99 §22).
8. **Same package id across stable, nightly and forks is the norm.** Cemu,
   Dolphin, NetherSX2 and GameHub Lite each appear twice in the pack under
   one id; the pack's entire dual-screen variant exists to dodge id
   collisions. Adopt apps.obtainium's rule verbatim: forks only if both
   package name and display name differ. Nightlies are listed but never
   auto-installed (99 §13 nightly policy).
9. **Nobody in the corpus counts completed downloads on a static host.**
   F-Droid deleted `fdroid stats` in 2.2.0; IzzyOnDroid's dlstats come from
   web-tier logs outside its tooling repo; Accrescent's directory has no
   counter table at all; the only measured-install analog is
   apps.obtainium's Plausible pixel, which tShop rejects. The R2 Worker
   counter in 03 is novel here, which is fine, but it means the "completed"
   definition in 03 has no prior art to lean on (99 §5).
10. **Landing Page entries are confirmed, and the list is longer than 03
    thought.** DuckStation's Android build has had no update since 1 May
    2025 and the author has said there will be none; the pack sources it
    from a third-party Cloudflare Worker mirror. ES-DE is still paid and
    "please don't distribute it or share download links". NetherSX2 keeps
    the pulled AetherSX2's package id. The pack also has "track only"
    entries for GPU drivers that are not APKs at all.

## Checked on the web (2026-09-04)

| Claim | Status | Source |
|---|---|---|
| Developer verification: 30 Sep 2026 pilot (BR, ID, SG, TH; Play, HONOR, OPPO, Galaxy Store, Palm Store, V-Appstore, GetApps); global on certified devices in 2027 "regardless of download source"; verifier to be "expanded to all third-party Android app stores" | Confirmed | [developer.android.com/developer-verification/guides](https://developer.android.com/developer-verification/guides), [FAQ](https://developer.android.com/developer-verification/guides/faq) |
| Advanced flow: developer mode, coercion check, re-auth, reboot, one-time 24-hour wait, then "Install anyway" with a warning; ADB exempt; limited-distribution accounts up to 20 devices, no ID or fee | Confirmed | [Android Developers Blog](https://developer.android.google.cn/blog/posts/android-developer-verification-balancing-openness-and-choice-with-safety), [9to5google](https://9to5google.com/2026/03/19/android-advanced-flow-sideloading/) |
| Package registration status API: `androiddeveloperidstatus.googleapis.com/v1/packages/{packageName}/packageRegistrationStatus:check`, global since July 2026; Developer Console API supports OAuth delegation to stores | Confirmed | [Help Net Security](https://www.helpnetsecurity.com/2026/06/19/android-developer-verification-rollout-markets/), [Console API guide](https://developer.android.google.cn/developer-verification/guides/developer-console-api) |
| F-Droid opposes registration and advises developers against it | Confirmed | [F-Droid open letter, 2026-02-24](https://f-droid.org/en/2026/02/24/open-letter-opposing-developer-verification.html) |
| targetSdk install floor: 23 on Android 14, 24 on Android 15, unchanged on 16; `INSTALL_FAILED_DEPRECATED_SDK_VERSION`; only bypass is `adb install --bypass-low-target-sdk-block` | Confirmed | [bayton.org matrix](https://bayton.org/android/android-minimum-targetsdk-matrix/), [Android 15 behavior changes](https://developer.android.com/about/versions/15/behavior-changes-all) |
| 16 KB page size: Android 15+ devices may run a 16 KB kernel; 4 KB-aligned native apps run in backcompat mode with a first-launch warning unless `android:pageSizeCompat` is set; Play requires 16 KB support for targetSdk 35+ since 1 Nov 2025 | Confirmed | [Support 16 KB page sizes](https://developer.android.google.cn/guide/practices/page-sizes), [AOSP backcompat](https://source.android.com/docs/core/architecture/16kb-page-size/16kb-backcompat-option) |
| Advanced Protection (Android 16) greys out "Install unknown apps" for every app; opt-in | Confirmed | [Android Authority](https://www.androidauthority.com/android-16-advanced-protection-mode-3518368/), [Obtainium#2591](https://github.com/ImranR98/Obtainium/issues/2591) |
| Flutter maps `KEYCODE_BUTTON_A`..`Y` (96–99) to `LogicalKeyboardKey.gameButtonA`..`Y` and `KEYCODE_DPAD_*` to arrow keys; arrow keys move the caret, not focus, inside text fields by default | Confirmed | [keyboard_maps.g.dart](https://codebrowser.dev/flutter/flutter/packages/flutter/lib/src/services/keyboard_maps.g.dart.html), [flutter/flutter#49335](https://github.com/flutter/flutter/issues/49335) |
| Android delivers d-pad either as `KEYCODE_DPAD_*` or as `AXIS_HAT_X/Y`; apps must treat both as the same input | Confirmed | [Handle controller actions](https://developer.android.com/games/sdk/game-controller/controller-input) |
| Flutter sets `IME_FLAG_NO_FULLSCREEN` on all Android text input; no public way to re-enable fullscreen extract mode | Confirmed in the engine; **ignored on AYN Thor**, whose IME is a full-screen modal in every app by design (owner observation, 2026-09-04) | [TextInputPlugin.java](https://github.com/flutter/engine/blob/main/shell/platform/android/io/flutter/plugin/editing/TextInputPlugin.java), [flutter/flutter#4899](https://github.com/flutter/flutter/issues/4899) |
| DuckStation Android: last update 1 May 2025; author: "No, because I don't have time and android users told me they don't want updates"; Play listing still exists | Confirmed | [Time Extension, 2026-03](https://www.timeextension.com/news/2026/03/popular-ps1-emulator-duckstation-may-have-reached-the-end-of-the-line-on-android), [duckstation.org](https://www.duckstation.org/) |
| ES-DE Android: paid ($5.50 Patreon, $6.50 Galaxy Store), "partially closed source", "Please don't distribute it or share download links to the APK"; delisted from Huawei AppGallery | Confirmed | [es-de.org](https://es-de.org/) |
| RetroArch: GitHub releases have no APK assets since 1.7.8; APKs only on `buildbot.libretro.com/stable/<ver>/android/` (`RetroArch_aarch64.apk`, `_ra32`, universal); F-Droid ships `com.retroarch` stable; Play version years stale | Confirmed | [libretro/RetroArch#9620](https://github.com/libretro/RetroArch/issues/9620), [libretro docs](https://github.com/libretro/docs/blob/master/docs/guides/install-android.md) |
| Switch emulators: Eden actively developed (GPLv3); Citron Neo active with nightly cadence; Sudachi capped at firmware 19 | Confirmed (secondary sources) | [tech-insider](https://tech-insider.org/eden-vs-citron-vs-sudachi-reborn-android-2026/), [citron-neo releases](https://github.com/citron-neo/emulator/releases) |
| Obtainium is at 1.6.11 (7 Aug 2026), with ~20 sources, categories, Shizuku installs, track-only mode, `useVersionCodeAsOSVersion`, release-date-as-version | Confirmed | [APKMirror](https://www.apkmirror.com/apk/imranr98/obtainium/), [Obtainium wiki](https://wiki.obtainium.imranr.dev/app_tracking/) |
| Komi Store (ex GitHub Store): 18.1k stars, v1.9.1, backend `api.github-store.org` live, self-hostable claim | Confirmed | [kurikomi-labs/komi-store](https://github.com/kurikomi-labs/komi-store), [v1.8.0 notes](https://github.com/kurikomi-labs/komi-store/releases/tag/v1.8.0) |
| IzzyOnDroid tooling has moved to Codeberg (`repodata` with a JSON Schema that makes `AllowedAPKSigningKeys` mandatory, `iod-stats-collector`, `iod-stats-builder` "turn your server logs into the stats format", `rbtlog`); April 2026 commit "also quarantine APKs with invalid certs" | Confirmed | [codeberg.org/IzzyOnDroid](https://codeberg.org/IzzyOnDroid), [APK Scans](https://izzyondroid.org/about/security/ApkScans/) |
| Shizuku 13.6.0 supports Android 16 QPR1; Android 16 drops wireless debugging frequently; Play Store build is stale, GitHub is current | Confirmed | [RikkaApps/Shizuku releases](https://github.com/RikkaApps/Shizuku/releases), [Shizuku#1478](https://github.com/RikkaApps/Shizuku/issues/1478) |

Not re-checked here because 99's verification notes already cover them:
`setRequireUserAction` conditions, Android 14 update ownership as a
device-side `sysconfig` opt-in, GitHub release-asset egress failures.

## Catalog

### The launch list already exists as data

`refs/11-store-backends/Obtainium-Emulation-Pack/README.md` is 76 Obtainium
configs encoded as `obtainium://app/{json}` links, plus a generated
`pages/table.md` that decodes to the same list. It is consumed live by
EmuTran. Decoded, grouped by the pack's own categories, with the quirks the
pipeline will meet:

**Emulators (36).** aPS3e, ARMSX1, ARMSX2 (`verifyLatestTag`), ARMSX3,
Azahar (variants: `apkFilterRegEx:"vanilla"`, version rewritten
`$1-vanilla`), Cemu (SSimco fork; `releaseTitleAsVersion` because tags are
not versions), Cemu dual-screen fork (**same id** `info.cemu.cemu`), Citra
MMJ, Citron Neo, Dolphin (HTML scrape of `dolphin-emu.org/download`),
Dolphin dev build (**same id**, table-only), Dolphin-MMJR2, DuckStation
(HTML via `duckstation-mirror.rmacias.workers.dev`), Eden (self-hosted
`stable.eden-emu.dev/latest/release.json`, `-standard.apk` variant filter),
Eden Nightly (separate id `dev.eden.eden_nightly`, table-only), Flycast,
Gopher64, Hakux, melonDS, melonDS Nightly (separate id; release date as
version because the nightly tag is static), NetherSX2-Classic and -Patch
(**same id** `xyz.aethersx2.android`), NetherSX2-Turnip, Pico8 Android
(needs paid PICO-8 data), Play! (HTML directory listing on purei.org,
`APKLinkHash` pseudo-version), PPSSPP (HTML on ppsspp.org; regex converts
`1_17_1` to `1.17.1`), RetroArch aarch64 (two-hop HTML on buildbot;
`exemptFromBackgroundUpdates`, `skipUpdateNotifications` because the stable
directory changes without a version change), RetroArch Nightly (table-only),
RPCSX, ScummVM (HTML; per-ABI APKs, `android-arm64-v8a.apk$`), Swiff,
Vita3K (releases in a separate `Vita3K-builds` repo), WatermelonDS (distinct
id `me.magnum.melondualds`, the good fork example), X1 BOX, X360 Mobile,
Xendroid.

**Frontends (9).** Argosy, Cannoli, Cocoon FE, Console Launcher, NeoStation
(all `includePrereleases`, Cocoon has only beta tags), Daijishō, iiSU
(`useVersionCodeAsOSVersion` because versionName is unreliable), Pegasus
(`apkFilterRegEx:"android64"`), RetroHrai (releases-only repo, likely
closed). ES-DE is absent as an installable; only its companion utilities
appear.

**PC emulation (7).** GameHub Lite (stable and pre-release, **same id**),
GameNative, Starboard (`apkFilterRegEx:"\.apk$"` because releases carry
non-APK assets), Winlator, Winlator CMod (distinct id), Winlator-Ludashi
(`bionic-vanilla` from a bionic/glibc × vanilla/driver matrix).

**Streaming (3).** Artemis (`includePrereleases`), Moonlight (on F-Droid),
PXPlay (paid; GitHub used purely as a file host; table-only).

**Track only (4).** Adreno-Tools-Drivers, Mr. Purple Turnip Drivers, ES-DE
Custom Systems, the pack itself. None are APKs.

**Utilities (17).** Bifrost, CHDroid, Cluster Tune, Emulnk, EmuReady Lite
(releases-only repo), ES-DE Android Apps, ES-DE Companion, Jarngreipr and
Mjolnir (LG V60 only), Mimir, O2P Tweaks (Odin 2 Portal only, table-only),
OdinTools (shipped to everyone despite being Odin-only), PixelGuide, Pulse,
RAOfflineProxy, Syncthing-Fork (repo moved to `researchxxl/syncthing-android`
while the id still says `catfriend1`), ThorTune (modifies system state,
table-only).

`android-foss/README.md` adds FOSS-vetted candidates the pack omits:
Lemuroid and J2ME Loader (both on F-Droid) under emulators; SuperTuxKart,
Mindustry, Shattered Pixel Dungeon, UnCiv, OpenTTD, Luanti, Endless Sky,
Pixel Wheels under games; Key Mapper under controller tools. Its
`Games › Emulator` section lists only eight entries, so the pack is the
better source for emulators and android-foss for FOSS games.

Lessons:

- **Roughly 30 of the 76 are plausible v1 entries, and the frontend
  category needs the hardest cut.** Nine frontends, five of them
  pre-release-only. Daijishō, Pegasus and one RomM client is a defensible
  set. *fills gap* (01 open question: which 30–50 apps).
- **The PS2 answer the community expects is NetherSX2, which 03 already
  rules out.** ARMSX2 and Play! are the installable alternatives; a
  NetherSX2 Landing Page entry is the honest bridge. *challenges* nothing,
  but the decision has to be written down.
- **Device-specific utilities belong behind capability tags, not out of the
  catalog.** The pack ships OdinTools to everyone and hides O2P Tweaks; 02's
  tag vocabulary is the better mechanism. EmuTran goes further and reads
  manufacturer, SoC and screen type to hide non-applicable emulators and
  skip Adreno-only driver steps on Mali. A per-entry `requires` tag such as
  `gpu:adreno` is a field, not a fork. *confirms* 02's tags, and starts the
  vocabulary with one real tag.
- **A "resource" entry type is a later question, not a v1 one.** GPU drivers
  and ES-DE custom systems are useful non-APKs the community tracks. Exclude
  them and say so. *fills gap* (99 §14).
- **Categories: the pack uses Emulator, Frontend, Utilities, PC Emulation,
  Streaming, Track Only, and allows multiple per app.** Starboard is both PC
  emulation and a frontend. 99 §11's fix (one primary category plus search
  tags) survives contact with the data. *fills gap* (99 §11).

### Not everything is rehostable, and the reasons vary

| App | Situation | Entry type |
|---|---|---|
| ES-DE | Paid, partially closed, explicit no-redistribution request | Landing Page → Patreon / Galaxy Store |
| DuckStation | CC BY-NC-ND; Android build abandoned May 2025; community uses a Worker mirror | Landing Page → Play, with a "no longer updated" note |
| NetherSX2 | Patch on AetherSX2 (CC BY-NC-ND); id `xyz.aethersx2.android` | Landing Page or omit |
| PXPlay, RetroHrai, EmuReady Lite, Pico8 Android | Closed or paid; GitHub is a file host, not a source | Landing Page or omit |
| RetroArch | GPL, but F-Droid's `com.retroarch` is F-Droid-signed while buildbot's is libretro-signed | Rehost the buildbot build; the F-Droid build is a different signing identity |

The last row is a new wrinkle: two legitimate builds of the same package
with two different signing identities. A device that installed RetroArch
from F-Droid is "Installed from another source" to a catalog that pins the
buildbot cert, and vice versa. Cert allowlists per package (below) are the
only clean answer. *fills gap* (99 §19).

### Intake rules worth adopting verbatim

From `apps.obtainium.imranr.dev/APP_CRITERIA.md` and `CONTRIBUTING.md`:

- "Forks of apps will not be accepted, unless both the package name and
  display name of the app has been changed. This is so people do not
  unknowingly download unofficial versions of apps."
- "Only configs from official sources from the app are accepted."
- Keep overrides minimal: "leave as many config options as you can as the
  default setting… you would not add an app with the `Include prereleases`
  setting enabled unless necessary."
- One file per app keyed by package id; simple vs complex file classes.

From `android-foss/CONTRIBUTING.md`, the eight-point FOSS gate (licensed
FOSS, source available, no ads or spyware, no proprietary elements, stable,
maintained, documented, free) is a good badge, not a catalog boundary;
tShop's catalog is deliberately broader.

From the pack's `CONTRIBUTING.md`: `just add-app` autodetects the package
id "from repo `applicationId` / `namespace`, then latest release APK
manifest"; a `meta` block (`excludeFromExport`, `includeInStandard`,
`nameOverride`, `urlOverride`) is stripped at export; sparse
`additionalSettings` are hydrated from `constants.py` defaults; CI fails "if
generated files are out of date". *fills gap* (01: contribution process).

The pack's own catalog data has the defects a validator would catch:
apps.obtainium has five files whose names diverge from their package id and
two extension-less files that silently never load; icons are hotlinked and
rot. *confirms* first-party curation with CI, not trust.

### The Obtainium format as a bridge

Every pack entry is a complete `obtainium://app/{id, url, author, name,
additionalSettings, categories, overrideSource, allowIdChange}` payload.
apps.obtainium's generator warns that exports have "no icon, category, or
description data". Emitting an Obtainium manifest from tShop's catalog is
cheap and lossy in the right direction: tShop's artwork, cert allowlist and
capability tags simply do not travel. Importing is the wrong direction; the
pack's configs encode Obtainium's parsing heuristics, not facts about the
apps. *fills gap* (99 §23: emit, don't import).

## Pipeline and validation

### Source adapters

The pack's `overrideSource` values are the adapter list: GitHub Releases
(most), GitHub Releases from a separate builds repo (`Vita3K/Vita3K-builds`,
`retrohrai/Releases`, `Producdevity/EmuReadyAppReleases`), HTML download
page (Dolphin, PPSSPP, ScummVM), HTML directory listing with one or two
hops (Play!, RetroArch), JSON feed scraped as text (Eden). IzzyOnDroid's
`-m` dispatch has the same shape: `gitlab-tags`, `gitlab-repo`,
`codeberg-release`, `github-release`, `github-repo`,
`github-release-manual`, `direct-link`, `gone`, `none`.

- **Homepage and download source are different fields.** The pack needed
  `urlOverride` for exactly this. *fills gap*.
- **Per-entry asset selection is curated, not inferred.** Obtainium's
  `autoApkFilterByArch` is on for every entry and still needed
  `apkFilterRegEx` on Azahar, Winlator-Ludashi, Pegasus, Eden, ScummVM,
  Starboard and Syncthing. IzzyOnDroid carries `ApkMatch`/`ApkIgnore` per
  app. The entry schema needs an asset regex or allowlist. *confirms* 02's
  "variants are a genuine choice" flag, *fills gap* on how the pipeline
  knows which asset is which variant.
- **Identify honestly.** The pack: "Do not spoof a browser User-Agent…
  Validation may fail if a browser User-Agent is present." apkeep: do not
  "place unreasonable or disproportionately large load on the infrastructure
  of the app distributor". Fetch each release once, then rehost. *confirms*
  03's "rehost at validation time, never proxy live".
- **HTML sources break; that is the whole reason the catalog service
  exists.** The pack's FAQ: "Apps sourced from websites (HTML scraping) can
  break if the site changes its layout." Its daily `scheduled-test.yml`
  resolves every entry to a real APK and opens one GitHub issue per failing
  app, auto-closed on recovery. Copy that. *confirms* 01, *fills gap*
  (99 §13: monitor death).
- **Rate limits are not tShop's problem at 30–50 apps, but the retry
  classification still matters.** komi-store-backend: retry once on 429 or
  on 403 with `x-ratelimit-remaining: 0`, never on a bare 403; GitHub
  limits are per user, 5000/hr authenticated; Search API 30/min. Conditional
  GETs with ETag (komi's `resource_cache`, EmuTran's manifest refresh) keep
  hourly polling trivially under quota. *fills gap* (99: pipeline
  internals).

### Validation gates, in order

IzzyOnDroid's `ApkUpdater` runs, per fetched APK: `aapt` versionCode →
quarantine on **missing versionCode**, **same versionCode with different
bytes**, **apksigner cert not in the per-app allowlist**, **unmarked
AntiFeatures** → LibRadar library scan, VirusTotal, manifest lint, signing
block check → fastlane pull, HTML-sanitized. Accrescent's devconsole
hard-rejects `debuggable`, `testOnly`, `usesCleartextTraffic`, targetSdk
below a floor with per-app `sdk_exceptions`, and non-path-safe versionNames;
soft-flags a permission blacklist and VPN/IME/Accessibility services; an
update that adds no new issues auto-publishes. Both lists agree on the
manifest lint set.

The ordered gate list for tShop, merged:

1. Downloadable; size matches upstream `Content-Length`; sha256 recorded.
2. Parses; `resources.arsc` present (apkstat hard-fails without it).
3. Package name matches the entry (apkeep 0.9.0: APKPure "fetched another
   package for certain ids"; ObtainX: wrong package id makes an app "not
   installed forever").
4. versionCode present and one of: **newer** (accept), **equal with
   different sha256** (quarantine, likely a re-tag), **lower** (quarantine,
   human review). versionName is display only. *fills gap* (99 §13).
5. Signature: apksigner ≥ 30, not 33.x; v2 or later required; cert in the
   entry's allowlist; APK Signing Block contains only known block ids
   (`CheckSigningBlocks.py`, 145 lines, in `repo/lib/`). *fills gap*
   (99 §13).
6. Manifest lint: reject `debuggable`, `testOnly`, `usesCleartextTraffic`;
   flag `VpnService`, `InputMethod`, `AccessibilityService`, dangerous
   permissions; record new permissions since the approved release (Neo Store
   1.1.1 "Notify of new required sensitive permissions on updates").
7. targetSdk ≥ 24, or the entry is unsupported on Android 15+ and says so
   (99 §13). Expect this floor to move.
8. ABI: arm64-v8a present; refuse armeabi-v7a-only entries in v1.
9. Native libraries 16 KB-aligned, or the entry carries a note; LibChecker
   labels `16 KB` vs `NON 16 KB STORED` and excludes non-standard ELFs.
   Emulators are native-heavy and Android 15+ handhelds may boot 16 KB
   kernels. *fills gap*.
10. Container type is `.apk`; `.xapk`, `.apks`, `.apkm` are rejected
    explicitly and become a curation decision, not a silent failure.
    Obtainium's `isApkOrContainerFile()` exists because suffix checks
    "historically missed split-APK formats"; fdroidserver 2.4.0 "brought
    back error when a package has multiple package types". *fills gap*
    (99 §14).
11. Never execute anything from metadata (fdroidserver 2.4.1 "update: never
    execute any VCS e.g. git"); sanitize fastlane text; cap image sizes
    (2.0.1 "handle large, corrupt, or inaccessible fastlane/triple-t
    files").

Anything failing 3–10 goes to a `quarantine/` state with a reason, the
previous approved release stays published, and an issue is opened. "Quarantine,
don't publish" is the corpus consensus. *confirms* 01's last-known-good.

### Signing the catalog

No reference in the corpus has a key-rotation protocol. fdroidserver's
entire changelog has zero rotation entries; Accrescent bakes one ed25519
public key into `Constants.kt:14` and its signer lives outside the corpus.
tShop has to design rotation itself. What the corpus does offer:

- **Sign a tiny pointer, not the bulk.** fdroidserver's `entry.json`
  `{sha256, size, name}` points at an unsigned `index-v2.json`; the client
  verifies the pointer's signature and the index's hash. Signing cost stays
  constant, the bulk is CDN-cacheable. At tShop's size the whole catalog is
  a few hundred KB, so the pointer is a nicety rather than a necessity, but
  it is also where `generatedAt`, schema version and `minClientVersion`
  belong. *fills gap* (99 §21: schema version, "your tShop is too old").
- **Deploy the signature with the index, atomically, index last.**
  fdroidserver 2.0.4 and 2.1.1 both had to fix "gpg-sign index-v1.json and
  deploy it"; `deploy.py` uses two-phase rsync with `--delete-after` and
  indexes last. The Hetzner spare in 03 should do the same. *fills gap*.
- **Key identity in the client, multiple keys allowed.** F-Droid's trust
  anchor is `fingerprint=` in the repo URL; Accrescent pins one key and
  enforces a `MIN_TIMESTAMP` anti-downgrade. Ship a small trust list and a
  key id on the pointer so a rotation is a client release, not a re-install.
  *fills gap* (99: signing design).
- **Signing continuity for catalog entries is a human decision with a
  record.** IzzyOnDroid's `repodata` JSON Schema now makes
  `AllowedAPKSigningKeys` mandatory per app. Komi keys its match cache on
  fingerprint specifically so "reinstalled the app from a different source
  after a key rotation" is handled. *confirms* 99 §13's stance, *challenges*
  02's single "expected signing identity" field.

### Monitoring, publishing, delisting

- **Publish only when something changed; allow a forced republish; carry a
  heartbeat.** IzzyOnDroid publishes when `updates > 0` and `-m post`
  forces. The pack has no `generatedAt` and its dossier lists that as a
  gap. A `generatedAt` in the pointer makes a dead monitor visible to the
  client (Settings already shows the timestamp). *fills gap* (99 §13).
- **Never overwrite good data with an empty or shrunken result.**
  komi-store-backend-data: "Never saves 0 repos — if a fetch returns 0,
  existing cache is preserved"; thresholds per feed. Refuse to publish a
  catalog with fewer entries than the last one without an explicit flag.
  *confirms* last-known-good, at catalog rather than entry granularity.
- **Alert by opening an issue.** Both the pack and komi-data auto-file a
  GitHub issue on failure. Cheapest alerting there is. *fills gap*.
- **Delisting is a policy plus garbage collection.** IzzyOnDroid's removal
  criteria: license no longer free; "started downloading additional binaries
  without the explicit and informed consent of the user (e.g. by integrating
  a self-updater that is not strictly opt-in)"; malicious with evidence;
  unmaintained and reported broken; exceeds size with no remediation. It
  needed `bin/cleanIcons` because fdroidserver ignores orphaned icons;
  Accrescent's reposerver deletes older versionCode dirs on publish. The
  pipeline should remove R2 objects and art for delisted entries, and the
  client needs a Library state for "installed, no longer in catalog"
  (99 §20). *fills gap*.
- **Keep the previous object until the new entry is published.** Accrescent's
  directory publishes by delete-then-insert, which its own dossier flags as
  "loses history and any download counts you add later". Counters live in
  their own table keyed `(package, versionCode, variant, day)`; the
  superseded object is the rollback. *fills gap* (99: rollback story).
- **Generated artifacts are diff-checked in CI.** The pack's "regenerate and
  diff" gate. *fills gap*.
- **The pipeline's output is a reasoned report, not pass/fail.**
  fdroidserver 2.4.1 `verify` writes `<appid>.json` per app; IzzyOnDroid's
  `checkAntis.php` re-checks the latest package of every app for
  anti-feature drift "dragged in by a new library dependency". Cheap and
  it is the operator's weekly loop. *fills gap*.

### What one person actually runs

IzzyOnDroid: 1,393 apps, 2,786 versions, 424 of 428 commits by one person,
cron on a private box, no CI ever, two `require`d files missing from the
public tree. Komi: one Hetzner 4 vCPU / 8 GB VPS, `docker compose`, a
one-page `RECOVERY.md` targeting a sub-60-minute restore with `.env` in a
password manager and encrypted off-host dumps, `:previous` image tag for
seconds-long rollback. Both are "boring on purpose". tShop's stateless
design means recovery is mostly re-running the pipeline; the counter data is
the one thing that needs an off-host export. *fills gap* (99: operator
runbook).

## Hosting, stats and ranking

### Static files and cache keys

- **One byte-identical document for everyone is what makes CDN caching and
  anonymity both work.** Komi's `/feed` "never reads `X-GitHub-Token` —
  anonymity + shared-cache correctness both depend on it", and carries a
  `rotation` UTC date the client keys its cache on. tShop's catalog is
  already this; adopt the rotation-date idea as `generatedAt`. *confirms*
  02.
- **Fingerprint the repo in the URL; content-address the objects; cache the
  scan by mtime.** fdroidserver 2.3.0 switched its APK scan cache from
  sha256 to mtime+size while the published objects stayed hash-named.
  *confirms* 03's `sha256.apk` shape.
- **Content addressing also fixes "same filename every release".** ObtainX
  has a "Refresh app details before download" option because "a project
  reuses the same file name for each release; refresh reduces the chance of
  caching an old file". *confirms* 03.
- **Origin behind a CDN: honour `CF-Connecting-IP`, short-cache 404s, force
  HTTPS origin pull.** Komi found "every anonymous user behind a Cloudflare
  POP shared one bucket" until it keyed on the connecting IP, caches 404s
  for 300 s "so scanners and broken clients can't pin origin", and leaked
  its direct hostname through Caddy's auto-redirect until origin pull was
  HTTPS. Relevant to 03's rate-limit rule and the Hetzner spare. *fills
  gap*.
- **Index-only mirror mode exists for a reason.** fdroidserver 2.3.0
  `index_only:`; IzzyOnDroid rsyncs to mirrors excluding two index files
  with a single `sleep(10)` retry. The spare can carry catalog and art only
  if egress is ever the concern. *confirms* 03 option E.

### Counting and the stats page

- **Nobody else counts on a static host; F-Droid removed the feature.**
  fdroidserver 2.2.0 "Remove obsolete `fdroid stats` command", 2.3.0 "Drop
  all uses of `stats/known_apks.txt`". IzzyOnDroid's `iod-stats-builder`
  turns web-server logs into a JSON format the `iod-stats-collector`
  aggregates across mirrors; that is 03's Option B collector. Accrescent's
  directory has no counter table. 03's Worker counter has no prior art in
  the corpus; its "completed" definition is tShop's own to defend
  (99 §5). *confirms* that the design is unusual, not that it is wrong.
- **k-anonymity for public per-app numbers.** Komi's forward-looking
  developer analytics: "any bin shown contains at least 5 events." Neo Store
  hides its top-apps bar entirely "when there's no dl-stats" and consumes
  monthly, not daily, figures. Bucket low-volume entries to weekly and
  suppress below a floor. *fills gap* (99 §7).
- **Store raw cumulative totals per `(package, versionCode, variant, day)`,
  keep them ≥ 730 days, and never store deltas.** Komi's brief calls
  per-version granularity "the one irreversible cardinality decision" and
  warns "do NOT ship the retention worker with the feed's 90d default or it
  silently destroys dashboard history before the dashboard exists". 02's
  daily row already has this shape. *confirms* 02, adds retention.
- **A user-triggered action needs a global cooldown and budget.** Komi's
  repo refresh: POST not GET ("Cloudflare would cache the trigger"), 30 s
  per repo global, 1000/hr global, cooldown stamped before the upstream
  call, no optimistic UI, no auto-retry. Relevant if "Check for updates
  now" or "Report broken install" (99 §24) ever touches a live endpoint.
  *fills gap*.

### Ranking

Komi's `feed-v2-design-brief.md` is the only document in the corpus that
reasons about ranking from measured failure. Its v1 used a seeded reshuffle
of the top N by lifetime totals and never changed which repos were eligible;
"~750/2000 repos mathematically un-surfaceable". What it concluded, scaled
to 30–50 apps:

- Rank on **velocity**: daily deltas from raw cumulative snapshots, floored
  at zero ("a deletion is not negative momentum"), divided by actual days
  between observations, smoothed with an EWMA of half-life 7 days
  (`α ≈ 0.094`; "~2d thrashes; ~30d degenerates into a totals score").
- **Gate** momentum on a minimum base (komi: stars ≥ 50 or downloads ≥ 500)
  so a three-download app "surging" to six does not top the grid; normalize
  per signal with `log1p` and a clamped z-score before weighting.
- Add a **recency** term, `exp(−days_since_release/90)`, so a fresh update
  is visible; do not double-count it.
- **Cold start**: `COALESCE` velocity to a curated seed rank; komi's
  categories sort `search_score DESC NULLS LAST, rank ASC` with static rank
  as the tie-breaker. Download velocity is "genuinely cold for the first
  ~7–14 days". *fills gap* (99 §9: seed rank).
- **Skip** cooldown, exposure ledgers and coverage metrics. They exist
  because komi's eligible set (1–3k) dwarfs its feed (400–500). tShop's
  whole eligible set fits on one Browse screen. *challenges* importing
  feed-v2 wholesale.
- Keep the **client-never-sorts** invariant; the published order is the
  server's formula applied to public numbers, which is what makes it
  auditable (99 §9). *confirms* 02.

An editorial default also exists in the corpus: EmuTran's "Quick Setup —
one tap to install the recommended emulator set" is a curated starter
bundle that needs no stats. It fits 02's fresh-device flow and 99 §10's
suggestion of a device-local first frame. *fills gap*.

### Privacy policy wording

Komi's `PRIVACY.md` and its announcements privacy doc are the closest
peers, and their defects are the lesson:

- Their policy describes opt-in telemetry the day before the code killed
  it, disagrees with itself on log retention (7 vs 14 days), and names the
  wrong CDN. Version the policy in git and change it before the code does.
  *confirms* 01's intent, warns about drift.
- "❌ 'We do not log anything'" is on their list of things not to write;
  access logs exist. 01 already reconciles this for tShop's own host; 03
  should state the Cloudflare log posture explicitly too (99 §F nit).
- Enumerate **subprocessors** (Cloudflare, GitHub, Hetzner) with a rule that
  adding one requires a policy edit. *fills gap*.
- Write "what we never collect" as hard guarantees; komi's includes "Users
  who installed X also installed Y". That maps directly onto 01's no-dedupe
  decision. *fills gap* (99 §6).
- Aurora's "does not own, license or distribute any apps… works exactly
  like a door or a browser" and komi's "does not review, validate, or
  guarantee" are the grey-area store posture. tShop reviews, validates and
  redistributes, and 01 says the project owns mistakes. Do not borrow the
  door language. *challenges* any boilerplate disclaimer.
- Komi's DMCA section works because it is "a thin proxy… Most takedown
  requests belong upstream". tShop rehosts, so it needs an own-index
  takedown path with an SLA (komi: 7 days) and a delist-and-purge
  procedure. 03 §8 already notes R2 makes Cloudflare the host of record.
  *fills gap*.

### Announcements and what's new

Komi stores announcements as one JSON file each in the repo, validated in
CI, baked into the build, expiring by default at 90 days, with
`minVersionCode`/`maxVersionCode`, severity, category, a 50–600 character
plain-text body ("the 50-char floor blocks 'various improvements' filler"),
interlocks (PRIVACY ⇒ acknowledgement required; SECURITY ⇒ severity ≥
IMPORTANT), and a cadence rule of "≤ 1 non-security item per month… users
learn to dismiss reflexively". Its client what's-new is one JSON per
`versionCode` with `NEW|IMPROVED|FIXED|HEADS_UP` sections and
`showAsSheet=false` for bug-fix-only patches. Both fit inside tShop's signed
catalog with no new request path. *fills gap* (99 §4: a first-run notice
about counting is exactly an announcement).

## Client: installs, updates, states

### The install path

- **PackageInstaller sessions, package source set on SDK 33+, foreground
  service typed for Android 14.** Neo Store 1.0.0 "Package source to
  session installer (SDK33+)", "ForegroundServiceType for works (Required on
  A14)", 0.9.0 "Crash on A12+ (gotta disable battery optimization)". Aurora
  declares `UPDATE_PACKAGES_WITHOUT_USER_ACTION`, `ENFORCE_UPDATE_OWNERSHIP`
  and optional `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. Accrescent ships
  "Automatic, unprivileged, unattended updates (Android 12+)"; apkupdater
  lists "installs without user interaction on Android 12+" separately from
  its root path. *confirms* 99 §1's silent-update finding, with two
  requirements (battery exemption prompt, typed FGS) and one caveat:
  apkupdater still caps support at Android 14, so 15/16 behaviour is
  unverified in the corpus.
- **Re-check "Install unknown apps" at install time, deep-link, resume from
  the downloaded file, time out the dialog.** EmuTran v0.3.1 and v0.3.3: two
  separate install paths "silently did nothing" or hung on "Installing…"
  because the permission was only assumed from onboarding; the fix resumed
  from the already-downloaded file and added "a timeout [that] prevents the
  install from hanging indefinitely if the system dialog is dismissed". Neo
  1.0.6 skips the unknown-sources prompt when `INSTALL_PACKAGES` is already
  granted. *fills gap* (99 §22).
- **Map `INSTALL_FAILED_UPDATE_INCOMPATIBLE` to the "other source" state.**
  LibChecker's AGENTS.md names it as the result of a signing-key switch.
  *fills gap* (99 §19).
- **Classify the installer of record, and detect vendor preloads.** Komi's
  `InstallerCategory` orders SIDE_STORE (F-Droid, Obtainium, Aurora,
  Droid-ify, self) → SIDELOADED → VENDOR_STORE (Samsung, Huawei, Xiaomi,
  OPPO, vivo, HONOR, Amazon) → PLAY_STORE → SYSTEM_UPDATE using
  `getInstallSourceInfo` plus `FLAG_UPDATED_SYSTEM_APP`, and shows a source
  chip per app; Neo stores "full signing history in Installed". AppManager
  2.5.10 "Fixed wrong package installer name", so read initiating vs
  installing package carefully. This is the data 99 §19 needs to tell
  "Play copy, uninstall to switch" from "vendor preload, cannot uninstall".
  *fills gap*.
- **Keep `PackageInfo` queries narrow.** LibChecker: "Avoid broad
  `PackageInfo` flag combinations for huge apps; prefer focused lookups
  that keep Binder payloads below transaction limits." Emulators with many
  native libraries are huge apps. *fills gap*.
- **Archived apps (Android 15+) are a new installed state.** LibChecker 2.5.1
  records them; bundletool ships an ARCHIVE build mode with a stub
  `classes.dex`. Do not classify an archived stub as up to date. *fills gap*
  (99 §18).
- **Advanced Protection is an explain-and-stop state.** Android 16's opt-in
  mode greys out "Install unknown apps" for every app; Obtainium#2591 shows
  the stock installer call simply blocked. Detect it and say so rather than
  fail. It is why ObtainX exists (hand-off to a privileged installer via
  `content://`), but that is a power-user escape hatch, not a v1 path.
  *fills gap*.
- **Shizuku, when it comes.** Non-rooted Shizuku "needs to be manually
  restarted with adb every time on boot"; Android 16 drops wireless
  debugging often; the binder can die mid-install (`addBinderDeadListener`,
  `IllegalStateException`); `getUid()` is 0 or 2000 with different powers;
  Sui must be supported alongside or "it will cause user confusion"; call
  `IPackageInstaller` through `ShizukuBinderWrapper`, never scrape
  `pm install` text ("Super unreliable", per Shizuku's own README). Komi and
  EmuTran both fall back to the standard installer on Shizuku failure.
  *confirms* 01's "never required", *fills gap* on the later design.

### The queue

Neo Store's changelog is the specification nobody wrote: "Install tasks
restarter on running the activity", "Retries and backoff for InstallWorker",
"Improve installs queueing with checks, timeouts and retry counters",
"Crashes on update where some releases, tasks or downloads stuck in the
database", "Downloads deadlock in a semaphore one retries", "Reduce download
auto-retries to 3", "Limit number of parallel downloads to 3". EmuTran
adds: `updateAll()` mutex-guarded "preventing a double-tap"; buttons disable
on tap; "Update all respects cancellation between items"; cancelling
"immediately stops the foreground service and dismisses the notification";
range-resume with backoff; atomic writes so a disk-full or network drop
leaves no half-written file; a 1 GB free-space pre-check (R-Shop). Obtainium
writes `<id>.json.tmp` then `renameSync` and renames corrupt files
`*.corrupt` rather than failing.

Rules that fall out: one install at a time, at most two concurrent
downloads, three retries with backoff, resume by `Range`, atomic writes,
free-space check against the catalog's declared size before download, dedupe
by package, persist the queue and restart it on activity start, and the
Update All chain is a mutex not a loop. *fills gap* (99 §22).

### Version states

ObtainX's six states replace Obtainium's boolean: *up to date*, *update
available*, *device is ahead* ("Common with betas, sideloads, or sources
that lag behind the actual release — shown correctly rather than flagged as
a false update"), *same version shown differently*, *genuinely unclear*
("when a developer labels releases with commit hashes"), *not installed*.
Komi shows a downgrade warning before installing an older version and picks
the installed variant before comparing so a project that ships "generic +
Play APK" does not show a false Update. Neo fixed "Showing apps with one
release but different arch as new too" and "Returning products of the repo
with lowest id instead of highest versionCode".

For tShop: pick the variant first, compare versionCode second, and give
Detail the two extra outcomes 02 lacks — **newer than catalog** (quiet
"current", no rollback in v1) and **cannot compare**. Show the installed
version, not the latest (Neo 0.9.8). *fills gap* (99 §18).

### Self-update

Obtainium installs itself last in any batch and routes self-update through
Shizuku when available; EmuTran verifies a SHA-256 sidecar and hands off to
the system installer; Yalp chooses its F-Droid or GitHub feed by its own
signing cert; Neo 1.1.4 "Randomly need to clean cache after updating self".
Put tShop in its own catalog as an entry, gate by its own cert, install it
last, and expect the confirmation to kill the app. Publish the package id
and signing-cert SHA-256 on the project page as Obtainium does. *fills gap*
(99 §21).

### Notifications and background cadence

Neo's notification bug list, in order: "Annoying 0 updates notification",
"Showing updates notification even when disabled", "Duplicate sync
notification channels", "Notification following system language and not
the app's", "Fix: Clicking updates notification", "Sticking downloaded app
notifications". Rules: never post on zero, honour the switch, one channel
for updates and one transient for the queue (99 §2), localize with the app
locale, tap opens Library.

Cadence in the corpus: Neo 6 h then 8 h; Accrescent 4 h refresh, 8 h
auto-update; Obtainium 360 min on a 15-minute WorkManager floor; komi
re-checks on resume with a 30-minute cooldown "to catch drift after external
install while background-killed". Neo also needed "Safeguard to avoid
spamming sync" and "Fix: Index cache being removed by the system". Pick 6–8
hours plus check-on-resume, and bundle a catalog snapshot in the APK the way
EmuTran does (50 of 54 entries) so first launch and cache eviction still
render. *fills gap* (99 §16, §F cadence nit).

### Schema, changelogs, metadata

- **Version the catalog; migrations idempotent; refuse newer documents.**
  Obtainium runs `appJSONCompatibilityModifiers()`, "a chain of idempotent
  schema migrations", on every load inside try/catch; EmuTran's import has a
  "schema-version gate [that] rejects files produced by a newer version";
  komi's `/v1/` routes are "additive only" and its deprecated endpoint
  returns 204 rather than 410 because old clients "treat any non-2xx as
  failure and retry". *fills gap* (99 §21).
- **Declare the changelog format.** Neo 1.1.1 "App's changelog being parsed
  as markdown although it's standardized as text"; komi normalizes CRLF so
  GFM tables render. Normalize in the pipeline, carry `changelog_format`.
  *fills gap* (99 §17).
- **License on Detail, without value judgement.** Komi's `license-info.md`:
  hide the chip when null, "Don't render 'Unknown license'", do not
  colour-code permissive vs copyleft, do not validate SPDX on the client.
  The pack records no licenses at all; 99 §F asks for a rights basis per
  entry. *fills gap*.
- **Integrity on every path.** EmuTran shipped two install paths that
  installed unverified (v0.3.0 passed `null` as the expected hash; v0.3.4
  fixed the dashboard button). Content-addressed rehosting gives the client
  the hash for free; check it in Privacy Mode too. *confirms* 02.

## Console UI and input

### Flutter needs no gamepad plugin for tShop's input

R-Shop is Flutter with Riverpod and drives a controller-first grid entirely
through `Shortcuts`/`Actions`/`Intent` (`includeRepeats: false`,
`NavigateAction`, `_GridNavigateAction`); its dependency list never
includes a gamepad package. Flutter's Android embedding maps
`KEYCODE_BUTTON_A`..`Y` to `LogicalKeyboardKey.gameButtonA`..`Y` and the
d-pad to arrow keys. `pad_input`'s README puts it plainly: buttons "arrive
through Flutter, not through the plugin"; the one thing a plugin exists for
is analog sticks, whose `MotionEvent`s never reach Dart. *confirms* 01's
stack, *fills gap* on plumbing.

Two caveats:

- **Some controllers deliver the d-pad as `AXIS_HAT_X/Y`.**
  `gamepads_android` shipped d-pad Up/Down inverted on the hat axis until
  25 August 2026 (#128), which proves the path is real in the wild. Whether
  Retroid, AYN and Anbernic built-in pads use keycodes or hat axes is a
  per-device check, not a documentation one. *fills gap*.
- **Do not use `flutter_gamepads` for the grid.** Its defaults map d-pad
  up/left to "Previous focus" and down/right to "Next focus" — linear, not
  directional — and its required `MainActivity` swallows events before
  Flutter sees them; the package "broke keyboard input" (#127) and
  misdetected Bluetooth keyboards twice. If sticks are wanted, scope a
  plugin to sticks. *challenges* bolting on the obvious package.

### Focus, repeats, overlays

- **D-pad repeats, face buttons never; 100 ms navigation cooldown.**
  R-Shop 0.9.2 "DPAD hold producing duplicate navigation" → `NavigateAction`
  cooldown; 0.9.4 "no more repeated fires on button hold; D-pad retains
  repeats". `flutter_gamepads` lands on the same split. *fills gap*.
- **Budget for a key-normalization shim.** R-Shop installs a
  `gamepad_key_fix` in `main()` that "intercepts mismatched logical keys on
  key-up/repeat for certain gamepad drivers (AYN Thor etc.)". AYN is on
  01's device list. *fills gap*.
- **One focus owner with index and column memory.** R-Shop's
  `FocusSyncManager` tracks `_selectedIndex` and `_targetColumn`, clamps both
  when items disappear or column count changes, and had "silent focus
  failures" when the index pointed at a disposed `FocusNode`. Library tiles
  move between frames as state changes; this is the case that breaks.
  *fills gap*.
- **Block grid navigation while any overlay is open, restore focus on
  close.** R-Shop: `_GridNavigateAction.isEnabled` checks an
  overlay-priority provider; the variant picker "blocks D-pad left/right to
  prevent focus leak" and had to "restore D-pad focus" after the download
  queue closed. Applies to the screenshot viewer, Detail dialogs and search.
  *fills gap*.
- **Neutral, high-contrast focus ring.** R-Shop 1.5.1 moved to "white
  borders and glow instead of accent-color-only styling, ensuring clear
  visibility regardless of system theme color" and fixed "phantom focus on
  multiple elements simultaneously". *confirms* 01's "selected tile always
  obvious", prescribes the treatment.
- **Text fields eat arrow keys.** flutter/flutter#49335: arrow keys move the
  caret, not focus, in a text field; the fix is `DirectionalFocusIntent(...,
  ignoreTextFields: false)` in the app's shortcuts, or R-Shop's approach of
  Down/B handing focus from the field to the results. *fills gap*.

### Search

R-Shop filters live: "Type to filter games in real time by name. Press Down
or B to exit search and return to the grid", with a fix so "left/right
arrows no longer leak to grid while editing". That design assumes the grid
is visible under the keyboard, which Flutter's forced `IME_FLAG_NO_FULLSCREEN`
is meant to guarantee. On the AYN Thor it does not: the device's IME is a
full-screen modal in every app, a deliberate choice because a landscape or
square panel would otherwise leave an unreadable strip of UI above the
keyboard. Android's documentation allows exactly this ("some IMEs may ignore
it"), and any handheld with the same aspect ratios has the same reason to
do it. So 02's commit-then-view flow is the right default and R-Shop's live
filter is a per-device nicety at best. *confirms* 02 and 99 §15's premise.

What does carry over: `flutter_gamepads` confirms "Text input is currently
not supported via Gamepad input", so the system IME is the only keyboard; a
dedicated key (B, or Down at the end of the field) must leave the field and
land on results; and arrow keys inside the field must not move grid focus
(see *Text fields eat arrow keys* above). Typo tolerance (99 §15) remains
open; nothing in the corpus addresses matching.

### Buttons and layouts

- **Layout swap is a setting, and hints show glyphs.** iiSU: "Swap A/B and
  X/Y Buttons" for a Nintendo layout; R-Shop ships Nintendo, Xbox and
  PlayStation layouts and an SVG glyph set for "context-aware controller
  hints" in a slot-based HUD (`a, b, x, y, start, select, dpad`). 02 never
  says which physical button confirms; both references make it a user
  choice and label it on screen. *fills gap*.
- **Convergent conventions.** R-Shop: A confirm, B back, X info/filters,
  Y search, L1/R1 column zoom, L2/R2 tabs, Start quick menu, Select
  favourite; iiSU: Select opens settings or a tile's quick menu, Y swaps
  screens. 02's shoulder buttons for Browse/Library/Settings collide with
  R-Shop's zoom; L2/R2 for tabs is the closer precedent. *fills gap*.
- **B on the root screen confirms exit.** R-Shop. *fills gap*.
- **Design for 4:3 and 16:9 at once.** R-Shop 1.5.1 replaced "hardcoded
  pixel constraints with screen-relative `clamp()`" across nine overlays and
  dropped icon-button labels that wrapped on 4:3. Retroid Pocket is 4:3,
  Odin is 16:9. Obtainium's own breakpoints (`NavigationRail` at ≥ 600,
  two-pane at ≥ 900) put a landscape handheld in Flutter's tablet tier;
  ObtainX's complaint that Obtainium adapted one screen argues for
  landscape-first on every screen. *fills gap*.
- **Touch focuses and activates in one tap, and moves the cursor.** R-Shop
  0.9.1 "click to focus and activate" on every focusable widget, with
  debouncing against "double-tap actions and duplicate sounds". *confirms*
  01's two complete input methods, *fills gap* on coexistence.

### Feel and performance

- **Cheap tiles.** R-Shop replaced `AnimatedScale`/`AnimatedContainer` with
  static transforms, rebuilds only the affected card on selection via
  `ValueNotifier`, suppresses image loads during fast scroll, and tiers
  caches by RAM ("for low-end handhelds"). EmuTran "moved package scans off
  the main thread for smoother performance on mid-range handhelds". *fills
  gap*.
- **Corner status persists for errors.** R-Shop's amber pill that
  "auto-dismissed after 6s" was "easy to miss" and became red and sticky;
  its download indicator is "a pulsing indicator in the top-left corner".
  02's Wi-Fi glyph should carry offline and error, and 99 §3's reachability
  probe decides what it shows. *confirms* the glyph, extends it.
- **Focus is hover; prefetch on it.** iiSU fires a background request when a
  tile is hovered; R-Shop swaps the backdrop to the selected cover. Warm
  the Detail payload when a tile gains focus. *fills gap*.
- **One primary action with explicit states, focused by default.** R-Shop's
  `DownloadActionButton` states are "download, delete, installed, adding,
  unavailable"; entering Detail focuses it; destructive confirms default to
  Cancel. *confirms* 02's single button, adds the in-flight states 99 §F
  asks for.
- **TalkBack focus is a second cursor.** AccessibilityDemo distinguishes the
  green accessibility rectangle from the orange app focus; custom-drawn UI
  must expose nodes with bounds, class, description and actions. Flutter
  tiles are that case: every tile needs a semantic label tied to the visual
  selection. *fills gap* (99 §F accessibility nit).
- **Phone app in immersive mode, not Leanback.** R-Shop and iiSU both are;
  Leanback's row-per-category model is not 02's continuous sectioned grid,
  and no peer store in `10-store-clients` addresses d-pad input at all (Neo
  lists "AndroidTV support" as a future nice-to-have). The niche is open.
  *confirms* 01.

## Where this argues against the current specs

Collected so the edits to 01, 02 and 03 are one pass:

| Spec text | Corpus says | Action |
|---|---|---|
| 02: one expected signing identity per entry | Two legitimate RetroArch builds have two signers; IzzyOnDroid makes an allowlist mandatory; rotation is human | Allowlist of certs per entry, with reasons |
| 02: popularity rank from download counts | Totals are lagging and incumbent-biased; komi moved to velocity | Publish rank from 7-day EWMA of daily counts, gated, coalesced to a seed rank |
| 01: Shizuku later, otherwise standard installer only | Advanced Protection blocks the standard path outright; vendor preloads cannot be uninstalled | Add explain-and-stop states; keep Shizuku later |
| 01/02: nightly is a policy question | The pack lists nightlies but never auto-installs; several frontends are pre-release-only | Per-entry `channel`; "prerelease is the only channel" allowed; never two entries for one id |
| 01: "APK-based applications only" | Track-only resources (drivers) and `.xapk` are in the ecosystem | State the exclusion and reject containers explicitly in the pipeline |
| 03: rehost decided per app for license reasons | Also for abandonment (DuckStation) and dual-signer situations (RetroArch) | Landing Page reasons are a small enum, not a boolean |
| 01: "Free Software, run in public"; no mention of developer verification | 2027 global enforcement on certified devices; F-Droid opposes; a status API exists | Decide a position; register tShop; add a per-entry verification status |
| 03 §Degenerate cases: counter poisoning is the main abuse | Komi's own client retry storms were the real incident; a deprecated endpoint must return 2xx | Client backoff on catalog errors; additive-only schema |

## What is not settled by the corpus

- **Developer verification's effect on a third-party store.** The mechanics
  for stores ("verification capability will soon be expanded to all
  third-party Android app stores") are not published. Whether tShop must
  call a verifier before install, or merely warn, is unknown. Track it;
  design the catalog field now.
- **d-pad delivery on the named devices** (keycodes vs hat axes) and the AYN
  Thor key-up mismatch. Hardware checks. The IME question is answered for
  the Thor (full-screen modal by design); Retroid and Odin are unchecked
  but share the aspect-ratio rationale, and the search design no longer
  depends on the answer.
- **Silent updates on Android 15/16.** No peer in the corpus claims support
  above 14. Device matrix, as 99 §1 already asks.
- **Typo-tolerant search matching.** Nothing in the corpus addresses it.
- **Screenshot and artwork rights.** The only model is apps.obtainium's
  hotlinking, which rots. Per-entry rights basis remains 99 §F's ask.
- **Whether Eden-class Switch emulators belong on tShop's domain.** The
  corpus confirms they are GPL and active; 03 already frames it as a policy
  flag.

## What this document is not

It is not a catalog worksheet, a pipeline design, a focus specification or
an edit to 01–03. It collects what the reference corpus and the web checks
say, so that those documents can be written or amended with evidence rather
than recollection. Items here should be resolved into 01, 02, 03 and the
infrastructure plan and then this document can go stale without harm.
