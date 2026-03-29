import { Hono } from "hono";
import type { Bindings, EventRow } from "../types";

const app = new Hono<{ Bindings: Bindings }>();

const DEFAULT_PAGE_SIZE = 50;

app.get("/", async (c) => {
  const cursor = c.req.query("cursor");
  const limit = Math.min(Number(c.req.query("limit") ?? DEFAULT_PAGE_SIZE), 100);

  let query: string;
  let params: (string | number)[];

  if (cursor) {
    query = `SELECT * FROM events WHERE id < ? ORDER BY id DESC LIMIT ?`;
    params = [Number(cursor), limit + 1];
  } else {
    query = `SELECT * FROM events ORDER BY id DESC LIMIT ?`;
    params = [limit + 1];
  }

  const { results } = await c.env.DB.prepare(query).bind(...params).all<EventRow>();

  const hasMore = results.length > limit;
  const events = hasMore ? results.slice(0, limit) : results;
  const nextCursor = hasMore ? events[events.length - 1].id : null;

  return c.json({
    events: events.map((e) => ({
      id: e.id,
      title: e.title,
      message: e.message,
      source: e.source,
      level: e.level,
      urgent: e.urgent === 1,
      url: e.url,
      created_at: e.created_at,
      read_at: e.read_at,
    })),
    next_cursor: nextCursor,
  });
});

export default app;
