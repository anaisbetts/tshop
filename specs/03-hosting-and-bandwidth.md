# Hosting and bandwidth costs

> What it costs to rehost APKs if tShop gets popular, and the cheapest
> architectures that still match the v1 spec.

This is a cost and architecture note against [01-prd.md](01-prd.md) and
[02-screens.md](02-screens.md). It is not the infrastructure plan. It exists so
the hosting decision is made with numbers, not vibes.

Written September 2026. Every price below was re-checked against the
providers' published pages on 2026-09-04. Provider prices move; the traffic
model and the "do not do this" list age more slowly than the dollar figures.

Compared against the store backends and clients in `tshop-oppo/refs`, especially
the architecture dossiers under `refs/11-store-backends/ARCHITECTURE/` and
`refs/10-store-clients/BACKEND-ARCHITECTURE.md`.

## The expensive decision is already in the spec

Version one commits tShop to something almost nobody else in this space does:
**rehost or proxy every APK so a completed download can be counted**.

From the PRD and screens docs:

- 30–50 apps, latest approved release only, ABI-picked APKs.
- Catalog, tiles, artwork, screenshots, and the stats page are static files.
- The only live request path is the download host. It exists so a completed
  APK fetch increments `(package, version, variant, UTC day)`.
- Default path is rehost or proxy. Privacy Mode goes to the publisher and is
  invisible to tShop.
- No accounts, no client telemetry, no third-party analytics vendor. tShop
  operates the collector. Access logs may keep IPs for seven days, then die.
- Downloads start only on Install, Update, or Update All. Background checks
  do not pre-fetch APKs.

[99-spec-critique.md](99-spec-critique.md) already has the cost-relevant
warning: the reliability argument for the host is stronger than the counting
argument. GitHub release assets fail. Once tShop rehosts, the download is
tShop's.

That last sentence is the bill. Storage is a rounding error. Egress is not.

## What the other stores actually do

Almost nobody pays for APK egress.

| Project | Hosts APKs? | How bandwidth is paid | Scale analog |
|---|---|---|---|
| Obtainium / ObtainX / EmuTran | No. Client hits GitHub, Codeberg, `buildbot.libretro.com`, `ppsspp.org`, etc. | Publishers / GitHub. Store cost ≈ $0. | The handheld catalog already exists as 76 Obtainium configs. |
| komi (GitHub Store) | No. Forge proxy + cache only. | One Hetzner 4 vCPU / 8 GB VPS + Cloudflare. ~90k users. | Closest "popular store" without binary hosting. |
| Aurora / Yalp | No. Play CDN. | Google. They only run a token dispenser. | Play's bandwidth is free to the client author. |
| F-Droid | Yes. Static tree + volunteer rsync mirrors. | Community mirrors absorb most egress. Origin is a dedicated box. Donations ~$3k/mo for *all* ops, not just bandwidth. Primary repo ~675 GB, archive ~3.8 TB. | What tShop becomes only if every old APK is kept forever. |
| IzzyOnDroid | Yes. Republish, purge `archive/`, rsync to mirrors, Apache. | Single-maintainer box + mirrors. Stats come from web-tier / Apache logs, published as monthly JSON. 1,393 apps / 2,786 versions. | Closest "we rehost APKs and count from logs" analog. |
| Accrescent | Yes. Content-addressed objects, `repo.accrescent.app/apps/<pkg>/<sha256>.apk`. Directory service never touches APK bytes. `${base-url}/${objectId}` concat, zero object-storage SDK in the API. | GCP object storage + Cloudflare. No download counters at all. | The right *shape* for artifacts. They skipped the thing that makes tShop expensive. |

Two extra facts that should change the plan:

1. DuckStation is the cautionary tale, twice. The Obtainium Emulation Pack's
   `duckstation-mirror.rmacias.workers.dev` is a Cloudflare Worker, but it
   only scrapes DuckStation's HTML and rewrites broken links; it never hosted
   APK bytes. Then the developer pulled the Android APK entirely, citing
   "hundreds of dollars" of personal hosting cost, and the CC BY-NC-ND
   license means nobody else may mirror it
   ([Obtainium-Emulation-Pack#54](https://github.com/RJNY/Obtainium-Emulation-Pack/issues/54)).
   Lesson one: one emulator on metered egress really does cost a hobbyist
   hundreds of dollars. Lesson two: not every catalog entry is rehostable,
   see [Not everything can be rehosted](#not-everything-can-be-rehosted).
2. The architecture survey's own conclusion: static-file architectures
   dominate, and the reason is caching economics, not purity. tShop already
   chose that for the catalog. The APKs should be the same shape: immutable
   objects behind a URL, not a live proxy of GitHub.

komi ranks on GitHub's own `download_count` because they killed client
telemetry. tShop cannot copy that and still have a first-party public
dashboard of *tShop* downloads. That is a product choice, not an infra
accident.

## How big the files actually are

A v1 catalog that looks like a trimmed Obtainium Emulation Pack (RetroArch
aarch64, Dolphin, PPSSPP, NetherSX2, Eden, Flycast, Vita3K, ES-DE, a few
utilities):

| Kind | Typical APK |
|---|---|
| Dolphin (arm64) | ~11–20 MB |
| NetherSX2 | ~20–27 MB |
| PPSSPP | ~30–43 MB |
| ES-DE | ~80 MB |
| Winlator | ~150 MB |
| RetroArch aarch64 | ~190–200 MB |
| Utilities / small emulators | 5–20 MB |

Working average for a counted download, ABI-split, latest-only: **~60 MB**.
Stress case if Winlator + RetroArch + Eden go to everyone: **~100 MB**.
Both numbers are conservative once the non-rehostable entries below drop
out of the counted set; ES-DE alone is 80 MB that tShop will never serve.

Keep only the current approved APK per variant, Izzy-style (purge archive).
50 apps × ~80 MB × 1.3 variants ≈ **5–8 GB**. Artwork is hundreds of MB.
F-Droid's terabyte archive is what happens when nothing is deleted.

Do not approve nightlies as the catalog channel. RetroArch nightly is ~200 MB
per day. That one decision can dominate the entire bill. The critique already
wants nightlies as separate entries; from a cost view they should stay out of
v1 entirely.

## Not everything can be rehosted

The rehost decision is per app, not per store. Of the eight apps named above,
two cannot be rehosted at all, and it has nothing to do with bandwidth:

| App | Terms | Rehost? |
|---|---|---|
| RetroArch, Dolphin, PPSSPP, Flycast, Vita3K, Eden | GPL | Yes |
| NetherSX2 | Patch on AetherSX2, which is CC BY-NC-ND 4.0. Trixarian's own README: "No APKs are provided due to licensing issues." | No |
| ES-DE (Android) | Paid, partially closed source. [es-de.org](https://es-de.org/): "Please don't distribute it or share download links to the APK." Sold via Patreon, Galaxy Store, AppGallery. | No, and there is no public URL to point at |
| DuckStation | CC BY-NC-ND 4.0, author has pulled the Android APK | No |

DuckStation's author is famously an outlier, but the license is not:
AetherSX2 chose BY-NC-ND first, and ES-DE Android is a business, not a
grudge. Expect more of these as the catalog grows; check the license of
every entry at curation time, not after the pipeline has uploaded it.

The catalog needs a **Landing Page** entry type for these. Same tile, same
artwork, same description, but the primary action is **Go to Publisher**
instead of Install, with a one-line explainer: "ES-DE for Android is a paid
app sold directly by its developer" or "This emulator's license does not
allow tShop to redistribute it." The pipeline never downloads the APK, so
there is nothing to validate, store, count, or pay for. Privacy Mode is
irrelevant to these entries; they are publisher-only by construction.

This is also the answer to Eden-class exposure. GPL permits redistribution
of a Yuzu descendant; whether tShop wants its own domain and a public
counter to be the thing serving it is a separate call, and flipping one
entry from Install to Landing Page is a policy change, not a deploy.

Cost effect: favorable. Two of the three largest files in the size table
leave the counted set, and the flag costs nothing.

## Traffic model if it gets popular

Handheld Android installed base is roughly 1–2M devices (Retroid + AYN +
Android Anbernics, not Linux Anbernic / Analogue). "Popular" means a large
slice of *those*, not F-Droid's millions.

Per user, once they are set up:

- Fresh device: ~15 apps × 60 MB ≈ **0.9 GB once**
- Steady month: a few emulator updates + a couple of new installs ≈
  **0.6 GB/user/month**
- Catalog and artwork: noise if ETag and cache work. Izzy's whole index is
  14 MB for 1,393 apps; tShop's is a few hundred KB.

| Scenario | MAU | Egress / month | What it looks like |
|---|---|---|---|
| Launch | 500 | ~0.3 TB | Discord + a couple of Reddit threads |
| Niche hit | 5,000 | ~3 TB | Default rec in comments on a Retro Game Corps video |
| Popular (komi-scale) | 50,000 | ~30 TB | "just use tShop" is common advice |
| Handheld default | 200,000 | ~120 TB | In every setup guide |
| Fantasy | 1,000,000 | ~600 TB | Phones too, or preinstalled |

A viral week is a spike on top: 10k fresh setups ≈ **9 TB in a few days**.

Privacy Mode subtracts egress and subtracts counts. Power users will turn it
on. Budget as if they do not.

hShop's reputation for huge bills came from multi-GB CIAs and games. tShop v1
explicitly excludes ROMs, BIOS, and firmware. That exclusion is the difference
between a coffee-money host and a five-figure invoice. Keep it as a hard infra
rule, not just a product rule.

## Aggressive cost controls

Do these regardless of provider. They are how the bill stays small.

1. **Rehost at validation time, never proxy GitHub live.** The pipeline
   downloads once, verifies, stores `sha256.apk`. Clients never touch GitHub.
   Accrescent's `objectId` model. One origin fetch per version, then tShop owns
   the bytes.
2. **Latest only. Delete superseded APKs.** Izzy purges `archive/`. F-Droid's
   3.8 TB archive is the anti-pattern.
3. **ABI-split, not fat APKs.** Already in the screens spec. RetroArch
   aarch64 vs universal is the obvious win.
4. **No nightlies, no Winlator-class entries until there is a reason.**
   Catalog policy is a budget.
5. **Static catalog + long-cache art.** Conditional GET. Background checks
   must 304.
6. **Count from the download path or from tShop's own access logs**, then
   discard. Izzy's `dlstats` monthly JSON is the product the PRD already
   specified. Do not buy Cloudflare Web Analytics.
7. **Never S3/CloudFront, never Wasabi.** Wasabi's free egress is 1:1 with
   stored volume. tShop would store 8 GB and egress 30 TB. They will throttle
   or kick the account.
8. **Never add ROMs or game dumps on this host.** That is the hShop-sized
   bill.
9. **Only rehost what the license allows.** `rehost: yes | landing` is a
   per-entry flag in the catalog, decided at curation time. ND-licensed,
   paid, or publisher-only apps ship as Landing Page entries. This is a
   liability control that happens to also be a bandwidth control.

The cheapest architecture that still matches the spec is: immutable objects on
a zero-egress store, a tiny counter in front, static everything else.

## Option A — Cloudflare R2 + Worker counter

Best "super aggro" option. Accrescent's artifact shape on Cloudflare's
pricing, plus the collector Accrescent refused to build.

```
pipeline (CI or a €5 VPS)
  → validate APK, upload r2://apk/<sha256>.apk
  → publish signed catalog + art + stats page to R2 / Pages

client  →  Worker (count on clean complete)  →  R2
                ↘ increment D1 daily total
```

Steal Accrescent's `${artifacts.base-url}/${objectId}` so the catalog is just
URLs. Steal fdroidserver's `{name, sha256, size}` triple so the Worker can
say "bytes delivered == size, connection closed" — the definition the critique
asked for.

R2 egress is $0. Workers do not charge for duration while streaming; they
charge CPU. A stream-and-count Worker is almost idle *if it is written the
way described below*. D1 paid includes 50 million writes/month. That holds
until more than a million counted downloads a day.

Bandwidth never appears on the bill, so the only meters that move are
request counts. At ~60 MB per counted download:

| Scale | Downloads / mo | Worker requests | R2 Class B | D1 writes | Over the $5 floor |
|---|---|---|---|---|---|
| Launch (0.3 TB) | 5k | 0.05% of 10M | free | 0.01% of 50M | $0 |
| Niche (3 TB) | 50k | 0.5% | free | 0.1% | $0 |
| Popular (30 TB) | 500k | 5% | free | 1% | $0 |
| Default (120 TB) | 2M | 20% | free | 4% | $0 |
| Fantasy (600 TB) | 10M | at the 10M line | at the 10M line | 20% | ~$0–5 |

Storage: 5–8 GB of APKs plus artwork sits right at the 10 GB free line.
Overage is $0.015/GB-month, i.e. cents. Range-request resumes add Worker
requests and Class B ops on top of the download count; at Fantasy that is
what pushes past 10M, at $0.30 + $0.36 per extra million.

| Scale | Storage | Class B GETs | Workers + D1 | Total |
|---|---|---|---|---|
| Launch (0.3 TB) | free (under 10 GB) | free (under 10M) | $5 paid plan | ~$5/mo |
| Niche (3 TB) | ~$0 | free | $5 | ~$5/mo |
| Popular (30 TB) | ~$0.10 | free | $5 | ~$5–10/mo |
| Default (120 TB) | ~$0.10 | still free | $5 | ~$5–15/mo |
| Fantasy (600 TB) | ~$0.10 | ~free | $5–10 | ~$5–15/mo |

The $5 is the Workers Paid floor, which is wanted anyway (free Workers cap CPU
at 10 ms; streaming a 200 MB APK and writing a counter is happier on paid).

### Worker design notes that keep the CPU column at zero

These do not change the dollar totals above, but getting them wrong is the
difference between "$5" and "Exceeded CPU Limit" on a 200 MB RetroArch.

- **Do not touch the bytes in JavaScript.** "Workers bill CPU, not
  duration" is true, but the obvious way to count "bytes delivered == size"
  is a per-chunk `transform()` callback, and that *is* CPU per chunk. A
  workers-rs user hit the 30 s CPU limit doing exactly this on a 200 MB R2
  object ([workers-rs#389](https://github.com/cloudflare/workers-rs/issues/389)).
  Use `new FixedLengthStream(size)`, `object.body.pipeTo(writable)` without
  awaiting it, and `ctx.waitUntil(pipe.then(record, ignore))`.
  `FixedLengthStream` is an identity stream on the runtime's native path
  (no JS per chunk), sets `Content-Length` for you, errors if too few bytes
  are written, and the `pipeTo` promise resolves only on full completion and
  rejects when the client goes away. That is the completion definition the
  critique asked for, at ~zero CPU.
- **Handle `Range`.** Android downloaders resume with `Range` headers. Serve
  206 via `bucket.get(key, { range })`, reject multi-range, and only count a
  completed full 200. Never count a range, not even one that ends at
  `size - 1`; a one-byte tail request would otherwise be a free fake
  download (see [Degenerate cases](#degenerate-cases-how-strangers-run-up-the-bill)).
  Resumed downloads go uncounted, which undercounts slightly and is the
  honest direction to be wrong in.
- **"Completed" means piped to Cloudflare's edge**, not ACKed by the
  handheld. Close enough; say so on the stats page.
- **D1 is fine on cost, but it is one writer with a hot row.** A Friday
  Update All at 200k users is roughly 50–100 increments a second. Workers
  Analytics Engine is purpose-built for this (10M data points/month included
  on Paid, $0.25/M after, no hot row); a Durable Object aggregating per UTC
  day is the other option. Same dollar column either way.
- **Never cache `/apk/*`.** Worker responses are not cached by default. If
  anyone later adds a "Cache Everything" rule, cache hits bypass the Worker
  and the counts go quietly wrong.
- **Raw logs are optional.** The D1 or Analytics Engine row *is* the log.
  Not keeping IPs at all is cheaper than the seven-day retention and is a
  better privacy story. If raw logs are wanted anyway, Workers Logs on Paid
  includes 20M events/month.

Risks: Cloudflare is the whole stack. They can change R2 pricing. The old
self-serve ToS §2.8 ("no non-HTML content over the CDN") was removed in 2023
and never applied to R2, which is a paid product sold for exactly this use;
the residual risk is price, not policy. Use a custom domain, not `r2.dev`.
Keep a Hetzner rsync copy so leaving is possible.

Fits the spec: tShop operates the collector. Cloudflare is a pipe, not an
analytics vendor. Privacy Mode never hits the Worker.

Prices as of 2026-09-04 (Cloudflare docs):

- R2 Standard storage $0.015/GB-month; 10 GB-month free.
- Class A $4.50/million; Class B $0.36/million; 1M / 10M free.
- Egress from R2, including via the Workers API: free.
- Workers Paid $5/mo: 10M requests + 30M CPU-ms included, then
  $0.30/million requests and $0.02/million CPU-ms. No charge for duration.
  CPU limit per request: 30 s default, configurable to 5 min.
- D1 on Workers Paid: 25B rows read and 50M rows written included, then
  $1.00/million writes.
- Workers Analytics Engine on Paid: 10M data points + 1M read queries
  included, then $0.25/M and $1.00/M.
- Workers Logs on Paid: 20M events/month included.

## Option B — Hetzner box + Caddy + nightly log rollup

What Izzy and komi actually run. One machine, Caddy or Apache, count from
access logs, publish a static stats page.

- Start: Hetzner Cloud CX (CX23 €3.99, CX33 €6.49), 20 TB included, then
  €1/TB. Covers through niche and into early-popular. CX is EU-only, and
  the 20 TB is EU-only too: US locations include 1 TB, Singapore 0.5 TB at
  €7.40/TB overage. Do not put this box in Ashburn.
- Comfortable: dedicated AX41-1-LTD / EX44-1-LTD, €57.30/mo excl. IPv4
  (~€59 with it, no setup fee, after the June 2026 price adjustment),
  unlimited 1 Gbit. Traffic is free. The limit is the port, not the invoice.

| Scale | Cloud CX | Dedicated 1G |
|---|---|---|
| 0.3 TB | ~€6 | ~€59 (overkill) |
| 3 TB | ~€6 | ~€59 |
| 30 TB | ~€6 + €10 overage ≈ €16 | ~€59, ~90 Mbps average — fine |
| 120 TB | ~€6 + €100 ≈ €106, but the uplink dies | ~€59, ~370 Mbps average — fine until Friday-night Update All |

Peak math: 10k users grabbing RetroArch (200 MB) in two hours is ~2.2 Gbit. A
1 Gbit dedicated box saturates on a popular update night. Then add a second
box, or 10G (€43 + 20 TB included, then €1/TB), or put R2 in front.

Fits the spec almost perfectly. The download host is a real host tShop runs.
Seven-day access logs → nightly aggregate → delete. Same collector story as
Izzy's `dlstats.izzyondroid.org`.

Worse than R2 at global latency. Handheld users are worldwide. A Falkenstein
box is slow from the US and worse from APAC. Fine for v1. Annoying if tShop
is "the default store."

Dedicated unlimited traffic applies to the default 1 Gbit uplink only. The
10G addon includes 20 TB outgoing and bills €1 ($1.20) per extra TB.

## Option C — Backblaze B2 + Cloudflare

Same shape as A. B2 storage is $6.95/TB since May 2026 (tShop will pay
cents). Egress through Cloudflare and other CDN partners is $0 with no cap.
Egress *not* through Cloudflare is free only up to 3× stored volume — 24 GB
for tShop — then $0.01/GB. A grey-cloud DNS mistake is a $1,200 surprise at
120 TB.

Use this if Cloudflare should be the CDN but not the only storage vendor.
Slightly more moving parts than R2. Same Worker-or-log counting problem.

## Option D — Bunny or any metered CDN

Honest, linear, and the thing people accidentally pick.

Bunny Volume is a flat $5/TB worldwide for the first 500 TB, then $4/TB.
Standard is $10/TB in NA/EU but $30/TB in Asia/Oceania and $60/TB in the
Middle East and Africa; for a worldwide handheld audience the blended
Standard rate is well above $10. Use Volume if Bunny at all.

CloudFront is tiered (NA/EU: $85/TB first 10 TB, $80 next 40, $60 next
100, $40 next 350; 1 TB free; APAC edges ~35% more). The column below uses
the tiers, not a flat $90.

| Scale | Bunny Volume | CloudFront / S3 (NA/EU tiers) |
|---|---|---|
| 3 TB | ~$15 | ~$170 |
| 30 TB | ~$150 | ~$2,400 |
| 120 TB | ~$600 | ~$8,200 |
| 600 TB | ~$2,900 | ~$27,000 |

Counting is awkward: the origin only sees cache misses. Bunny logs or an edge
script are required, or "completed" is a lie. Do not pick this unless R2 and
Hetzner are unavailable. It is how a successful store becomes a Patreon for
*bandwidth* instead of curation.

## Option E — F-Droid mirrors later

Volunteer rsync mirrors are how F-Droid survives 675 GB × a global audience.
At 8 GB of APKs, anyone can mirror tShop.

The spec problem: if clients use mirrors, the counted host does not see
completions, and popularity becomes "whoever hit origin." Options:

- keep the counted host canonical and treat mirrors as overflow /
  Privacy-Mode-adjacent, or
- have mirrors ship nightly aggregates (political, messy, incomplete).

Worth it after tShop is actually popular. Not a v1 design.

fdroidserver itself is not a server. It emits a static signed tree and
`deploy` rsyncs it. Two-phase rsync (indexes last, `--delete-after`) is worth
copying. Four parallel index formats, a 10-deep diff chain, and `archive/` as
a second repo are not, at 30–50 apps.

## Option F — Do not rehost

Pipeline validates, catalog points at upstream. Privacy Mode is the only path.
Dashboard is empty, or tShop scrapes GitHub `download_count` the way komi does.

Cost: ~$0–10/mo at any scale. GitHub outages are accepted, which is the
failure mode the host exists to prevent. This violates the current PRD unless
the product changes. It is listed because the refs show it is how every
popular *handheld* store actually ships today, including a 90k-user one.

## Degenerate cases: how strangers run up the bill

R2 took bandwidth off the table, and bandwidth was the only meter without
a ceiling. What remains on Option A is linear per-request pricing on the
Worker path, with no hard spend cap at Cloudflare. That is bounded, but only
by how much traffic gets past the edge and for how long.

### What an attacker is actually paying for

Every request that *reaches the Worker* costs ~$0.66/M: $0.30 for the
Worker invocation plus $0.36 for the Class B `bucket.get()`, which happens
before streaming, so aborting after the headers does not avoid it. Egress is
$0 whether they take one byte or 200 MB. Completed downloads add $1/M for
D1, but completing costs the attacker 60–200 MB of their own bandwidth per
count, so nobody floods that meter.

Unmitigated exposure is therefore about **$1.70 per month per sustained
request/second** reaching the Worker:

| Sustained rate past the edge | Requests / mo | Bill |
|---|---|---|
| 100 rps | 260M | ~$170 |
| 1k rps | 2.6B | ~$1,700 |
| 10k rps | 26B | ~$17,000 |

Three Cloudflare facts (2026-09-04) shape what that means:

- **Only requests that hit the Worker are billed.** Anything dropped by
  DDoS mitigation, WAF custom rules, or rate limiting rules is free.
  Cloudflare's HTTP DDoS protection is unmetered and on by default; 10k rps
  against one hostname is the textbook flood it exists for.
- **There is no hard spend cap.** Budget alerts are email-only, evaluated
  daily, and explicitly "do not pause or cap usage." A $10 alert is on by
  default for pay-as-you-go accounts since June 2026. The day-after lag is
  the minimum blast radius without a self-built breaker.
- **Free-plan rate limiting is one rule**: IP-keyed, fixed 10 s window,
  10 s block, matching on Path only. Pro ($25/mo) gets two rules and
  1-minute windows. Enough to cap a single IP at ~2 rps on `/apk/*`;
  useless against 10k residential IPs at one request each. Bot Fight Mode
  and challenges are off the table: the client is an Android app, and a JS
  challenge on `/apk/*` bricks Install for everyone.

Realistic residual: Cloudflare eats the volumetric floods, the one-rule
limiter stops single-VPS scripts, and what slips through is low-and-slow
distributed traffic that is by construction low-cost. A 1k rps flood that
evades everything for the one day before an alert fires is 86M requests,
about **$57**. That is the worst case with mitigations. $17k is the worst
case with none and nobody looking for a month.

### Ranked by how likely they actually are

1. **tShop's own client.** The most probable "attacker" is a retry loop in
   the update checker. The DuckStation release notes in the refs describe
   exactly this failure ("obtainium will request update every 5 minutes on
   your device"). 50k devices re-downloading a 200 MB APK every five minutes
   is 14M downloads a day. On R2 that is 2.9 PB of *free* egress and about
   $290 in ops for the month, which is a stunning argument for R2, but the
   counts are garbage and every user's data plan hates tShop. Mitigation is
   client-side (never download unless version *and* sha differ; exponential
   backoff on failure) plus a server-side sanity clamp before counts are
   published.
2. **Counter poisoning.** Cheap and inevitable once the stats page exists.
   One Hetzner box at 1 Gbit completes ~2 downloads/s of a 60 MB APK, so
   +100k fake downloads costs an attacker about 14 hours and costs tShop
   ~$0.10. Two holes to close in the Worker:
   - If "the range that ends at `size - 1`" counts as a completion, a
     one-byte `Range: bytes=199999999-` is a free count. Count full 200s
     only; `Range` requests are served but never counted.
   - Reject multi-range requests (`bytes=0-1,5-6,...`) outright.
   Beyond that: the free rate-limit rule on `/apk/*`, a daily clamp in the
   pipeline (flag a package whose count jumps more than N× its trailing
   median instead of publishing it), and a line on the stats page saying
   counts are approximate. Public counters are soft. Design like it.
3. **Hotlinking.** Another store or setup guide links straight to
   `dl.…/apk/<sha>`. Financially ~$0.66/M, irrelevant, but it poisons
   counts with downloads that were not tShop installs. A WAF custom rule
   (free plan: five) blocking `/apk/*` without the client's User-Agent is
   trivially spoofable but stops every lazy case, unbilled.
4. **Catalog cache-busting.** If catalog and art live in an R2 public
   bucket, `catalog.json?x=<random>` is a cache miss per request, so Class B
   per request. Either a Cache Rule ignoring query strings, or put catalog
   and art on Pages, where static asset requests are unmetered and there is
   no meter to attack. Pages' 25 MB per-file limit rules it out for APKs;
   it is the right home for everything else.
5. **Paths around the Worker.** `r2.dev` stays disabled and the bucket has
   no custom domain of its own; otherwise there is an uncounted path that
   also bypasses the rate-limit rule. The only public route to APK bytes is
   the Worker.
6. **The Hetzner spare.** The rsync copy *pulls* from R2 via the S3 API, so
   the box needs zero inbound and zero DNS. It is only a target if
   promoted. If promoted and flooded, cost is bounded by the NIC: ~1 Gbit
   saturated for a month is ~320 TB, about €300 over the included 20 TB.
   Bounded, and avoidable by proxying it through Cloudflare when promoted so
   the cache absorbs the hits.
7. **Pipeline box compromise.** Not a cost problem. A malicious APK signed
   by the pipeline is a security problem and belongs in the signing design
   (key not on the box, or a human approval gate). Storage bloat from a
   leaked token is $0.015/GB, irrelevant.
8. **Fake DMCA.** R2 makes Cloudflare the host of record, so bogus notices
   go to them and they may disable objects. Cost is time, plus the catalog
   base-URL flip to the spare.

### Two things worth building for this

**A kill switch that costs nothing when it fires.** A cron Worker polls the
GraphQL analytics API every few minutes; if `/apk/*` requests over the last
hour exceed a ceiling, it adds a WAF custom rule via the API blocking
`/apk/*`. Blocked requests are unbilled, so the meter stops within minutes
instead of at the day-after email.
[cf-usage-guard](https://github.com/tristanwagner/cf-usage-guard) is an
existing implementation of the pattern.

**A graceful-degrade lever, not just an off switch.** Give the bytes two
hostnames: `dl.…/apk/<sha>` (Worker, counted) and `cdn.…/<sha>` (R2 custom
domain, Cloudflare cache in front, uncounted, Class B only on cache miss,
Cache Rule ignoring query strings). The catalog base URL is one field. Under
a flood: block the Worker path, republish the catalog pointing at `cdn`, and
tShop stays *up* at ~$0/month while the counter is offline. Users lose
nothing; the dashboard has a gap. That is a better failure mode than "the
store is down because the operator panicked about a bill."

### Verdict

"Costs to infinity" is not available to them. R2 removed bandwidth, the only
unbounded meter. What is left is ~$1.70/month per rps that gets past
Cloudflare's free mitigation, with a day of lag before the operator hears
about it by default. Realistic attacker damage is tens of dollars plus a
poisoned dashboard. The most expensive plausible incident is tShop's own
client in a loop, and R2 makes even that a $300 mistake instead of $30,000.

## Side-by-side at "it got popular"

Monthly, 50k users, ~30 TB APK egress, ~8 GB stored. Pipeline + catalog +
dashboard included.

| Architecture | ~Monthly | What breaks first |
|---|---|---|
| A. R2 + Worker | $5–10 | Cloudflare pricing change; a Worker that counts bytes in JS |
| C. B2 + CF | $5–15 | Misconfigured DNS → paid B2 egress |
| B. Hetzner dedicated | €59 | 1 Gbit on update night |
| B. Hetzner Cloud | €16 | Shared uplink, then overage |
| D. Bunny Volume | $150 | The invoice, linearly |
| S3 + CloudFront | ~$2,400 | The invoice, immediately |
| Wasabi | "limit or suspend", verbatim from their FAQ | Account review |
| F. Upstream only | $5 | GitHub, and the dashboard |

At 200k users / 120 TB the R2 line barely moves. Bunny is $600. S3 is
~$8,200, a five-figure accident once APAC edges are in the mix. Hetzner
dedicated is still ~€59 until the NIC saturates.

## Recommended v1 path

Cheapest path that still matches the written spec:

1. **R2 as the APK and asset store.** Content-addressed, latest-only, custom
   domain.
2. **Worker only on `/apk/*`**, `FixedLengthStream` pass-through, count on
   clean complete into D1 or Analytics Engine, `Range` handled. Catalog and
   art bypass the Worker so browse is free and uncounted. No raw IP logs
   unless there is a reason.
3. **Pages** for the signed catalog, art, and the stats HTML. Static asset
   requests there are unmetered, so there is no per-request meter to flood.
   The dashboard is pipeline output — not a web app.
4. **A `rehost` flag per catalog entry.** Landing Page entries (ES-DE,
   NetherSX2, DuckStation, anything ND-licensed or paid) show Go to
   Publisher with an explainer and never enter the pipeline.
5. **Edge rules, all free and unbilled when they fire:** the one rate-limit
   rule on `/apk/*` (~20 requests per 10 s per IP, enough for Update All), a
   WAF rule dropping `/apk/*` without the client User-Agent, `r2.dev` off,
   no custom domain on the bucket itself.
6. **A kill switch and a degrade lever.** Cron Worker → GraphQL analytics →
   WAF block on `/apk/*` when requests exceed a ceiling. A second hostname
   on the bucket (`cdn.…`, cache-fronted, uncounted) so the catalog base URL
   can flip and the store stays up while the counter is off.
7. **A €4–6 Hetzner CX in Falkenstein or Helsinki** as the release watcher
   / validator / uploader. GitHub Actions is fine until a cron on a box is
   easier.
8. **rsync a copy to that box** so Cloudflare is not a single point of
   existence. The box pulls; it has no inbound and no DNS until promoted.
9. If R2 ever gets hostile, flip the catalog base URL to the Hetzner copy,
   proxied through Cloudflare. Option B is already running as a spare.

That stays under **$20/month** from launch through "we are the default
handheld store," as long as old APKs are not archived, nightlies are not
shipped, game dumps are not added, and the Worker never touches APK bytes
in JavaScript.

The PRD's Patreon question is then about **curator time**, which is the real
scarce resource at 30–50 apps, not bandwidth. Izzy runs 1,393 rehosted apps as
one person with cron and no CI. komi serves 90k users without hosting a single
APK. tShop is choosing to host, on purpose. Do it on a zero-egress store and
the popularity problem is an ops problem, not a money problem.

The ways this project actually produces a five-figure invoice are all
policy failures, not scale: someone reaches for S3/CloudFront or grey-clouds
the B2 bucket; game dumps land on the host; tShop rehosts a binary it has no
license to redistribute and the cost arrives as a letter instead of a
bandwidth line; or a request flood runs for a month against a Worker with no
kill switch and nobody reading the budget email. All four are one flag, one
rule, or one cron job away from impossible.

## What this document is not

This is not a signing design, a catalog format, a rollback story, or an
operator runbook. Those still belong to the infrastructure plan. This document
only answers: if the current plan ships and people use it, what does bandwidth
cost, and what is the cheapest honest way to pay it.
