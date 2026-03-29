import { Hono } from "hono";
import type { Bindings } from "../types";

const app = new Hono<{ Bindings: Bindings }>();

app.put("/:id/read", async (c) => {
  const id = Number(c.req.param("id"));
  const now = new Date().toISOString();

  const result = await c.env.DB.prepare(
    `UPDATE events SET read_at = ? WHERE id = ? AND read_at IS NULL`
  )
    .bind(now, id)
    .run();

  if (result.meta.changes === 0) {
    const exists = await c.env.DB.prepare(`SELECT id FROM events WHERE id = ?`)
      .bind(id)
      .first();
    if (!exists) {
      return c.json({ error: "Event not found" }, 404);
    }
  }

  return c.body(null, 204);
});

app.delete("/:id/read", async (c) => {
  const id = Number(c.req.param("id"));

  const result = await c.env.DB.prepare(
    `UPDATE events SET read_at = NULL WHERE id = ? AND read_at IS NOT NULL`
  )
    .bind(id)
    .run();

  if (result.meta.changes === 0) {
    const exists = await c.env.DB.prepare(`SELECT id FROM events WHERE id = ?`)
      .bind(id)
      .first();
    if (!exists) {
      return c.json({ error: "Event not found" }, 404);
    }
  }

  return c.body(null, 204);
});

export default app;
