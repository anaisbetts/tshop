# Critique of the v1 specs

> A review of [01-prd.md](01-prd.md) and [02-screens.md](02-screens.md),
> limited to problems in the text that exists.

Every finding below is a defect of something already written: a claim that
is wrong, two claims that contradict each other, a mechanism that will not
produce the outcome asserted of it, or an enumeration that misses a case the
document's own promises guarantee. Findings of the form "the infrastructure
plan is not written yet" are deliberately excluded — see
[Excluded as not yet due](#excluded-as-not-yet-due).

Written against the working-tree revision of both documents. Two findings
about analytics and download hosting were resolved by an edit made while this
review was in flight; they are recorded under
[Resolved](#resolved-while-this-review-was-in-flight) rather than deleted, so
the reasoning behind the new text is not lost.

Numbered 99 so it does not claim the slot of the next real document. Items
here are meant to be resolved into 01 and 02 and then deleted, not
maintained.

Each finding is tagged:

- **[blocks]** — undermines a promise the PRD makes about v1
- **[weak]** — stated as decided, but the mechanism will not do the job
- **[gap]** — an enumeration in scope of the document is incomplete
- **[nit]** — cheap to fix, no consequences

## What holds up

Worth naming so the review does not skew the record.

The central bet is correct. Moving release detection from each handset to the
catalog is the actual difference from Obtainium, not the tile grid. Obtainium
pushes parsing rules onto every device, so one upstream change breaks the
whole installed base at once and nobody is accountable. "Keep offering the
last known-good version" is the most valuable sentence in the PRD.

02 derives server requirements from screens rather than inventing an API, and
resists a live API at a scale that does not need one. That derivation came out
right. The client-never-sorts invariant, the single navigation layer with its
reasoning shown, the "Not in version one" / "Surfaces that are not screens" /
"Client-only concerns" sections, and the signature-mismatch state are all
better than the average v1 spec, and the last one proves the author has
installed APKs on Android.

The new data policy is also good work, and unusually so: a discard list
instead of a collection list, "if a number is not on that page tShop does not
have it", operators with no private view, Privacy Mode refusing to fall back
to the counted URL silently, and the explicit exclusion of install-success
tracking. That is a policy written by someone who intends to keep it. The
findings below are about its edges, not its direction.

## A. Wrong about the platform

### 1. The install-confirmation model is out of date [blocks]

02, Library:

> Without Shizuku or root, tShop cannot install anything itself. It hands
> each APK to Android's package installer, which shows its own confirmation
> dialog, one per app, that the user must accept.

01 defers the same thing:

> The version-one promise is reliable updates, not silent updates. Shizuku
> support can later remove confirmation prompts for users who choose to
> configure it.

On Android 12 and later this is not true. An app holding
`REQUEST_INSTALL_PACKAGES` that also declares
`UPDATE_PACKAGES_WITHOUT_USER_ACTION` can commit a staged session with
`setRequireUserAction(USER_ACTION_NOT_REQUIRED)` and get no confirmation
dialog, provided the app being installed targets a recent API level and the
caller is the installer of record — that is, it is an update to something the
caller installed, or the caller is updating itself. Aurora Store and
Droid-ify/NeoStore ship this today.

The consequences are large and all in tShop's favour:

- Silent updates are a v1 capability, not a Shizuku later. For apps tShop
  installed, on Android 12 and up, Update All can be genuinely silent without
  asking anyone to configure anything. Deferring this gives away the property
  the product is named after.
- First installs still need a dialog. That is fine, and arguably right — the
  moment a user chooses an app is a moment worth one confirmation. So the
  accurate sentence is: first install, one system dialog; every later update,
  silent where the device and the target app allow it; Shizuku buys silence
  for first installs and for apps tShop did not install.
- 01's hedge —

  > When the platform supports it, tShop should remain the recognized
  > installer and request update ownership for apps it installed.

  — gestures at exactly this mechanism, but it is too vague to build against,
  and the second half is not available to a sideloaded store. Android 14's
  formal *update ownership* is opted in through a device-side `sysconfig`
  `<update-ownership>` entry, which is something an OEM or a preinstalled
  store does. tShop cannot claim it for arbitrary packages. What tShop can do
  is be the installer of record and handle `STATUS_PENDING_USER_ACTION`
  correctly.
- The reverse risk is unmentioned: where Play Store is the installer of record
  or update owner for an app, Android 14 and later can require user consent
  for tShop's update. That is a per-app state tShop will meet in the wild, and
  it overlaps heavily with the signature-mismatch case in finding 13.

The spec should name the mechanism, state which operations are silent on which
Android versions, and treat the rest as a device matrix to fill in on real
hardware. "Updates must be boring" hangs on this, and the current text plans a
ten-dialog, d-pad-operated Update All, which is one bad Saturday away from
being Obtainium with better artwork.

### 2. "One summary notification" is not the notification set [nit]

02 lists a single summary notification under surfaces that are not screens.
Background downloads on Android 14 and later need a data-sync foreground
service, which carries its own ongoing notification while the queue runs. The
accurate statement is one summary notification for updates plus one transient
queue notification while downloading. Small, but this document's value is that
its claims about the platform can be trusted.

### 3. The Wi-Fi icon will lie [weak]

> A small bitmapped Wi-Fi icon in a corner of every screen shows whether the
> device is online, in the manner of the 3DS home menu.

"Online" is not binary. Captive portals, a network that reaches nothing
upstream, and a catalog fetch failing while Wi-Fi is nominal are all common on
exactly these devices. Define what the icon tests — a real reachability probe
against the catalog host, not a network capability check — or it will show a
contented icon while every install fails, which is worse than no icon.

## B. The data policy needs five decisions it does not make

The policy is right; these are the places where it will meet reality.

### 4. Nothing in the first-launch flow tells the user the policy exists [gap]

01 says the policy "also appears in the app's About screen and on the
dashboard itself", and 02 puts it in About and behind a Settings switch. But
Onboarding covers only the two permissions, so the first time tShop counts a
download is a download the user has not been told about. About is where
policies go to be unread.

01 also states the governing rule: "Data collection should never become a
hidden part of the product." One line in Onboarding — what gets counted, that
it is anonymous, that Privacy Mode exists — satisfies that rule at the only
moment the user is paying attention. A console-style first-run notice is also
squarely in the 3DS idiom the product is invoking.

### 5. "Completed download" is the whole measurement and is undefined [weak]

The count is now load-bearing — it orders the grid, sets catalog priority, and
is published — and the policy rule is that "a download counts when the client
finishes fetching the APK. Partial transfers, retries, and HTTP range resumes
are not extra events."

Nothing says who decides that a transfer finished, or on what evidence. A
proxy that streams bytes can see the client stop early; a proxy that buffers
cannot. A resume across three range requests is one download by policy and
three by a naive implementation. A user who abandons at 97 percent correctly
counts zero, and then never appears in the dataset at all.

This needs one sentence in the pipeline section: count when bytes delivered to
the client equal the declared size and the connection closed cleanly, and
count at most once per package-version-variant per day per source. Without
it, the number the public dashboard promises is the number the dashboard
cannot actually deliver.

### 6. The policy forbids the dedupe the ranking depends on [weak]

Counts drive popularity, and the policy discards IP addresses and every
identifier, so counts cannot be deduped per device. The result is
download-events-per-day, which tracks how many devices exist and how often
they update, not interest. One user with Update All enabled on a
nightly-tracking app moves an entry.

Two ways out that do not break the policy:

- Dedupe on `(package, version)` per day per day-hashed source address. The
  hash is never persisted, so "tShop does not keep IP addresses" stays true in
  the only sense that matters, and the count becomes closer to distinct
  fetches than transfers.
- Or keep raw totals and say plainly in the policy that popularity is measured
  in downloads, not in people, and let the ranking formula absorb it.

Related, and unmentioned either way: Privacy Mode users leave the dataset
entirely, so the grid is ordered by the preference of whoever did not turn the
switch on. That is a self-selected subset, and at a small install base it can
be a large minority. Worth one honest line, because the whole point of
publishing the numbers is that anyone can check that the grid is ordered by
them.

Publishing them also makes the ranking gameable in a new way — a scripted
burst of fetches moves a tile — which is a fair price for transparency, but a
price.

### 7. Daily public totals over 30 to 50 apps are near-real-time for the long tail [weak]

"Daily package totals are kept indefinitely. They are public popularity data,
not a dossier." For a popular emulator, true. For an app with three installs,
a daily count is a small integer that an interested maintainer — or the one
person who cares — can read as activity. If a user's device is the only one
that fetches an obscure entry, the public page says roughly when.

That is a judgment call the project is entitled to make. Make it knowingly:
state the minimum published granularity, and whether low-volume entries are
bucketed to weekly. It costs nothing now and is awkward to retract later, since
the data is already public.

### 8. The stats dashboard is a v1 deliverable with no requirements [gap]

It arrived as a privacy control and is now in "Version one includes", listed as
a first-party web page that quotes the policy and links out of About. So v1
ships a client, a pipeline, and a web frontend, and the dashboard has no
requirements, no owner, and no failure behaviour anywhere in either document.

Cheap fix that also protects the architecture: state that the dashboard is
static output of the same publishing pipeline — generated JSON plus a page —
so nobody builds a web application, and the download host stays the only live
request path 02 claims it is. Then say what About does when the dashboard is
unreachable, since it is now a link the product depends on.

## C. Mechanisms that will not do what is claimed of them

### 9. Popularity order has no cold start and a story problem [weak]

> **Popularity rank**: computed server-side from download counts and published
> as an explicit order. The client never sorts.

Beyond the measurement issues in findings 6 and 7:

- A new entry has zero downloads, so it ranks last, so it is never seen, so it
  stays at zero. Nothing in either document breaks that loop; it needs a
  curator-assigned seed rank.
- Order is baked into the next published catalog, so ranking lags a publish
  cycle behind reality. Harmless, but it makes "popularity" slow-moving
  incumbent bias rather than a signal.
- Letting download counts allocate the most valuable real estate quietly
  contradicts "curated means accountable". The crowd ranks, the project takes
  the credit and the blame.

Keep the client-never-sorts invariant — it is a good one. The server needs a
documented formula and a seeded order. The published dashboard is a genuine
asset here: a ranking anyone can audit is a ranking the project can defend.

### 10. The grid as specified is a storefront, not the 3DS home menu [weak]

01's reference is explicit:

> The visual reference is the Nintendo 3DS home menu

What makes that menu feel like yours is that it reflects your own usage and
does not rearrange underneath you. A globally fixed, server-computed
popularity order gives every device the same grid, which is a storefront grid.
Both are legitimate products. Invoking the 3DS while shipping a fixed global
order means the reference is doing aesthetic work rather than design work.

Either say the reference is the tile *language* and stop implying the
behaviour, or make the first frame device-local — recently used, most used,
user-pinned — with the curated catalog as the browse layer below it. A
device-local frame needs no server state and does not touch the
client-never-sorts rule.

### 11. Exactly one category will fight the curator and the user [weak]

> **Category**: exactly one.

01's own list of what belongs guarantees collisions: RetroArch is an emulator
and a frontend; a PlayStation emulator is an emulator and a BIOS problem; a
streaming client is a utility and a controller tool. Forcing one category turns
a multidimensional catalog into a series of arbitrary calls, then makes the
losing categories unrecoverable — a user who correctly guesses "frontend" and
finds nothing has no way to discover the app is filed under "emulator".

02 is right to reject filter chips and a second navigation layer; both are
hostile to a d-pad. The fix costs no navigation: keep one primary category
that drives the frames, and allow secondary tags used only as search match
material. The grid stays clean, the client still never sorts, and the curator
stops lying to the taxonomy.

### 12. Greyed tiles carry more authority than the data can support [weak]

> Version one starts with an empty vocabulary and adds a tag when a catalog
> entry cannot usefully run without that hardware.

Starting empty is good YAGNI discipline and the reasoning is sound. But the
design also gives capability tags the power to grey out an app and to explain
that grey-out on Detail — a visible, app-hiding authority, exercised on
hardware whose vendors ship inconsistent `getSystemFeature()` results. A wrong
tag makes a working emulator look unsupported, and the store looks broken
rather than the tag looking wrong.

State the rule in 02: capability tags annotate and never hide, and a capability
the client cannot determine resolves to "not stated", never to "unmet".

### 13. The validation list is one check short of the promise, and one check is wrong [blocks]

01 lists what the pipeline should confirm per update. As written it will
misbehave on the catalog 01 wants:

- **"Its version is newer than the currently approved release"** is undefined
  and misleading. Android's authoritative signal is `versionCode`; upstreams
  reset it, reuse tags, and use date-based schemes that can regress. Say
  `versionCode` decides and `versionName` is display only, and say what happens
  when the code goes backwards.
- **No prerelease or nightly policy.** RetroArch and much of this ecosystem
  publish nightlies with version codes above stable. "Newer than approved" will
  happily promote a nightly over a good stable build, which is exactly the class
  of problem tShop exists to absorb. Nightly needs to be a separate entry, not a
  state of one.
- **A signature change is treated as a check, not a decision.** Legitimate key
  rotation happens — v3 rotations, project handoffs, a project moving to Play
  App Signing. A pass/fail check leaves only two bad options: block forever, or
  auto-trust a new key. Rotating a signing identity is a human judgment and
  should be recorded as one, with the reason kept next to the entry.
- **Nothing checks that the APK can be installed at all.** Android 14 refuses to
  install apps targeting SDK 23 or lower; Android 15 refuses below 24. That is
  exactly the old-homebrew population a handheld catalog reaches for, and the
  bypass needs adb or Shizuku, which 01 says must not be required.
  Installability on current Android is a catalog inclusion rule, so it belongs
  in 01's "what belongs" section rather than as a surprise at install time.
- **Monitor death is indistinguishable from "up to date".** A check that stops
  running produces no user-visible symptom, and the promise being made is that
  the store, not the device, is watching. Worth one sentence in 01 saying the
  pipeline reports silence as a failure.

### 14. The ABI-variant model cannot express split APKs [gap]

01:

> Version one distributes APK-based applications only.

02:

> When a release provides more than one APK, the client chooses automatically
> by ABI and minimum Android version.

That model covers multiple single APKs and not split APKs, `.xapk`, or
APK-plus-OBB, all of which appear in this ecosystem. Refusing them is a
legitimate v1 rule and probably the right one — but it has to be written down,
because it constrains which apps can be seeded, and because "APK-based only"
currently reads as though splits are included.

### 15. The search flow rests on an unverified premise [weak]

> On landscape handhelds the IME is expected to cover the whole screen, so
> search is a commit-then-view flow rather than filter-as-you-type.

The flow follows sensibly from the premise, but the premise is an empirical
claim about specific devices, and many handhelds dock or resize the IME. If the
IME docks, commit-then-view is worse than live filtering for no reason. Verify
on the actual target devices before this becomes a requirement.

Separately, "tiles whose name, summary, or description match" has no matching
rule. On a d-pad-only device search is the last resort and typing is expensive,
so typo tolerance and case handling are not polish. And this makes 01's open
question about categories the most consequential one in the document, not a
detail to settle later.

### 16. Offline Browse shows stale promises with no staleness rule [gap]

> Offline, Browse renders from the last cached catalog, including tile
> artwork. Install is disabled until connectivity returns.

Rendering from cache is the right call and the artwork-cache requirement is
correctly traced back to the server. What is missing is any notion of age. A
cached catalog can be four hours or forty days old; the grid will still show
update badges from it while Install is disabled, which reads as the store being
broken rather than the store being offline. Settings already displays a
last-updated timestamp, so the client has the input. Define the age thresholds
and what changes at each — this is screen-level behaviour, not an infra detail.

### 17. Showing one release's changelog is the wrong unit [weak]

> Changelog for the latest approved release only

A reasonable scope reduction, but the failure case is the common case: a user
who has not opened tShop in two months and has three releases to catch up on
sees the notes for the newest one and nothing else. The client already knows
the installed version, so "changes since your version" costs one array in the
catalog document and no new screen.

## D. States the enumeration misses

### 18. "Installed version is newer than approved" has no action [gap]

02 lists the primary actions as Install, Update, Open, Retry, and the
signature-mismatch state. It omits the case where the installed version code is
*above* the catalog's approved release.

That state is guaranteed by 01's own promise:

> the catalog should keep offering the last known-good version instead of
> passing the problem to every device

A device that already took the bad release, before the catalog retracted it,
lands in it. So does anyone who updated from another source. The action list
needs a decision — quiet "current", an explicit rollback, or "installed version
is newer than the catalog, tShop will not manage it" — and the choice is a
product one, not an implementation detail.

### 19. The signature-mismatch fix is the first-run experience and it destroys data [blocks]

The mismatch state is the strongest sign of care in 02. Its handling is
under-designed, and it will be common: Retroid and Anbernic firmware ships
vendor-signed emulators preinstalled, and many catalog apps also exist on the
Play Store signed with a different key than their GitHub APK. On a fresh
device, a meaningful fraction of the launch catalog can be greyed with
"uninstall first".

- Uninstalling means losing saves, controller remaps, configs, and BIOS
  locations. 02 says the state "explains that the existing copy must be
  uninstalled" and offers no warning, no pointer to what will be lost, and no
  backup path. For an emulator's private storage there is usually no other
  backup path.
- Detail offers **Uninstall** only "when the app is installed with a matching
  signature" — so in the one case where uninstalling is the prescribed fix,
  tShop declines to offer it and the user goes to Android Settings to do what
  the store told them to do.
- Preinstalled system apps cannot be uninstalled at all, and there is no state
  for that. On the target hardware this is not an edge case; it is Tuesday.

There is also a catalog consequence: the launch list should prefer apps whose
canonical distribution is the APK tShop will ship. Count the Play-conflicting
entries before committing to 50. If it is a third of them, the mismatch state
is the product and it deserves its own design pass.

### 20. Nothing happens when a catalog entry goes away [gap]

Curation means removing entries — abandoned projects, bad actors, upstream that
stops publishing APKs. The Library's frames are Queue, Updates available, Up to
date, and Other source. An installed app whose entry has been delisted fits
none of them, and its Detail view references an upstream URL and a release that
no longer exist in the catalog. Say what happens: which frame it lands in,
whether it still reports a version, and whether tShop keeps mentioning it at
all.

### 21. tShop itself is not covered by either document [gap]

01 claims to enumerate v1 and 02 claims to list every screen in it, and neither
mentions how tShop is obtained or updated. It is a store that cannot update
itself, and self-update is the easy case of the installer rule in finding 1 —
an app updating itself is allowed to be silent.

Two follow-ons, both in scope of documents that already make these decisions:

- **Nothing says what happens when the installed client cannot read the
  published catalog.** 02's entry fields carry no schema version and 02 has no
  "your tShop is too old" screen, so the first format change in year two is a
  silent failure for every un-upgraded install. Given "we own mistakes", that is
  a self-inflicted outage; a version check plus one screen is cheap.
- **Which Android versions tShop runs on** is a product decision that decides
  which handhelds are supported, and it determines whether the silent-update
  path exists at all. 01 defines supported devices by form factor and never by
  Android version. Stock firmware on the named devices skews Android 12 and 13,
  so this is a constraint the PRD already needs.

### 22. The queue's rules are one sentence [gap]

02 is careful about queue *states* and about the confirmation chain pausing when
the user leaves Library. The scheduling rules are absent: concurrency,
ordering, resume after a partial download, free-space check before downloading,
dedupe when the same app is queued twice, and what happens to a
downloaded-but-unconfirmed session across a reboot. "Multiple installs queue" is
currently the whole specification of the component whose entire job is turning
ten installs into one boring task.

The new Privacy Mode rule adds a queue case worth naming in the same place: a
Privacy Mode download that fails because upstream is unreachable must not fall
back, so the failure reason has to tell the user that Privacy Mode caused it.
Otherwise the switch reads as "turning this on breaks installs".

## E. Claims that need evidence or a number

### 23. The problem statement has no competition in it [weak]

> Android game consoles have a healthy software ecosystem but no good way to
> browse it.

Nothing in 01 mentions F-Droid (curated, validated, rehosted, signed metadata,
silent updates in clients such as Droid-ify and NeoStore — tShop's architecture,
minus the storefront), Obtainium's current capabilities, ObtainX (a Material 3
fork that already answers the "utilitarian list" complaint), the Obtainium
emulation packs (curated handheld catalogs that exist as data today), EmuTran
(device detection, curated catalog, Shizuku installs, self-update, BIOS
validation, folder scaffolding — it already serves the fresh-device job, as a
wizard), or R-Shop.

A reader who knows the space will not accept the sentence as written, and the
stronger claim is already in 01's own principles: the pieces exist separately,
nobody has made the storefront coherent, and nobody has taken responsibility
for the catalog as a product. That is defensible and specific.

One decision follows from the packs existing: whether v1 imports an
Obtainium-compatible manifest, or emits one. The community's curation already
lives in that format, so the bridge is cheap adoption leverage. Not deciding is
deciding against.

### 24. The success criteria cannot be observed, and the new exclusions make that permanent [weak]

> Keep using the catalog for one month without catalog-caused broken installs,
> mismatched packages, or stale update rules

> nobody reaches for Obtainium or a browser, and nobody has to curse at updates

Not one of these is observable: no telemetry, no unique-user tracking, and now
an explicit exclusion of install-success tracking, plus a policy that discards
"whether the user accepted Android's install prompt after the download". The
project has ruled out, on principle, the one signal that would confirm an
install worked.

That is a fine principle — it just means the criteria need a human mechanism.
Define "catalog-caused broken install" precisely, since it is the metric being
promised on; restate the criteria as a named beta group with a checklist; and
give the user a way to report a broken install, so failures arrive as reports
rather than as inferences nobody is allowed to draw.

### 25. The one number in the PRD is asserted [nit]

> A smaller catalog with 30 excellent entries is more useful than 300 entries

The principle is right and the ratio is right. The size of the launch catalog is
nonetheless the only number in either document that the product's whole cost
hangs from, and 01's open questions treat it as taste ("Which 30 to 50 apps").
It is a budget decision: onboarding an entry means sourcing artwork,
screenshots, a description, and a verified source, and upkeep means watching it
forever. Deriving the size from hours the maintainer can actually spend makes
"curated means accountable" an honest promise instead of a hopeful one.

### 26. The pain is asserted, not evidenced [nit]

01's account of Obtainium's failings is specific and almost certainly right, and
it rests on nobody having to explain it. A handful of quotes from the
communities this is for would firm the premise and seed the beta group the
success criteria depend on, in the same afternoon.

## F. Nits

- One state, two names: Detail says "Installed from another source", Library
  says "Other source". Pick one, and note that it occupies a primary-action
  slot while being a state rather than an action.
- The primary-action list omits the in-flight states, even though Detail says the
  button becomes a progress indicator. Queued, downloading, installing, and
  cancelled by the user are the states a user actually stares at.
- "Background update checks are always on; there is no switch for them" removes
  the user's only lever with no stated cadence and no note about aggressive OEM
  background killing on the target devices. The no-switch decision is
  defensible; unstated is not. Now that Privacy Mode is the second switch, 02's
  framing of "the few switches tShop has" should say why these two earn a
  switch and background checks do not.
- The discard list says tShop does not keep IP addresses, while Retention allows
  access logs to retain client IPs for up to seven days. Reconciled in
  substance, contradictory as read. "Does not keep in the analytics store"
  matches the intent.
- Nothing names a license for tShop, though 01 asserts it is Free Software. Nor
  does the entry quality bar record the rights basis for rehosted artwork and
  screenshots, which is per-entry work that is far cheaper while sourcing them
  than afterwards.
- Unstated as exclusions rather than as oversights, and worth one line each:
  secondary Android users and work profiles, and TalkBack/accessibility.

## Resolved while this review was in flight

Two findings against the earlier text, both fixed by the data-policy revision:

- **Analytics was undecided in 01 and already happening in 02.** 01 said the
  project "has not yet decided whether to collect usage data" while 02 made the
  download host exist solely to count downloads. 01 now decides it explicitly,
  names the counts as the whole analytics system, publishes them, and adds
  Privacy Mode. The contradiction is gone, and the resolution is better than
  the one this review would have proposed.
- **Mirroring was optional in 01 and mandatory in 02.** 01 said the first
  release need not mirror APKs; 02 required downloads to be rehosted or proxied.
  Both variants now carry a tShop URL and an upstream URL, which settles it and
  makes Privacy Mode possible at all.

Two things worth carrying forward from the old findings, since neither document
says them yet: the reliability argument for the counted host is stronger than
the counting argument — GitHub release assets are redirect-based and there are
recurring reports of large-asset downloads failing on account egress limits, so
the host is also a durability feature. And proxying every byte changes 01's
claim that entries "point to legitimate, publisher-controlled upstream
releases": the download becomes tShop-hosted, with upstream as the Privacy Mode
exception. Probably the right trade; worth saying out loud rather than letting
two phrasings imply different products.

## Excluded as not yet due

Dropped deliberately, because they are requests for documents that have not been
written rather than faults in the ones that have:

- No infrastructure plan, catalog format document, signing and key-rotation
  design, hosting cost, or rollback story. 02 is explicit that signing belongs
  to a plan that does not exist yet, which is honest.
- No navigation and focus specification. 02 disclaims being a visual design, and
  focus semantics arguably belong to the design pass — findings 12 and 15 are
  kept because they are behaviour, not appearance.
- No state-and-error matrix for the screens: loading, empty, fetch failure,
  parse failure, checksum mismatch, disk full, package busy.
- No launch catalog worksheet, no milestone order, no test strategy, no stack
  decision recorded despite the client being pinned to Flutter 3.47.2.
- No pipeline internals: scheduler, upstream rate limits, quarantine states,
  alerting, or the operator's weekly work loop.

## Verification notes

Checked against current sources, since several findings turn on platform
behaviour:

- `setRequireUserAction` and its conditions, including the
  `UPDATE_PACKAGES_WITHOUT_USER_ACTION` requirement, the recent-API-target
  requirement, and the installer-of-record-or-self-update requirement:
  <https://developer.android.com/reference/android/content/pm/PackageInstaller.SessionParams>
  and <https://gitlab.com/fdroid/fdroidclient/-/issues/2380>
- Android 14 update ownership as a device-side `sysconfig` opt-in, and
  `STATUS_PENDING_USER_ACTION`:
  <https://source.android.com/docs/setup/create/app-ownership>
- The target-SDK install floor (SDK 23 blocked on Android 14, below 24 blocked
  on Android 15):
  <https://bayton.org/android/android-minimum-targetsdk-matrix/> and
  <https://www.androidpolice.com/android-15-blocks-android-marshmallow-apps/>
- Reports of GitHub release-asset download failures under account egress limits,
  relevant to the hosting argument:
  <https://github.com/orgs/community/discussions/8535>
- Competitors named in finding 23: F-Droid's security model, ObtainX,
  `RJNY/Obtainium-Emulation-Pack`, `mayusi/EmuTran`, `AverageConsumer/R-Shop`.
