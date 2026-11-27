import { describe, expect, it } from "vite-plus/test";
import worker from "../src/index";
import { createTestHarness } from "./mocks";

const BASE_URL = "https://dev.tshop.local";
const SAMPLE_APK_SHA =
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
const SAMPLE_CATALOG_SHA =
  "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";
const SAMPLE_ART_SHA =
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const SAMPLE_APK_BYTES = new TextEncoder().encode(
  "PK\u0003\u0004fake-android-apk-payload-0123456789",
);

describe("worker routing and /health", () => {
  it("returns 200 JSON on GET /health with CORS", async () => {
    const { env, ctx } = createTestHarness();
    const res = await worker.fetch(
      new Request(`${BASE_URL}/health`),
      env,
      ctx.asExecutionContext(),
    );

    expect(res.status).toBe(200);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(res.headers.get("Content-Type")).toBe(
      "application/json; charset=utf-8",
    );
    expect(await res.json()).toEqual({ ok: true, service: "tshop-dev-server" });
  });

  it("handles OPTIONS CORS preflight", async () => {
    const { env, ctx } = createTestHarness();
    const res = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk`, {
        method: "OPTIONS",
      }),
      env,
      ctx.asExecutionContext(),
    );

    expect(res.status).toBe(204);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(res.headers.get("Access-Control-Allow-Methods")).toContain("GET");
    expect(res.headers.get("Access-Control-Allow-Methods")).toContain("HEAD");
  });

  it("returns 404 JSON for unknown routes", async () => {
    const { env, ctx } = createTestHarness();
    const res = await worker.fetch(
      new Request(`${BASE_URL}/does-not-exist`),
      env,
      ctx.asExecutionContext(),
    );

    expect(res.status).toBe(404);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(await res.json()).toEqual({ error: "not_found" });
  });
});

describe("static routes (/pointer.json, /catalog/*, /art/*)", () => {
  it("returns 404 when /pointer.json is unseeded", async () => {
    const { env, ctx } = createTestHarness();
    const res = await worker.fetch(
      new Request(`${BASE_URL}/pointer.json`),
      env,
      ctx.asExecutionContext(),
    );

    expect(res.status).toBe(404);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
  });

  it("serves /pointer.json with ETag, short cache, CORS, and 304 on matching If-None-Match", async () => {
    const { env, ctx, assetsBucket } = createTestHarness();
    const payload = JSON.stringify({
      schemaVersion: 1,
      minClientVersionCode: 100,
      generatedAt: "2026-04-01T00:00:00Z",
      keyId: "tshop-dev-01",
      catalogUrl: `/catalog/catalog-${SAMPLE_CATALOG_SHA}.json`,
      catalogSha256: SAMPLE_CATALOG_SHA,
      catalogSize: 42,
      statsUrl: "https://stats.tshop.local/",
      signature: "c2ln",
    });
    const stored = assetsBucket.seed("public/pointer.json", payload, "ptr-v1");

    const first = await worker.fetch(
      new Request(`${BASE_URL}/pointer.json`),
      env,
      ctx.asExecutionContext(),
    );
    expect(first.status).toBe(200);
    expect(first.headers.get("Content-Type")).toBe(
      "application/json; charset=utf-8",
    );
    expect(first.headers.get("Cache-Control")).toBe("public, max-age=60");
    expect(first.headers.get("ETag")).toBe(stored.httpEtag);
    expect(first.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(await first.text()).toBe(payload);

    const notModified = await worker.fetch(
      new Request(`${BASE_URL}/pointer.json`, {
        headers: { "If-None-Match": stored.httpEtag },
      }),
      env,
      ctx.asExecutionContext(),
    );
    expect(notModified.status).toBe(304);
    expect(notModified.headers.get("ETag")).toBe(stored.httpEtag);
    expect(notModified.headers.get("Cache-Control")).toBe("public, max-age=60");
    expect(notModified.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(await notModified.text()).toBe("");

    const weakNotModified = await worker.fetch(
      new Request(`${BASE_URL}/pointer.json`, {
        headers: { "If-None-Match": `W/${stored.httpEtag}` },
      }),
      env,
      ctx.asExecutionContext(),
    );
    expect(weakNotModified.status).toBe(304);

    const headRes = await worker.fetch(
      new Request(`${BASE_URL}/pointer.json`, { method: "HEAD" }),
      env,
      ctx.asExecutionContext(),
    );
    expect(headRes.status).toBe(200);
    expect(headRes.headers.get("Content-Length")).toBe(String(payload.length));
    expect(await headRes.text()).toBe("");
  });

  it("serves immutable /catalog/catalog-<sha>.json and rejects invalid catalog names", async () => {
    const { env, ctx, assetsBucket } = createTestHarness();
    const catalogJson = JSON.stringify({ schemaVersion: 1, entries: [] });
    assetsBucket.seed(
      `public/catalog/catalog-${SAMPLE_CATALOG_SHA}.json`,
      catalogJson,
    );

    const res = await worker.fetch(
      new Request(`${BASE_URL}/catalog/catalog-${SAMPLE_CATALOG_SHA}.json`),
      env,
      ctx.asExecutionContext(),
    );
    expect(res.status).toBe(200);
    expect(res.headers.get("Content-Type")).toBe(
      "application/json; charset=utf-8",
    );
    expect(res.headers.get("Cache-Control")).toBe(
      "public, max-age=31536000, immutable",
    );
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(await res.text()).toBe(catalogJson);

    const badShort = await worker.fetch(
      new Request(`${BASE_URL}/catalog/catalog-abc.json`),
      env,
      ctx.asExecutionContext(),
    );
    expect(badShort.status).toBe(404);

    const badUpper = await worker.fetch(
      new Request(
        `${BASE_URL}/catalog/catalog-${SAMPLE_CATALOG_SHA.toUpperCase()}.json`,
      ),
      env,
      ctx.asExecutionContext(),
    );
    expect(badUpper.status).toBe(404);
  });

  it("serves immutable /art/<sha>.<ext> with exact Content-Type and rejects unsafe filenames", async () => {
    const { env, ctx, assetsBucket } = createTestHarness();
    const webpBytes = new Uint8Array([0x52, 0x49, 0x46, 0x46]);
    const pngBytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);
    const jpgBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);

    assetsBucket.seed(`public/art/${SAMPLE_ART_SHA}.webp`, webpBytes);
    assetsBucket.seed(`public/art/${SAMPLE_ART_SHA}.png`, pngBytes);
    assetsBucket.seed(`public/art/${SAMPLE_ART_SHA}.jpg`, jpgBytes);

    const webpRes = await worker.fetch(
      new Request(`${BASE_URL}/art/${SAMPLE_ART_SHA}.webp`),
      env,
      ctx.asExecutionContext(),
    );
    expect(webpRes.status).toBe(200);
    expect(webpRes.headers.get("Content-Type")).toBe("image/webp");
    expect(webpRes.headers.get("Cache-Control")).toBe(
      "public, max-age=31536000, immutable",
    );
    expect(webpRes.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(new Uint8Array(await webpRes.arrayBuffer())).toEqual(webpBytes);

    const pngRes = await worker.fetch(
      new Request(`${BASE_URL}/art/${SAMPLE_ART_SHA}.png`),
      env,
      ctx.asExecutionContext(),
    );
    expect(pngRes.status).toBe(200);
    expect(pngRes.headers.get("Content-Type")).toBe("image/png");

    const jpgRes = await worker.fetch(
      new Request(`${BASE_URL}/art/${SAMPLE_ART_SHA}.jpg`),
      env,
      ctx.asExecutionContext(),
    );
    expect(jpgRes.status).toBe(200);
    expect(jpgRes.headers.get("Content-Type")).toBe("image/jpeg");

    for (const badPath of [
      `/art/${SAMPLE_ART_SHA}.svg`,
      `/art/${SAMPLE_ART_SHA.toUpperCase()}.webp`,
      "/art/short.webp",
      `/art/../${SAMPLE_ART_SHA}.webp`,
      `/art/${SAMPLE_ART_SHA}.webp.exe`,
    ]) {
      const badRes = await worker.fetch(
        new Request(`${BASE_URL}${badPath}`),
        env,
        ctx.asExecutionContext(),
      );
      expect(badRes.status).toBe(404);
    }
  });
});

describe("APK download route (/apk/<sha256>.apk)", () => {
  it("streams full 200 APK and increments D1 completions for install, update, and unknown intents", async () => {
    const { env, ctx, apksBucket, analyticsDb } = createTestHarness();
    apksBucket.seed(`${SAMPLE_APK_SHA}.apk`, SAMPLE_APK_BYTES, "apk-etag-1");

    const installRes = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk?r=install`),
      env,
      ctx.asExecutionContext(),
    );
    expect(installRes.status).toBe(200);
    expect(installRes.headers.get("Content-Type")).toBe(
      "application/vnd.android.package-archive",
    );
    expect(installRes.headers.get("Content-Disposition")).toBe(
      `attachment; filename="${SAMPLE_APK_SHA}.apk"`,
    );
    expect(installRes.headers.get("Cache-Control")).toBe(
      "public, max-age=31536000, immutable",
    );
    expect(installRes.headers.get("Accept-Ranges")).toBe("bytes");
    expect(installRes.headers.get("Content-Length")).toBe(
      String(SAMPLE_APK_BYTES.byteLength),
    );
    expect(installRes.headers.get("ETag")).toBe('"apk-etag-1"');
    expect(installRes.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(new Uint8Array(await installRes.arrayBuffer())).toEqual(
      SAMPLE_APK_BYTES,
    );
    await ctx.flush();

    const installAgain = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk?r=install`),
      env,
      ctx.asExecutionContext(),
    );
    expect(installAgain.status).toBe(200);
    await installAgain.arrayBuffer();
    await ctx.flush();

    const updateRes = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk?r=update`),
      env,
      ctx.asExecutionContext(),
    );
    expect(updateRes.status).toBe(200);
    await updateRes.arrayBuffer();
    await ctx.flush();

    const unknownMissingRes = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk`),
      env,
      ctx.asExecutionContext(),
    );
    expect(unknownMissingRes.status).toBe(200);
    await unknownMissingRes.arrayBuffer();
    await ctx.flush();

    const unknownBogusRes = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk?r=other`),
      env,
      ctx.asExecutionContext(),
    );
    expect(unknownBogusRes.status).toBe(200);
    await unknownBogusRes.arrayBuffer();
    await ctx.flush();

    const today = new Date().toISOString().slice(0, 10);
    expect(analyticsDb.queryCompletions()).toEqual([
      { sha256: SAMPLE_APK_SHA, utc_day: today, intent: "install", n: 2 },
      { sha256: SAMPLE_APK_SHA, utc_day: today, intent: "unknown", n: 2 },
      { sha256: SAMPLE_APK_SHA, utc_day: today, intent: "update", n: 1 },
    ]);
  });

  it("serves HEAD uncounted with Content-Length, ETag, and Accept-Ranges", async () => {
    const { env, ctx, apksBucket, analyticsDb } = createTestHarness();
    apksBucket.seed(`${SAMPLE_APK_SHA}.apk`, SAMPLE_APK_BYTES, "apk-etag-head");

    const res = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk?r=install`, {
        method: "HEAD",
      }),
      env,
      ctx.asExecutionContext(),
    );
    await ctx.flush();

    expect(res.status).toBe(200);
    expect(res.headers.get("Content-Length")).toBe(
      String(SAMPLE_APK_BYTES.byteLength),
    );
    expect(res.headers.get("ETag")).toBe('"apk-etag-head"');
    expect(res.headers.get("Accept-Ranges")).toBe("bytes");
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(await res.text()).toBe("");
    expect(analyticsDb.queryCompletions()).toEqual([]);
  });

  it("serves single Range as 206 Partial Content uncounted", async () => {
    const { env, ctx, apksBucket, analyticsDb } = createTestHarness();
    apksBucket.seed(`${SAMPLE_APK_SHA}.apk`, SAMPLE_APK_BYTES, "apk-etag-r");

    const res = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk?r=install`, {
        headers: { Range: "bytes=0-9" },
      }),
      env,
      ctx.asExecutionContext(),
    );
    const body = new Uint8Array(await res.arrayBuffer());
    await ctx.flush();

    expect(res.status).toBe(206);
    expect(res.headers.get("Content-Range")).toBe(
      `bytes 0-9/${SAMPLE_APK_BYTES.byteLength}`,
    );
    expect(res.headers.get("Accept-Ranges")).toBe("bytes");
    expect(res.headers.get("Content-Length")).toBe("10");
    expect(body).toEqual(SAMPLE_APK_BYTES.subarray(0, 10));
    expect(analyticsDb.queryCompletions()).toEqual([]);
  });

  it("rejects multi-range Range headers with 400 and does not count", async () => {
    const { env, ctx, apksBucket, analyticsDb } = createTestHarness();
    apksBucket.seed(`${SAMPLE_APK_SHA}.apk`, SAMPLE_APK_BYTES);

    const res = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk?r=install`, {
        headers: { Range: "bytes=0-3, 5-8" },
      }),
      env,
      ctx.asExecutionContext(),
    );
    await ctx.flush();

    expect(res.status).toBe(400);
    expect(analyticsDb.queryCompletions()).toEqual([]);
  });

  it("returns 404 for missing APK objects and invalid sha256 paths", async () => {
    const { env, ctx, analyticsDb } = createTestHarness();

    const missing = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk?r=install`),
      env,
      ctx.asExecutionContext(),
    );
    expect(missing.status).toBe(404);

    const invalidUpper = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA.toUpperCase()}.apk`),
      env,
      ctx.asExecutionContext(),
    );
    expect(invalidUpper.status).toBe(404);

    const invalidShort = await worker.fetch(
      new Request(`${BASE_URL}/apk/not-a-sha.apk`),
      env,
      ctx.asExecutionContext(),
    );
    expect(invalidShort.status).toBe(404);

    await ctx.flush();
    expect(analyticsDb.queryCompletions()).toEqual([]);
  });

  it("returns 405 for unsupported HTTP methods on /apk/*", async () => {
    const { env, ctx } = createTestHarness();
    const res = await worker.fetch(
      new Request(`${BASE_URL}/apk/${SAMPLE_APK_SHA}.apk`, { method: "POST" }),
      env,
      ctx.asExecutionContext(),
    );
    expect(res.status).toBe(405);
    expect(res.headers.get("Allow")).toContain("GET");
  });
});
