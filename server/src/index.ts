import {
  corsPreflightResponse,
  jsonResponse,
  methodNotAllowedResponse,
} from "./http";
import { handleApkRequest } from "./routes/apk";
import { handleStaticRequest } from "./routes/static";
import type { Env } from "./types";

const SERVICE_NAME = "tshop-dev-server";
const HEALTH_PATH = "/health";
const APK_PREFIX = "/apk/";
const POINTER_PATH = "/pointer.json";
const CATALOG_PREFIX = "/catalog/";
const ART_PREFIX = "/art/";

type RouteKind = "health" | "apk" | "static" | "not_found";

export default {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<Response> {
    if (request.method === "OPTIONS") {
      return corsPreflightResponse();
    }

    const url = new URL(request.url);
    const route = classifyRoute(url.pathname);

    switch (route) {
      case "health":
        return handleHealthRequest(request);
      case "apk":
        return handleApkRequest(request, env, ctx);
      case "static":
        return handleStaticRequest(request, env);
      case "not_found":
        return jsonResponse({ error: "not_found" }, 404);
      default:
        return assertNever(route);
    }
  },
} satisfies ExportedHandler<Env>;

function handleHealthRequest(request: Request): Response {
  if (request.method === "HEAD") {
    const response = jsonResponse({ ok: true, service: SERVICE_NAME }, 200, {
      "Cache-Control": "no-store",
    });
    return new Response(null, { status: 200, headers: response.headers });
  }
  if (request.method !== "GET") {
    return methodNotAllowedResponse();
  }
  return jsonResponse({ ok: true, service: SERVICE_NAME }, 200, {
    "Cache-Control": "no-store",
  });
}

function classifyRoute(pathname: string): RouteKind {
  if (pathname === HEALTH_PATH) {
    return "health";
  }
  if (pathname.startsWith(APK_PREFIX)) {
    return "apk";
  }
  if (
    pathname === POINTER_PATH ||
    pathname.startsWith(CATALOG_PREFIX) ||
    pathname.startsWith(ART_PREFIX)
  ) {
    return "static";
  }
  return "not_found";
}

function assertNever(value: never): never {
  throw new Error(`Unexpected route: ${String(value)}`);
}
