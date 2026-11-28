const CORS_ORIGIN = "*";
const CORS_ALLOW_METHODS = "GET, HEAD, OPTIONS";
const CORS_ALLOW_HEADERS = "Range, If-None-Match";
const CORS_MAX_AGE = "86400";
const JSON_CONTENT_TYPE = "application/json; charset=utf-8";

export function corsPreflightResponse(): Response {
  const headers = new Headers({
    "Access-Control-Allow-Origin": CORS_ORIGIN,
    "Access-Control-Allow-Methods": CORS_ALLOW_METHODS,
    "Access-Control-Allow-Headers": CORS_ALLOW_HEADERS,
    "Access-Control-Max-Age": CORS_MAX_AGE,
  });
  return new Response(null, { status: 204, headers });
}

export function jsonResponse(
  body: unknown,
  status = 200,
  extraHeaders?: HeadersInit,
): Response {
  const headers = new Headers(extraHeaders);
  headers.set("Content-Type", JSON_CONTENT_TYPE);
  applyCorsHeaders(headers);
  return new Response(JSON.stringify(body), { status, headers });
}

export function methodNotAllowedResponse(allow = CORS_ALLOW_METHODS): Response {
  return jsonResponse({ error: "method_not_allowed" }, 405, { Allow: allow });
}

export function applyCorsHeaders(headers: Headers): void {
  headers.set("Access-Control-Allow-Origin", CORS_ORIGIN);
}
