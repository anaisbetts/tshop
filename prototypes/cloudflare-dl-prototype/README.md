# Worker completion counter

Throwaway Cloudflare Worker for [specs/98-prototype-this-first.md](../../specs/98-prototype-this-first.md) item **#4**. Nothing here ships.

Question: can a Worker stream a 200 MB object from R2 at near-zero CPU and count exactly once, only when the whole body has been piped? 03's Option A stands or falls on this. 04 §9 says nobody has built it.

The Worker is the one 03 describes: `FixedLengthStream(size)`, `object.body.pipeTo(writable)` unawaited, `ctx.waitUntil(pipe.then(record, ignore))`. 206 for a single `Range`, 400 for multi-range, count only on a completed full 200. Completions go to D1 (queryable) and Analytics Engine (no hot row). Compare them after the 20-wide burst.

A dummy 200 MB object stands in for RetroArch. Swap a real APK into the same key if you want the client's content-type path.

## Run locally

```bash
npm install
npm run seed
npm run dev
```

In another terminal:

```bash
npm run probe
```

`dummy-1m.bin` settles count-on-complete, `Range`, multi-range, and a 20-wide burst. Abort does not work on that file: loopback delivers 1 MB before the client can disconnect, and the pipe resolves. For abort and for anything that looks like RetroArch:

```bash
npm run seed -- --big
KEY=dummy-200m.bin WAIT_MS=2000 npm run probe
```

Local workerd, 2026-09-04: 200 MB full GET Δ1; abort after headers Δ0; abort at 97% Δ0; single `Range` 206 Δ0; multi-range 400 Δ0. D1 matched on twenty parallel 1 MB downloads.

Read CPU-ms from the Workers dashboard after a remote 200 MB pass. Local wrangler is the wrong meter. Twenty parallel 200 MB downloads: `PARALLEL=20 KEY=dummy-200m.bin WAIT_MS=3000 npm run probe`.

## Deploy

Needs a Cloudflare account. First deploy creates the R2 bucket and D1 database.

```bash
npx wrangler login
npx wrangler deploy
npm run seed -- --remote --big
BASE=https://tshop-completion-counter.<account>.workers.dev KEY=dummy-200m.bin WAIT_MS=3000 npm run probe
```

Then the handheld pass 98 lists: Dio (`client/pubspec.yaml` already has it) and, separately, Android `DownloadManager`. Record whether either client splits a transfer into `Range`s — if it does, the full-200-only counter records zero on resume.

Cache Everything is a dashboard rule, not a script. Apply it on `/apk/*`, repeat a clean full download, confirm `/counts` does not move. That is the failure 03 wants known before someone does it for real.

Throughput from the EU, a US VPN, and an APAC VPN is a stopwatch on the 200 MB object. 03 dismisses Hetzner on latency; write the three numbers down.

## Record

One row per case:

| Case | Count Δ | Notes |
|---|---|---|
| Clean full download | | CPU-ms from the dashboard |
| Abort at 97% | | must be 0 |
| Resume by `Range` | | must be 0; this is the undercount |
| One-byte tail | | must be 0 |
| Multi-range | | 4xx, Δ 0 |
| Twenty parallel | | D1 exact? AE lag? |
| Cache Everything | | count disappears? |
| Dio on a handheld | | did it send `Range`? |
| `DownloadManager` | | did it send `Range`? |
| EU / US VPN / APAC VPN | | seconds, not counts |

## Gates

- Option A or B in 03
- The "completed" sentence 99 §5 asks 01 to add
- Whether the client must be told never to parallelise downloads
- The Worker CPU column ($5 vs a CPU-limit error on RetroArch)
