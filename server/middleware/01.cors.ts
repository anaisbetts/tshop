import { defineMiddleware } from "void";
import { corsPreflightResponse } from "../src/http";

export default defineMiddleware(async (c, next) => {
  if (c.req.method === "OPTIONS") {
    return corsPreflightResponse();
  }
  await next();
});
