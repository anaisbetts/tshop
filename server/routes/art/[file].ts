import { defineHandler } from "void";
import { handleStaticRequest } from "../../src/routes/static";

export const GET = defineHandler((c) => {
  return handleStaticRequest(c.req.raw, c.env);
});
