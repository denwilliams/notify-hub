import { env, SELF } from "cloudflare:test";

const API_KEY = "test-api-key";

export async function applySchema() {
  await env.DB.exec(
    "CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, message TEXT NOT NULL, source TEXT NOT NULL, level TEXT NOT NULL DEFAULT 'info', urgent INTEGER NOT NULL DEFAULT 0, url TEXT, task_id TEXT, pushed INTEGER NOT NULL DEFAULT 0, read_at TEXT, created_at TEXT NOT NULL);"
  );
}

export async function clearEvents() {
  await env.DB.exec("DELETE FROM events");
}

export async function seedEvent(overrides: Record<string, unknown> = {}) {
  const defaults = {
    title: "Test event",
    message: "Test message",
    source: "test",
    level: "info",
    urgent: 0,
    url: null,
    task_id: null,
    pushed: 0,
    read_at: null,
    created_at: new Date().toISOString(),
  };
  const data = { ...defaults, ...overrides };
  const result = await env.DB.prepare(
    `INSERT INTO events (title, message, source, level, urgent, url, task_id, pushed, read_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      data.title,
      data.message,
      data.source,
      data.level,
      data.urgent,
      data.url,
      data.task_id,
      data.pushed,
      data.read_at,
      data.created_at
    )
    .run();
  return result.meta.last_row_id;
}

export function post(path: string, body: unknown) {
  return SELF.fetch(`http://localhost${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": API_KEY,
    },
    body: JSON.stringify(body),
  });
}

export function get(path: string) {
  return SELF.fetch(`http://localhost${path}`, {
    headers: { "x-api-key": API_KEY },
  });
}

export function put(path: string) {
  return SELF.fetch(`http://localhost${path}`, {
    method: "PUT",
    headers: { "x-api-key": API_KEY },
  });
}

export function del(path: string) {
  return SELF.fetch(`http://localhost${path}`, {
    method: "DELETE",
    headers: { "x-api-key": API_KEY },
  });
}

export function fetchNoAuth(path: string) {
  return SELF.fetch(`http://localhost${path}`);
}
