import { createMiddleware } from "hono/factory";
import type { Bindings } from "../types";

export const auth = createMiddleware<{ Bindings: Bindings }>(
  async (c, next) => {
    const key = c.req.header("x-api-key");
    if (!key || key !== c.env.API_KEY) {
      return c.json({ error: "Unauthorized" }, 401);
    }
    await next();
  }
);
