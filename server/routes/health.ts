import { defineHandler } from "void";
import { jsonResponse } from "../src/http";

const SERVICE_NAME = "tshop-dev-server";

export const GET = defineHandler((c) => {
  const response = jsonResponse({ ok: true, service: SERVICE_NAME }, 200, {
    "Cache-Control": "no-store",
  });
  if (c.req.method === "HEAD") {
    return new Response(null, { status: 200, headers: response.headers });
  }
  return response;
});
