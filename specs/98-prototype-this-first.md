# Prototype this first

> The parts of tShop most likely to be wrong, ranked by how much of the
> spec they take down with them, and the smallest experiment that settles
> each one.

This document reads [01-prd.md](01-prd.md), [02-screens.md](02-screens.md),
[03-hosting-and-bandwidth.md](03-hosting-and-bandwidth.md),
[04-oppo-research-lessons.md](04-oppo-research-lessons.md) and
[99-spec-critique.md](99-spec-critique.md) for one purpose: to find the
claims that are load-bearing, unverified, and cheap to test. It is not a
milestone plan. Nothing here ships. Every item is a throwaway harness, a
script, or a spreadsheet whose only output is an edit to another spec.

Written September 2026. The client at this point is a Flutter composition
root with a placeholder route and no features, so no prototype below has to
work around existing code.

## How items were chosen

A part of the application is on this list when it meets at least one of
these tests:

- **The spec asserts something about hardware or the platform that has not
  been observed on the target devices.** If the assertion is false, the text
  of 01 or 02 changes, not just the implementation.
- **No peer in the reference corpus has built it.** 04 §9 is explicit that
  the completed-download counter has no prior art; nobody else's changelog
  will warn tShop what goes wrong.
- **Every peer that built it spent years fixing it.** 04 §7: the installer is
  the most failure-prone subsystem in every store surveyed.
- **It gates the size of the catalog**, which 99 §25 identifies as the one
  number the product's cost hangs from.
- **The target hardware offers something no peer store uses.** The AYN Thor
  ships a run-as-root facility; nothing in the corpus asks what a store
  could do with it.

A part is deliberately *not* on the list when it is server-side and
reversible, when it is a design question rather than an empirical one, when
it concerns phones and tablets rather than handhelds (01 is explicit that
they do not drive the design), or when the reference corpus already answers
it. Those are collected under [Declined](#declined-do-not-prototype-these)
so nobody re-argues them.

Items are in three tiers:

- **Tier 1 — the spec is wrong if this fails.** Results rewrite 01 or 02.
  Do these before writing the infrastructure plan.
- **Tier 2 — the build is wrong if this fails.** Results change how a
  subsystem is constructed, not whether it exists. One item in this tier is
  exploratory rather than a yes/no test and is marked as such.
- **Tier 3 — measure, do not build.** Scripts and worksheets. No app code.

## The list at a glance

| # | Prototype | Tier | Question it answers | Rewrites | Cost | Needs |
|---|---|---|---|---|---|---|
| 1 | Silent update matrix | 1 | Is Update All silent, or ten dialogs? | 01 installs, 02 Library, Android floor | 3–4 days | all handhelds |
| 2 | Controller input reaches Flutter **(done)** | 1 | Does the d-pad arrive at all, and as what? | 01 controllers, stack decision | 1–2 days | all handhelds |
| 3 | Fresh-device signer survey | 1 | What fraction of the launch list is "other source" out of the box? | 02 mismatch state, launch list | 1 day | all handhelds, fresh |
| 4 | Worker completion counter | 1 | Can a Worker count a full 200 MB download at ~zero CPU, exactly once? | 03 Option A vs B, 01 policy wording | 2–3 days | CF account, one handheld |
| 5 | Sectioned focus grid **(done)** | 2 | Does one focus owner survive frames, reframing, overlays, 4:3 and 16:9? | 02 Browse/Library, focus spec | 3–5 days | Retroid + Odin |
| 6 | Install queue skeleton | 2 | Does the queue survive reboot, dismissed dialogs, revoked permission, double-tap, leaving the app? | 02 queue rules (99 §22) | 3–4 days | reuses #1 |
| 7 | Non-GitHub source adapters | 2 | How often do the HTML and JSON sources break in two weeks? | pipeline design | 2 days + 14-day soak | none |
| 8 | Root and Shizuku on the Thor | 2 (exploratory) | What does a store gain from a device that will run a script as root? | 01 Later, Shizuku design | 3–5 days | AYN Thor |
| 9 | Launch-list attrition worksheet | 3 | How many of ~30 candidates survive every rule? | 01 catalog, 03 Landing Page | 1–2 days | outputs of 3, 7 |
| 10 | Upstream URL stability | 3 | Does Privacy Mode's upstream URL serve the validated bytes a week later? | 01/02 Privacy Mode | 0.5 day + 7-day soak | none |
| 11 | Cost of one finished entry | 3 | How many hours does a complete entry take? | 01 catalog size (99 §25) | 5 entries' worth | none |
| 12 | IME shape on Retroid and Odin | 3 | Does the keyboard cover the grid, and can it be typed on with a d-pad? | 02 Search | 1 hour | Retroid + Odin |

Items 7 and 10 have soak periods. Start them on day one so their results
are ready when the short ones finish.

## Tier 1 — the spec is wrong if this fails

### 1. Silent update matrix

**Risk.** 02's Library section says tShop "cannot install anything itself"
and walks the user through one system dialog per app. 99 §1 says that on
Android 12+ an installer of record that declares
`UPDATE_PACKAGES_WITHOUT_USER_ACTION` and commits with
`setRequireUserAction(USER_ACTION_NOT_REQUIRED)` gets no dialog for updates.
04 confirms Aurora, Accrescent and apkupdater ship this, and then notes that
apkupdater caps support at Android 14 and nothing in the corpus claims 15 or
16. Both documents are arguing from documentation. The named devices run
stock firmware that 99 §21 says skews Android 12 and 13, with vendor
modifications nobody has characterised.

The product is named after this. "Updates must be boring" is either a
one-dialog-then-silence store or a d-pad-operated dialog chain, and 01 and
02 currently describe the second while 99 argues for the first.

**Build.** A plain Kotlin harness app, not Flutter, because the question is
about the platform and iteration is faster. Two dummy APKs, v1 and v2, same
key, current targetSdk. The harness:

- installs v1 through a `PackageInstaller` session and records whether the
  system dialog appears and whether it can be accepted with the d-pad alone,
  including where focus lands by default;
- commits v2 with `USER_ACTION_NOT_REQUIRED` and records whether a dialog
  appears;
- repeats v1→v2 where v1 was installed by `adb`, by the stock file manager,
  and (where a Play-signed build of a real app exists) where Play is the
  installer of record, to see `STATUS_PENDING_USER_ACTION` and the Android
  14 update-ownership consent path in the wild;
- updates itself, since 04 says the confirmation may kill the app and
  self-update is 99 §21's unhandled case;
- runs once with battery optimisation on, because Neo Store 0.9.0 crashed
  on A12+ until it was disabled.

**Record.** One row per device × Android version × installer-of-record ×
operation: dialog shown, d-pad-acceptable, result code. Also the exact
Android versions of every device in the matrix, which becomes 01's supported
floor.

**Gates.** The Library text in 02, how much of #8's root path is still
needed once the unprivileged path is measured, the Android floor 99 §21
asks for, and whether 04's "typed foreground service" and "battery
exemption prompt" are requirements or noise.

### 2. Controller input reaches Flutter

**Risk.** 01 makes controllers first-class and 04 finds the plumbing is
free: Flutter maps `KEYCODE_BUTTON_A..Y` to `gameButtonA..Y` and
`KEYCODE_DPAD_*` to arrow keys, and R-Shop drives a whole grid with
`Shortcuts` and no plugin. The same section then lists three ways this
fails: some controllers deliver the d-pad as `AXIS_HAT_X/Y`, whose
`MotionEvent`s never reach Dart; the AYN Thor mismatches logical keys on
key-up and R-Shop ships a shim for it; and `gamepads_android` had the hat
axis inverted until 25 August 2026, proving the axis path is what real
devices use. 04 closes with "a per-device check, not a documentation one".

If the built-in d-pad on a Retroid or Odin arrives as a hat axis, Flutter
sees nothing without a platform channel, and the stack decision recorded in
99 §Excluded is incomplete.

**Build.** A debug route in the existing client that dumps every
`KeyEvent` (physical key, logical key, repeat flag, down/up) and, through a
ten-line platform channel, every `MotionEvent` with `SOURCE_JOYSTICK` or
`SOURCE_DPAD`. Press every control on each device's built-in pad and on one
Bluetooth pad. Hold the d-pad and record the repeat cadence. Hold A and
check whether it repeats, since 04 wants d-pad repeats and face buttons
never.

In the same session, and with the same devices in hand, check the two
places 02 sends the user out of the app: can the stock "Install unknown
apps" Settings page be toggled with the d-pad alone, and can the system IME
type a search query with the d-pad alone? 01 says no essential control may
require touch. Onboarding and Search both depend on system UI tShop does not
draw.

**Gates.** Whether the client needs a native input plugin (and for what),
whether the Thor shim is one device or a pattern, whether Onboarding must
warn that a step needs touch, and the repeat/cooldown numbers for the focus
spec.

**Result.** 2026-09-04, AYN Thor, kitchens in `prototypes/flutter-ui-tests`
and `prototypes/compose-ui-tests`. D-pad events arrive. Stock widget
focus does not. The kitchen dies in the text field: once that input has
focus, nothing else on the page is focusable — D-pad cannot leave, and
tapping further down the page does not move focus either. Flutter
Material, phone Compose Material3, and `androidx.tv.material3` all do
this. Compose TV glow/scale is not a rescue. Picking Compose does not
buy a free D-pad UI. A hand-rolled focus owner is required either way.
Hat-axis / Thor key-up on Retroid and Odin still worth a desk pass; they
do not change the stack decision.

### 3. Fresh-device signer survey

**Risk.** 99 §19 calls the signature-mismatch state "the first-run
experience" and asks the project to "count the Play-conflicting entries
before committing to 50". Retroid and Anbernic ship vendor-signed emulators
preinstalled; many catalog apps also exist on Play with a different key
than their GitHub APK; RetroArch has two legitimate signers (04 §Not
everything is rehostable). Preinstalled system apps cannot be uninstalled,
and 02 has no state for that. If a third of the launch list is greyed out
on a fresh Odin, the mismatch state is the product.

**Build.** An `adb` script run against each device in factory state:
`pm list packages -f`, `dumpsys package` for signer digests,
`getInstallSourceInfo` equivalents via `pm`, and `FLAG_UPDATED_SYSTEM_APP`.
Join against upstream signer digests from one `apksigner verify
--print-certs` pass over the candidate APKs, downloaded once by hand. While
the shell is open, dump `getSystemFeature()` results, GPU vendor, and SoC,
since 99 §12 warns that capability tags on inconsistent
`getSystemFeature()` output will grey working apps, and 04 wants
`gpu:adreno` as the first tag.

**Record.** Per device: which candidates are preinstalled, with which
signer, whether they are system apps, whether Play holds the update
ownership. Per candidate: how many devices it conflicts on.

**Gates.** Whether "Installed from another source" needs its own design
pass (data-loss warning, Uninstall offered in the one state where 02 does
not offer it, a "cannot uninstall" state); whether the launch list prefers
apps whose canonical build is the one tShop ships; the first capability tag
and whether the client can evaluate it honestly.

### 4. Worker completion counter

**Risk.** 03's recommended architecture rests on a Cloudflare Worker that
streams a 200 MB object from R2 at near-zero CPU and counts exactly once
when the whole body has been piped. 04 §9 confirms no peer has built this,
and 99 §5 says "completed" is the whole measurement and is undefined. 03
itself lists the ways it fails: a per-chunk `transform()` hits the 30 s CPU
limit (workers-rs#389); a counted `Range` is a free fake download; a
"Cache Everything" rule bypasses the Worker silently. Two more that 03 does
not test: whether the client's download stack ever splits a transfer into
ranges, in which case a full-200-only counter records zero; and whether
"piped to the edge" fires on a client that aborted at 97 percent, which
the policy says must count zero.

If the counter cannot be made honest, 03 falls back from Option A to
Option B's log rollup and 01's policy paragraph about what the host writes
down changes.

**Build.** Deploy the Worker as 03 describes it: `FixedLengthStream(size)`,
`object.body.pipeTo(writable)` unawaited, `ctx.waitUntil(pipe.then(record,
ignore))`, 206 for single ranges, 4xx for multi-range, count only on full
200. Put a real 200 MB APK in R2. From a handheld on Wi-Fi, using the
download stack the client will actually use (Dio is already in
`pubspec.yaml`; `DownloadManager` is the alternative), run:

- a clean full download — expect one count and read the CPU-ms from the
  Workers dashboard;
- an abort at 97 percent — expect zero;
- a resume by `Range` after the abort — expect zero, and note the
  undercount;
- a one-byte tail range and a multi-range request — expect zero and a
  rejection;
- twenty parallel full downloads — expect twenty, and check whether D1 or
  Analytics Engine is the right sink at the hot-row rate 03 estimates;
- the same download with a `Cache Everything` rule accidentally applied —
  confirm the count disappears, so the failure is known before someone does
  it for real.

Measure throughput from the EU, a US VPN, and an APAC VPN, since 03 dismisses
Hetzner on latency and that claim should have a number too.

**Gates.** Option A or B in 03; the "completed" sentence 99 §5 asks 01 to
add; whether the client must be told never to parallelise downloads; the
Worker CPU column, which is the difference between $5 and a CPU-limit
error on RetroArch.

## Tier 2 — the build is wrong if this fails

### 5. Sectioned focus grid

**Risk.** 02's Browse is one continuous grid sectioned into framed category
groups, and Library is the same grid whose frames are states, so tiles move
between frames as downloads complete. 04's R-Shop lessons are a list of
ways this breaks in Flutter: a single focus owner with index and column
memory that must clamp when items disappear; "silent focus failures" when
the index pointed at a disposed `FocusNode`; d-pad repeat producing double
navigation until a 100 ms cooldown; overlays leaking focus to the grid
behind them; text fields eating arrow keys (flutter/flutter#49335);
hardcoded pixel constraints wrapping on 4:3; "phantom focus on multiple
elements"; `AnimatedScale` too expensive for low-end handhelds. Flutter's
default `FocusTraversalPolicy` is not designed for a grid whose frames have
different column counts.

None of this changes 02's text. All of it changes how the grid is built,
and the grid is most of the client.

**Build.** In the client, against a hand-written catalog of 40 fake
entries: the Browse grid with four frames, d-pad traversal across frame
boundaries, a Library variant where a timer moves tiles between frames
every few seconds while focus is on them, a modal overlay (the screenshot
viewer stand-in) that must block grid navigation and restore focus on
close, and a search field that must not move grid focus while typing and
must hand focus down on B or Down. Run it on the 4:3 Retroid and the 16:9
Odin. Profile a fast scroll with image loading on the lowest-end device in
hand.

**Gates.** The focus specification 99 §Excluded says is not yet due, but
which becomes due the moment this prototype works; whether tiles need a
custom traversal policy or a hand-rolled focus manager; the 4:3 layout
rules; whether the input shim from #2 lives in `main()` as R-Shop's does.

**Result.** 2026-09-04, AYN Thor. The 40-entry framed grid was not
built. The widget kitchens already settle the construction question:
stock `FocusTraversalPolicy` and Compose TV focus are both a trash fire
for D-pad. Once the text field has focus, the rest of the page is dead
— D-pad cannot leave, and touch cannot move focus further down either.
Browse/Library need a hand-rolled focus owner regardless of toolkit.
Worst case, and acceptable: every control is annotated with the four
neighbors — "on [DIRECTION], focus this" — and the owner only honors
that graph. Stock policy is ignored. Static screens can paint the
graph by hand; the framed grid generates the same edges from index
and column so tiles that move still have a next. The text field is
the first annotation: Down/B leaves, arrows inside stay caret.
The framed-grid survival cases (tiles moving between frames, 4:3 wrap,
overlay restore) become tests of that owner, not a reason to hope the
platform will do it.

### 6. Install queue skeleton

**Risk.** 99 §22: the queue's rules are one sentence. 04 §7 reconstructs
them from Neo Store and EmuTran's changelogs: sessions stuck across
reboots, dialogs dismissed leaving "Installing…" forever, two install paths
that "silently did nothing" because "Install unknown apps" was only checked
at onboarding, a double-tap on Update All starting two chains, semaphore
deadlocks, retries without a cap. Every one of these is a bug the corpus
paid for. 02's rule that the confirmation chain pauses when the user leaves
Library and resumes on return is a state machine with no specification.

The queue also carries the corrected update model (see [Spec corrections
surfaced by this pass](#spec-corrections-surfaced-by-this-pass)): all
work happens while the app is open or while its foreground service is
running, so "the user leaves the app entirely mid-queue" is the case the
queue must handle well, not an edge.

**Build.** Extend #1's Kotlin harness into a persisted queue with the rules
04 derives: one install at a time, two concurrent downloads, three retries
with backoff, `Range` resume, atomic writes, a free-space check against the
declared size, dedupe by package, persistence and restart on activity
start, downloads owned by a foreground service typed `dataSync`. Then abuse
it: reboot mid-download and mid-staged-session; dismiss the system dialog
and wait; revoke "Install unknown apps" between download and install; tap
Update All twice; fill the disk; pull Wi-Fi at 50 percent; leave and return
to the harness's Library screen during the chain; swipe the app away with
the foreground service running and see whether the download completes and
what the install chain does when the user comes back. Record what state
each abuse leaves behind and whether the queue recovers without user
action.

**Gates.** The queue rules that 02 must gain, the confirmation-timeout
value, whether the foreground service's notification is the only
notification tShop posts, and the failure-reason vocabulary, including the
Privacy Mode "upstream unreachable" reason 99 §22 wants distinguished.

### 7. Non-GitHub source adapters

**Risk.** 04 §3: about a quarter of the essential emulators are not on
GitHub Releases. Dolphin, PPSSPP and ScummVM are HTML download pages; Play!
and RetroArch are directory listings, RetroArch two hops deep on
`buildbot.libretro.com` whose stable directory changes without a version
change; Eden is a self-hosted `release.json`. The Obtainium Emulation Pack's
FAQ says these "can break if the site changes its layout", and its answer
is a daily job that resolves every entry and files an issue per failure. 01
promises the store, not the device, absorbs this. That promise costs
whatever the breakage rate is.

**Build.** Adapters for exactly RetroArch buildbot, Dolphin, PPSSPP,
ScummVM, Play! and Eden, plus GitHub Releases and GitHub Releases in a
separate builds repo (Vita3K). Each resolves to `(versionName, versionCode
if visible, APK URL, size, sha256 if published)`. Run them from cron every
six hours for fourteen days with conditional GETs and an honest User-Agent,
per apps.obtainium's rule against spoofing. Log every change in output and
every failure. Keep the APKs the first run downloads; they are the fixtures
for #3, #9, #10 and for the pipeline's eventual test suite.

**Gates.** How much of the pipeline is adapters versus gates; whether a
`direct-link` adapter with a curated URL is more reliable than scraping for
some entries; what the monitor-death heartbeat (99 §13) should look like
in practice.

### 8. Root and Shizuku on the Thor (exploratory)

**Risk.** Not a risk of being wrong; a risk of leaving value on the table.
01 defers Shizuku to Later and says it must never be required. 04 documents
why unprivileged Shizuku is miserable: it "needs to be manually restarted
with adb every time on boot", Android 16 drops wireless debugging, the
binder dies mid-install, Sui has to be supported alongside. Every one of
those complaints is about *getting* privilege, not *having* it. The AYN
Thor ships a facility, as an entry in its Settings app, that lets the user
run a shell script as root. It is user-invoked, not app-invoked, so tShop
cannot call it; what tShop can do is ship the script and walk the user to
the Settings entry, the same shape as Onboarding's "Open Settings" step for
"Install unknown apps". That removes the getting problem for one device
today, and 01's device list is short enough that "one device" is a
meaningful fraction of users.

Nothing in the corpus asks what a store does with root it did not have to
beg for. The corpus does say what privilege buys: Accrescent's "automatic,
unprivileged, unattended updates" is the ceiling without it; with it,
first installs need no dialog, apps tShop did not install can be updated
silently, and updates can run when the app is not open, which the
corrected model in this document otherwise gives up.

**Build.** On the Thor, in order of increasing ambition, and stopping at
the first tier that is enough:

1. Use the root facility to start Shizuku (or Sui) at boot so it persists
   without adb. Then drive `IPackageInstaller` through
   `ShizukuBinderWrapper` from #1's harness, never `pm install` text, and
   re-run #1's matrix. Record which rows go silent.
2. Grant the harness what Shizuku would otherwise proxy: try `pm grant` and
   `appops` for the install-related permissions, and note which are
   signature-or-privileged and therefore refuse. Record whether anything
   short of a privileged install is enough.
3. Install a small supplementary package as a privileged system app (or
   have the root script do so), exposing one bound service that tShop calls
   to install a staged session. Measure whether it survives a firmware
   update and a reboot, and whether it can run an update check and install
   while tShop itself is not open.

Each tier answers: what becomes silent, what survives reboot, what the
user had to do once, and what breaks on the next firmware update.

The walkthrough is part of the prototype, because it is the part the user
sees. Record: whether tShop can deep-link to the Settings entry or only
describe where it is; where the script has to live on disk for the entry to
find it, and whether tShop can write it there; whether the entry can be
reached and confirmed with the d-pad alone; whether the script's effect
persists across reboot or the user has to run it again; and how many
screens the whole thing takes. If the answer is "once, three screens,
d-pad-only", this is an optional Onboarding step on the Thor. If it is
"after every reboot", it is a Settings-page instruction and tier 3's
supplementary package, which installs once and stays, is the only tier
worth shipping.

**Gates.** 01 §Later §Silent updates, which currently names Shizuku alone;
whether the "boring updates" story on the Thor is a different, better
story than on other devices and whether 02 should say so; whether a
supplementary privileged package is a v1.x deliverable or a curiosity.

## Tier 3 — measure, do not build

### 9. Launch-list attrition worksheet

**Risk.** 01's open question "which 30 to 50 apps" is treated as taste. 03
removes entries for licence (ES-DE, NetherSX2, DuckStation). 04 removes
more for closed sources, same-id forks and pre-release-only channels, and
adds targetSdk, ABI, container and dual-signer rules. #3 adds preinstall
conflicts. Nobody has applied all of these to one list at once. The number
that survives is the catalog, and 99 §25 says the catalog size is the
project's real budget.

**Build.** One spreadsheet, one row per candidate from 04 §The launch list
and `android-foss`, one column per rule: rehostable (yes / landing / omit,
with the reason enum 04 asks for), source type from #7, signer conflict
count from #3, targetSdk and ABIs from one `aapt2 dump badging` pass over
#7's downloaded APKs, container type, channel, size, and a "canonical build
is the one tShop ships" flag.

**Gates.** The launch list itself; the category list, once the survivors
are grouped; the ratio of Install to Landing Page entries, which decides
whether Landing Page is a footnote or a second primary action.

### 10. Upstream URL stability

**Risk.** 01 and 02 say Privacy Mode fetches "that same validated file from
upstream" and the client checks the hash on every path (04 §Integrity on
every path). That assumes the upstream URL captured at validation time
still serves the same bytes when a Privacy Mode user asks for them. 04 notes
RetroArch's stable directory changes without a version change and ObtainX
has a "refresh before download" option because projects reuse filenames.
GitHub release assets are redirect-based. If upstream mutates, Privacy Mode
fails with a hash mismatch on the entries where it matters most, and the
switch reads as "turning this on breaks installs".

**Build.** For each candidate, record the upstream URL and sha256 from
#7's first run, then fetch the same URL daily for a week and compare. Note
redirects, `Content-Length` changes, and 404s.

**Gates.** Whether the catalog needs a "Privacy Mode unavailable for this
entry" flag, whether some upstream URLs must be pinned to immutable release
assets rather than "latest" paths, and the wording of the failure reason
in 99 §22.

### 11. Cost of one finished entry

**Risk.** 01's quality bar: identity, source, name, summary, description,
category, square tile from official assets, larger artwork, screenshots,
version, changelog, compatibility notes, plus the rights basis for every
image (99 §F). 04 §What is not settled says the only artwork model in the
corpus is hotlinking, which rots. No one has measured how long an entry
takes, and 99 §25 says the catalog size should be derived from hours, not
taste.

**Build.** Produce five entries completely, chosen to span the hard cases:
one with a press kit (PPSSPP), one GPL emulator with no square icon
anywhere, one FOSS game, one utility with no screenshots, one Landing Page
entry. Time each step. Record where every image came from and under what
licence.

**Gates.** Catalog size for v1; the minimum screenshot rule 01 leaves open;
whether AI-assisted asset search is a real saving or a review burden; the
per-entry rights field 99 §F asks for.

### 12. IME shape on Retroid and Odin

**Risk.** Small and nearly resolved. 04 §2 confirms the AYN Thor's IME is a
full-screen modal by design and that 02's commit-then-view search stands
regardless. Retroid and Odin are unchecked. If either docks the keyboard,
live filtering becomes a per-device nicety rather than a redesign, and
knowing which devices dock costs an hour while they are on the desk for #2.

**Build.** Open any text field on each device, photograph the screen, and
note whether the grid area remains visible. Already covered for d-pad
typing under #2.

**Gates.** A one-line note in 02 about optional live filtering.

## Spec corrections surfaced by this pass

Not prototypes. Places where reading the five documents together showed
that 01 or 02 promises something the design cannot deliver, and the fix is
an edit rather than an experiment.

**Background update checks and the update notification.** 01 says tShop
"periodically checks the approved catalog in the background" and "sends
one useful notification"; 02 says background checks are "always on" with
no switch and lists a summary notification as a surface. With no accounts
and no device identity there is no push channel, and 04 shows that every
peer that relied on WorkManager for this spent releases fighting OEM
background killing and evicted caches. The honest model is: check the
catalog when the app is opened or resumed, run downloads and the install
chain inside a foreground service so leaving the app does not lose them,
and post no notification other than the foreground service's own. That
removes the Settings switch for update notifications, shrinks Onboarding's
notification permission to the foreground service's needs, and moves
"Update All while you sleep" to the privileged path #8 explores. 01
§Installs and updates and 02 §Settings and §Surfaces that are not screens
should be rewritten to say this.

## Declined: do not prototype these

Listed so the list above stays short and so the decision not to prototype
is recorded as a decision.

- **Developer verification.** 04 §1 treats it as existential. It is not a
  tShop problem: Obtainium, every Obtainium pack, and every sideloaded APK
  on the same device share it exactly. Handhelds whose value is sideloaded
  emulators cannot ship with the verifier enforced without killing the
  product, and the policy is contentious enough that global enforcement on
  the 2027 schedule is doubtful. Watch it; do not design the catalog around
  it yet.
- **Validation gates on real APKs.** Running 04's eleven-step gate list
  over the candidate APKs is worthwhile, but as the pipeline's test suite,
  with #7's downloaded APKs as fixtures, not as a prototype. Nothing about
  the design changes if a gate fails on a candidate; the candidate does.
- **Background-check survival under OEM killers.** Moot once the correction
  above lands; there is no background check to keep alive.
- **Advanced Protection, 16 KB kernels, archived apps.** Android 16 phone
  features. 01 says phones and tablets do not drive the design, and the
  handhelds will not run 16 for a long time. The pipeline can keep a 16 KB
  alignment lint as a note field; nothing else needs to move.
- **The ranking formula.** 04 §Ranking gives a complete design (7-day EWMA,
  gated on a base, coalesced to a seed rank). It runs server-side, the
  client never sorts, and it is cold for the first 7–14 days regardless.
  Wrong values are a republish, not a client release. Simulate on synthetic
  numbers when the pipeline exists.
- **Catalog signing and key rotation.** No peer has a rotation protocol (04
  §Signing the catalog), so there is nothing to test against; this is a
  design document, not an experiment. Ed25519 verification of a small
  pointer in Dart is a known quantity.
- **The stats dashboard.** 99 §8 already resolves it: static output of the
  pipeline. Nothing to learn by building it early.
- **Hosting cost.** 03 has the numbers. Only the Worker's CPU column is
  empirical, and #4 measures it.
- **Landing Page entries.** A per-entry flag and a second button label.
  Policy, not risk.
- **Search matching.** 30–50 entries. Any substring match with case folding
  works on day one; typo tolerance is tuning.
- **The Wi-Fi glyph's reachability probe.** 99 §3 is right that it must be a
  real probe. That is a design rule, not an unknown.

## Devices

The matrix the Tier 1 items need. Android versions are to be recorded by
#1, not assumed here; 99 §21 says stock firmware skews 12 and 13. Phones
and tablets are not in the matrix; 01 says they do not drive the design,
and nothing on this list is worth a day on one.

| Device | Why it is in the matrix |
|---|---|
| Retroid Pocket (any current model) | 4:3 display; Retroid firmware preloads; the most common target |
| AYN Odin 2 | 16:9; the device 04's ranking of emulators is written around |
| AYN Thor | Already observed to ignore `IME_FLAG_NO_FULLSCREEN` and to mismatch key-up events; the shim's test case; the only device with a run-as-root facility, so #8 lives here |
| Anbernic Android model | Vendor-signed preloads; the cheapest firmware in the set |

Every handheld should be factory-reset once before #3 runs on it.

## Sequence

Day one, in parallel, because they wait on clocks: start the adapter soak
(#7) and, from its first run's output, the upstream-stability soak (#10).

Week one, with all devices on the desk: #2 (one day), #12 (one hour), #3
(one day), then #1 (the rest of the week).

Week two: #4 against Cloudflare, #5 in the client, #8 on the Thor once #1
has shown which rows are not already silent without privilege.

Week three: #6 on top of #1's harness, #9 filled from everything above,
#11 begun and timed. The soaks report.

Each result is an edit: #1 and #8 rewrite 01 §Installs and updates, 01
§Later and 02 §Library; #2 and #5 produce the focus specification; #3, #9
produce the launch catalog and the entry schema; #4 settles 03 and 01's
"completed download" sentence; #6 produces 02's queue rules; #7 produces
the pipeline heartbeat; #10 and #11 produce one line each in 01. The
background-check correction above is an edit to make now, before any of
this runs. When those edits land, this document has done its job and can
be deleted, as 99 says of itself.

## What this document is not

It is not a milestone plan, a test strategy, or the infrastructure plan.
Nothing here is kept. It is the shortest list of experiments whose results
change what the other documents say, ordered so the ones that change the
most run first.
