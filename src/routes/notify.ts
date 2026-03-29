import { Hono } from "hono";
import type { Bindings } from "../types";
import { sendPushover } from "../services/pushover";

const app = new Hono<{ Bindings: Bindings }>();

const VALID_LEVELS = ["info", "warn", "error", "in_progress"];

interface NotifyPayload {
  title: string;
  message: string;
  source: string;
  urgent: boolean;
  level?: "info" | "warn" | "error" | "in_progress";
  url?: string;
  task_id?: string;
}

app.post("/", async (c) => {
  const body = await c.req.json<NotifyPayload>();

  if (!body.title || !body.message || !body.source || body.urgent === undefined) {
    return c.json({ error: "Missing required fields: title, message, source, urgent" }, 400);
  }

  const level = body.level ?? "info";
  if (!VALID_LEVELS.includes(level)) {
    return c.json({ error: `Invalid level: must be one of ${VALID_LEVELS.join(", ")}` }, 400);
  }

  const urgent = body.urgent ? 1 : 0;
  const pushed = urgent;
  const now = new Date().toISOString();
  const taskId = body.task_id ?? null;

  let eventId: number;

  if (taskId) {
    // Upsert: replace existing event with same task_id
    const existing = await c.env.DB.prepare(
      `SELECT id FROM events WHERE task_id = ?`
    ).bind(taskId).first<{ id: number }>();

    if (existing) {
      await c.env.DB.prepare(
        `UPDATE events SET title = ?, message = ?, source = ?, level = ?, urgent = ?, url = ?, pushed = ?, read_at = NULL, created_at = ?
         WHERE task_id = ?`
      ).bind(body.title, body.message, body.source, level, urgent, body.url ?? null, pushed, now, taskId).run();
      eventId = existing.id;
    } else {
      const result = await c.env.DB.prepare(
        `INSERT INTO events (title, message, source, level, urgent, url, task_id, pushed, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).bind(body.title, body.message, body.source, level, urgent, body.url ?? null, taskId, pushed, now).run();
      eventId = result.meta.last_row_id as number;
    }
  } else {
    const result = await c.env.DB.prepare(
      `INSERT INTO events (title, message, source, level, urgent, url, pushed, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(body.title, body.message, body.source, level, urgent, body.url ?? null, pushed, now).run();
    eventId = result.meta.last_row_id as number;
  }

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

  return c.json({ id: eventId, created_at: now }, 201);
});

export default app;
