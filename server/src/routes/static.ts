import {
  applyCorsHeaders,
  corsPreflightResponse,
  jsonResponse,
  methodNotAllowedResponse,
} from "../http";
import type { Env } from "../types";

const POINTER_PATH = "/pointer.json";
const POINTER_R2_KEY = "public/pointer.json";
const CATALOG_PATH_PATTERN = /^\/catalog\/catalog-([a-f0-9]{64})\.json$/;
const ART_PATH_PATTERN = /^\/art\/([a-f0-9]{64}\.(webp|png|jpg|jpeg))$/;
const JSON_CONTENT_TYPE = "application/json; charset=utf-8";
const POINTER_CACHE_CONTROL = "public, max-age=60";
const IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable";

type ArtExtension = "webp" | "png" | "jpg" | "jpeg";

interface StaticAssetTarget {
  r2Key: string;
  contentType: string;
  cacheControl: string;
}

export async function handleStaticRequest(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }
  if (request.method !== "GET" && request.method !== "HEAD") {
    return methodNotAllowedResponse();
  }

  const url = new URL(request.url);
  const target = resolveStaticTarget(url.pathname);
  if (target === null) {
    return jsonResponse({ error: "not_found" }, 404);
  }

  return serveStaticAsset(request, env, target);
}

async function serveStaticAsset(
  request: Request,
  env: Env,
  target: StaticAssetTarget,
): Promise<Response> {
  const ifNoneMatch = request.headers.get("If-None-Match");

  if (request.method === "HEAD" || ifNoneMatch !== null) {
    const head = await env.ASSETS_BUCKET.head(target.r2Key);
    if (head === null) {
      return jsonResponse({ error: "not_found" }, 404);
    }

    if (ifNoneMatch !== null && etagMatches(ifNoneMatch, head.httpEtag)) {
      return notModifiedResponse(head, target);
    }

    if (request.method === "HEAD") {
      const headers = buildStaticHeaders(head, target);
      return new Response(null, { status: 200, headers });
    }
  }

  const object = await env.ASSETS_BUCKET.get(target.r2Key);
  if (object === null) {
    return jsonResponse({ error: "not_found" }, 404);
  }

  const headers = buildStaticHeaders(object, target);
  return new Response(object.body, { status: 200, headers });
}

function resolveStaticTarget(pathname: string): StaticAssetTarget | null {
  if (pathname === POINTER_PATH) {
    return {
      r2Key: POINTER_R2_KEY,
      contentType: JSON_CONTENT_TYPE,
      cacheControl: POINTER_CACHE_CONTROL,
    };
  }

  const catalogMatch = CATALOG_PATH_PATTERN.exec(pathname);
  if (catalogMatch !== null) {
    const sha256 = catalogMatch[1];
    return {
      r2Key: `public/catalog/catalog-${sha256}.json`,
      contentType: JSON_CONTENT_TYPE,
      cacheControl: IMMUTABLE_CACHE_CONTROL,
    };
  }

  const artMatch = ART_PATH_PATTERN.exec(pathname);
  if (artMatch !== null) {
    const filename = artMatch[1];
    const ext = artMatch[2] as ArtExtension;
    return {
      r2Key: `public/art/${filename}`,
      contentType: artContentType(ext),
      cacheControl: IMMUTABLE_CACHE_CONTROL,
    };
  }

  return null;
}

function artContentType(ext: ArtExtension): string {
  switch (ext) {
    case "webp":
      return "image/webp";
    case "png":
      return "image/png";
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    default:
      return assertNever(ext);
  }
}

function buildStaticHeaders(
  object: R2Object,
  target: StaticAssetTarget,
): Headers {
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("Content-Type", target.contentType);
  headers.set("Cache-Control", target.cacheControl);
  headers.set("ETag", object.httpEtag);
  headers.set("Content-Length", String(object.size));
  applyCorsHeaders(headers);
  return headers;
}

function notModifiedResponse(
  object: R2Object,
  target: StaticAssetTarget,
): Response {
  const headers = new Headers();
  headers.set("Cache-Control", target.cacheControl);
  headers.set("ETag", object.httpEtag);
  applyCorsHeaders(headers);
  return new Response(null, { status: 304, headers });
}

function etagMatches(ifNoneMatch: string, etag: string): boolean {
  const trimmed = ifNoneMatch.trim();
  if (trimmed === "*") {
    return true;
  }

  const targetTag = normalizeEtag(etag);
  for (const candidate of trimmed.split(",")) {
    if (normalizeEtag(candidate) === targetTag) {
      return true;
    }
  }
  return false;
}

function normalizeEtag(value: string): string {
  const trimmed = value.trim();
  return trimmed.startsWith("W/") ? trimmed.slice(2) : trimmed;
}

function assertNever(value: never): never {
  throw new Error(`Unexpected value: ${String(value)}`);
}
