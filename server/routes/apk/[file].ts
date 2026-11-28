import { defineHandler } from "void";
import { handleApkRequest } from "../../src/routes/apk";

export const GET = defineHandler((c) => {
  return handleApkRequest(c.req.raw, c.env, c.executionCtx);
});
