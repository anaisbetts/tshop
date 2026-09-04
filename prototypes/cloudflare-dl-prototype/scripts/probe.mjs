#!/usr/bin/env node
const base = process.env.BASE ?? "http://127.0.0.1:8787";
const key = process.env.KEY ?? "dummy-1m.bin";
const url = `${base}/apk/${key}`;
const waitMs = Number(process.env.WAIT_MS ?? 750);

const results = [];

function pass(name, ok, detail) {
  results.push({ name, ok, detail });
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? ` — ${detail}` : ""}`);
}

async function countsForKey() {
  const response = await fetch(`${base}/counts`);
  if (!response.ok) {
    throw new Error(`/counts ${response.status}`);
  }
  const body = await response.json();
  return (body.results ?? [])
    .filter((row) => row.object_key === key)
    .reduce((sum, row) => sum + Number(row.n), 0);
}

async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function drain(response) {
  const reader = response.body.getReader();
  let bytes = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    bytes += value.byteLength;
  }
  return bytes;
}

async function abortAfterHeaders() {
  const controller = new AbortController();
  const response = await fetch(url, { signal: controller.signal });
  const expected = Number(response.headers.get("content-length"));
  await response.body.cancel();
  controller.abort();
  return { bytes: 0, expected };
}

async function abortAt(fraction) {
  const controller = new AbortController();
  const response = await fetch(url, { signal: controller.signal });
  const expected = Number(response.headers.get("content-length"));
  const cutoff = Math.floor(expected * fraction);
  const reader = response.body.getReader();
  let bytes = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      bytes += value.byteLength;
      if (bytes >= cutoff) {
        await reader.cancel();
        controller.abort();
        break;
      }
    }
  } catch (error) {
    if (error.name !== "AbortError") {
      throw error;
    }
  }
  return { bytes, expected };
}

async function expectDelta(name, run, expectedDelta) {
  const before = await countsForKey();
  const extra = await run();
  await sleep(waitMs);
  const after = await countsForKey();
  const delta = after - before;
  pass(
    name,
    delta === expectedDelta,
    `count ${before} → ${after} (Δ${delta}, want Δ${expectedDelta})${extra ? `; ${extra}` : ""}`,
  );
}

async function main() {
  const head = await fetch(url, { method: "HEAD" });
  if (!head.ok) {
    throw new Error(
      `${url} HEAD ${head.status}. Seed first: npm run seed && npm run seed -- --big`,
    );
  }
  const size = Number(head.headers.get("content-length"));
  console.log(`probing ${url} (${size} bytes)\n`);

  await expectDelta(
    "clean full download",
    async () => {
      const response = await fetch(url);
      const bytes = await drain(response);
      return `status ${response.status}, ${bytes} bytes`;
    },
    1,
  );

  if (size >= 8 * 1024 * 1024) {
    await expectDelta(
      "abort after headers",
      async () => {
        const { expected } = await abortAfterHeaders();
        return `cancelled ${expected}-byte body`;
      },
      0,
    );
    await expectDelta(
      "abort at 97%",
      async () => {
        const { bytes, expected } = await abortAt(0.97);
        return `read ${bytes}/${expected}`;
      },
      0,
    );
  } else {
    console.log(
      "SKIP  abort cases — 1 MB on loopback finishes before the client can disconnect; seed --big or probe a deployed Worker",
    );
  }

  await expectDelta(
    "resume by Range after abort",
    async () => {
      const start = Math.floor(size * 0.97);
      const response = await fetch(url, {
        headers: { Range: `bytes=${start}-` },
      });
      const bytes = await drain(response);
      return `status ${response.status}, ${bytes} bytes`;
    },
    0,
  );

  await expectDelta(
    "one-byte tail range",
    async () => {
      const response = await fetch(url, {
        headers: { Range: `bytes=${size - 1}-` },
      });
      const bytes = await drain(response);
      return `status ${response.status}, ${bytes} bytes`;
    },
    0,
  );

  const beforeMulti = await countsForKey();
  const multi = await fetch(url, {
    headers: { Range: "bytes=0-1,5-6" },
  });
  await sleep(waitMs);
  const afterMulti = await countsForKey();
  pass(
    "multi-range rejected",
    multi.status >= 400 && multi.status < 500 && afterMulti === beforeMulti,
    `status ${multi.status}, count ${beforeMulti} → ${afterMulti}`,
  );

  const parallel = Number(process.env.PARALLEL ?? (size >= 8 * 1024 * 1024 ? 0 : 20));
  if (parallel > 0) {
    await expectDelta(
      `${parallel} parallel full downloads`,
      async () => {
        const statuses = await Promise.all(
          Array.from({ length: parallel }, async () => {
            const response = await fetch(url);
            await drain(response);
            return response.status;
          }),
        );
        return `statuses ${statuses.join(",")}`;
      },
      parallel,
    );
  } else {
    console.log(
      "SKIP  parallel downloads — set PARALLEL=20 for the 200 MB object",
    );
  }

  const failed = results.filter((row) => !row.ok);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (failed.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
