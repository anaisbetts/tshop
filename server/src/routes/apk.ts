import {
  applyCorsHeaders,
  corsPreflightResponse,
  jsonResponse,
  methodNotAllowedResponse,
} from "../http";
import type { DownloadIntent, Env } from "../types";

const APK_PATH_PATTERN = /^\/apk\/([a-f0-9]{64})\.apk$/;
const APK_CONTENT_TYPE = "application/vnd.android.package-archive";
const IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable";
const UPSERT_COMPLETION_SQL = `INSERT INTO completions (sha256, utc_day, intent, n)
VALUES (?, ?, ?, 1)
ON CONFLICT(sha256, utc_day, intent) DO UPDATE SET n = n + 1`;

interface ByteSpan {
  start: number;
  length: number;
}

export interface WaitUntilContext {
  waitUntil(promise: Promise<unknown>): void;
}

export async function handleApkRequest(
  request: Request,
  env: Env,
  ctx: WaitUntilContext,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }
  if (request.method !== "GET" && request.method !== "HEAD") {
    return methodNotAllowedResponse();
  }

  const url = new URL(request.url);
  const match = APK_PATH_PATTERN.exec(url.pathname);
  if (match === null) {
    return jsonResponse({ error: "not_found" }, 404);
  }

  const sha256 = match[1];
  const key = `${sha256}.apk`;

  if (request.method === "HEAD") {
    return headApk(env, key, sha256);
  }

  const intent = parseIntent(url.searchParams.get("r"));
  return serveApk(request, env, ctx, key, sha256, intent);
}

async function serveApk(
  request: Request,
  env: Env,
  ctx: WaitUntilContext,
  key: string,
  sha256: string,
  intent: DownloadIntent,
): Promise<Response> {
  const rangeHeader = request.headers.get("Range");
  if (rangeHeader?.includes(",")) {
    return jsonResponse({ error: "multi_range_not_supported" }, 400);
  }

  const ranged = rangeHeader !== null;
  const object = await env.APKS_BUCKET.get(
    key,
    ranged ? { range: request.headers } : undefined,
  );
  if (object === null) {
    return jsonResponse({ error: "not_found" }, 404);
  }
  if (!("body" in object) || object.body === undefined) {
    return jsonResponse({ error: "precondition_failed" }, 412);
  }

  const size = Number(object.size);
  const length = ranged ? bodyLength(size, object.range) : size;
  const { readable, writable } = new FixedLengthStream(length);
  const headers = buildApkHeaders(object, sha256, ranged);
  const pipe = object.body.pipeTo(writable);

  if (!ranged) {
    ctx.waitUntil(
      pipe.then(() => recordCompletion(env, sha256, intent), ignore),
    );
  } else {
    ctx.waitUntil(pipe.then(undefined, ignore));
  }

  return new Response(readable, {
    status: ranged ? 206 : 200,
    headers,
  });
}

async function headApk(
  env: Env,
  key: string,
  sha256: string,
): Promise<Response> {
  const object = await env.APKS_BUCKET.head(key);
  if (object === null) {
    return jsonResponse({ error: "not_found" }, 404);
  }

  const headers = buildApkHeaders(object, sha256, false);
  return new Response(null, { status: 200, headers });
}

async function recordCompletion(
  env: Env,
  sha256: string,
  intent: DownloadIntent,
): Promise<void> {
  const utcDay = new Date().toISOString().slice(0, 10);
  await env.ANALYTICS_DB.prepare(UPSERT_COMPLETION_SQL)
    .bind(sha256, utcDay, intent)
    .run();
}

function parseIntent(raw: string | null): DownloadIntent {
  if (raw === "install") {
    return "install";
  }
  if (raw === "update") {
    return "update";
  }
  return "unknown";
}

function buildApkHeaders(
  object: R2Object,
  sha256: string,
  ranged: boolean,
): Headers {
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("Content-Type", APK_CONTENT_TYPE);
  headers.set("Content-Disposition", `attachment; filename="${sha256}.apk"`);
  headers.set("Cache-Control", IMMUTABLE_CACHE_CONTROL);
  headers.set("ETag", object.httpEtag);
  headers.set("Accept-Ranges", "bytes");
  headers.set("Content-Length", String(bodyLength(object.size, object.range)));
  if (ranged && object.range) {
    headers.set("Content-Range", contentRangeHeader(object.size, object.range));
  }
  applyCorsHeaders(headers);
  return headers;
}

function bodyLength(size: number, range: R2Range | undefined): number {
  if (!range) {
    return size;
  }
  return rangeSpan(size, range).length;
}

function contentRangeHeader(size: number, range: R2Range): string {
  const { start, length } = rangeSpan(size, range);
  return `bytes ${start}-${start + length - 1}/${size}`;
}

function rangeSpan(size: number, range: R2Range): ByteSpan {
  if (isSuffixRange(range)) {
    const length = Math.min(range.suffix, size);
    return { start: size - length, length };
  }
  const start = range.offset ?? 0;
  const remaining = Math.max(0, size - start);
  const length =
    range.length === undefined ? remaining : Math.min(range.length, remaining);
  return { start, length };
}

function isSuffixRange(range: R2Range): range is { suffix: number } {
  return "suffix" in range && typeof range.suffix === "number";
}

function ignore(_error: unknown): void {}
