const APK_PREFIX = "/apk/";

export default {
  async fetch(request, env, ctx): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/counts") {
      return counts(env);
    }
    if (!url.pathname.startsWith(APK_PREFIX)) {
      return new Response("not found", { status: 404 });
    }
    const key = url.pathname.slice(APK_PREFIX.length);
    if (!key) {
      return new Response("missing object key", { status: 400 });
    }
    if (request.method === "HEAD") {
      return headApk(env, key);
    }
    if (request.method !== "GET") {
      return new Response("method not allowed", {
        status: 405,
        headers: { Allow: "GET, HEAD" },
      });
    }
    return serveApk(request, env, ctx, key);
  },
} satisfies ExportedHandler<Env>;

async function serveApk(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  key: string,
): Promise<Response> {
  const rangeHeader = request.headers.get("Range");
  if (rangeHeader?.includes(",")) {
    return new Response("multi-range not supported", { status: 400 });
  }

  const ranged = rangeHeader !== null;
  const object = await env.BUCKET.get(
    key,
    ranged ? { range: request.headers } : undefined,
  );
  if (object === null) {
    return new Response("not found", { status: 404 });
  }
  if (!("body" in object) || object.body === undefined) {
    return new Response("precondition failed", { status: 412 });
  }

  const size = Number(object.size);
  const length = ranged ? bodyLength(size, object.range) : size;
  const { readable, writable } = new FixedLengthStream(length);
  const headers = apkHeaders(object, ranged);
  const pipe = object.body.pipeTo(writable);
  if (!ranged) {
    ctx.waitUntil(pipe.then(() => record(env, key), ignore));
  } else {
    ctx.waitUntil(pipe.then(undefined, ignore));
  }
  return new Response(readable, {
    status: ranged ? 206 : 200,
    headers,
  });
}

async function headApk(env: Env, key: string): Promise<Response> {
  const object = await env.BUCKET.head(key);
  if (object === null) {
    return new Response(null, { status: 404 });
  }
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("accept-ranges", "bytes");
  headers.set("content-length", String(object.size));
  return new Response(null, { status: 200, headers });
}

async function record(env: Env, key: string): Promise<void> {
  const day = new Date().toISOString().slice(0, 10);
  await env.DB.prepare(
    `INSERT INTO completions (object_key, utc_day, n) VALUES (?, ?, 1)
     ON CONFLICT(object_key, utc_day) DO UPDATE SET n = n + 1`,
  )
    .bind(key, day)
    .run();
}

async function counts(env: Env): Promise<Response> {
  const { results } = await env.DB.prepare(
    "SELECT object_key, utc_day, n FROM completions ORDER BY utc_day, object_key",
  ).all<{ object_key: string; utc_day: string; n: number }>();
  return Response.json({ results });
}

function apkHeaders(object: R2Object, ranged: boolean): Headers {
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("accept-ranges", "bytes");
  headers.set("content-length", String(bodyLength(object.size, object.range)));
  if (ranged && object.range) {
    headers.set("content-range", contentRangeHeader(object.size, object.range));
  }
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

function rangeSpan(
  size: number,
  range: R2Range,
): { start: number; length: number } {
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
