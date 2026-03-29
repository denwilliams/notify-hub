import { Hono } from "hono";
import type { Bindings } from "../types";
import { sendPushover } from "../services/pushover";

const app = new Hono<{ Bindings: Bindings }>();

interface NotifyPayload {
  title: string;
  message: string;
  source: string;
  urgent: boolean;
  level?: "info" | "warn" | "error";
  url?: string;
}

app.post("/", async (c) => {
  const body = await c.req.json<NotifyPayload>();

  if (!body.title || !body.message || !body.source || body.urgent === undefined) {
    return c.json({ error: "Missing required fields: title, message, source, urgent" }, 400);
  }

  const level = body.level ?? "info";
  if (!["info", "warn", "error"].includes(level)) {
    return c.json({ error: "Invalid level: must be info, warn, or error" }, 400);
  }

  const urgent = body.urgent ? 1 : 0;
  const pushed = urgent; // urgent events are marked as pushed immediately
  const now = new Date().toISOString();

  const result = await c.env.DB.prepare(
    `INSERT INTO events (title, message, source, level, urgent, url, pushed, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(body.title, body.message, body.source, level, urgent, body.url ?? null, pushed, now)
    .run();

  if (urgent) {
    await sendPushover(
      c.env.PUSHOVER_TOKEN,
      c.env.PUSHOVER_USER,
      body.title,
      body.message,
      1,
      body.url
    );
  }

  return c.json({ id: result.meta.last_row_id, created_at: now }, 201);
});

export default app;
