import { describe, it, expect, beforeEach } from "vitest";
import { env } from "cloudflare:test";
import { applySchema, clearEvents, post } from "./helpers";

describe("POST /notify", () => {
  beforeEach(async () => {
    await applySchema();
    await clearEvents();
  });

  it("creates a non-urgent event", async () => {
    const res = await post("/notify", {
      title: "Deploy complete",
      message: "v1.0.0 to prod",
      source: "github",
      urgent: false,
    });

    expect(res.status).toBe(201);
    const body = await res.json<{ id: number; created_at: string }>();
    expect(body.id).toBeGreaterThan(0);
    expect(body.created_at).toBeTruthy();

    // Verify it was stored with pushed=0
    const row = await env.DB.prepare("SELECT * FROM events WHERE id = ?")
      .bind(body.id)
      .first();
    expect(row!.pushed).toBe(0);
    expect(row!.urgent).toBe(0);
    expect(row!.level).toBe("info");
  });

  it("creates an urgent event with pushed=1", async () => {
    const res = await post("/notify", {
      title: "Server down",
      message: "Production is unreachable",
      source: "monitoring",
      urgent: true,
      level: "error",
    });

    expect(res.status).toBe(201);
    const body = await res.json<{ id: number }>();

    const row = await env.DB.prepare("SELECT * FROM events WHERE id = ?")
      .bind(body.id)
      .first();
    expect(row!.pushed).toBe(1);
    expect(row!.urgent).toBe(1);
    expect(row!.level).toBe("error");
  });

  it("stores optional url field", async () => {
    const res = await post("/notify", {
      title: "PR merged",
      message: "#42 merged",
      source: "github",
      urgent: false,
      url: "https://github.com/org/repo/pull/42",
    });

    expect(res.status).toBe(201);
    const body = await res.json<{ id: number }>();

    const row = await env.DB.prepare("SELECT url FROM events WHERE id = ?")
      .bind(body.id)
      .first();
    expect(row!.url).toBe("https://github.com/org/repo/pull/42");
  });

  it("rejects missing required fields", async () => {
    const res = await post("/notify", { title: "Incomplete" });
    expect(res.status).toBe(400);
    const body = await res.json<{ error: string }>();
    expect(body.error).toContain("Missing required fields");
  });

  it("rejects invalid level", async () => {
    const res = await post("/notify", {
      title: "Test",
      message: "msg",
      source: "test",
      urgent: false,
      level: "critical",
    });
    expect(res.status).toBe(400);
    const body = await res.json<{ error: string }>();
    expect(body.error).toContain("Invalid level");
  });

  it("defaults level to info", async () => {
    const res = await post("/notify", {
      title: "Test",
      message: "msg",
      source: "test",
      urgent: false,
    });
    const body = await res.json<{ id: number }>();
    const row = await env.DB.prepare("SELECT level FROM events WHERE id = ?")
      .bind(body.id)
      .first();
    expect(row!.level).toBe("info");
  });

  it("defaults url to null", async () => {
    const res = await post("/notify", {
      title: "Test",
      message: "msg",
      source: "test",
      urgent: false,
    });
    const body = await res.json<{ id: number }>();
    const row = await env.DB.prepare("SELECT url FROM events WHERE id = ?")
      .bind(body.id)
      .first();
    expect(row!.url).toBeNull();
  });

  it("accepts in_progress level", async () => {
    const res = await post("/notify", {
      title: "Deploying",
      message: "Build running",
      source: "ci",
      urgent: false,
      level: "in_progress",
    });
    expect(res.status).toBe(201);
    const body = await res.json<{ id: number }>();
    const row = await env.DB.prepare("SELECT level FROM events WHERE id = ?")
      .bind(body.id)
      .first();
    expect(row!.level).toBe("in_progress");
  });

  it("stores task_id", async () => {
    const res = await post("/notify", {
      title: "Deploy v1",
      message: "Starting",
      source: "ci",
      urgent: false,
      task_id: "deploy-42",
    });
    expect(res.status).toBe(201);
    const body = await res.json<{ id: number }>();
    const row = await env.DB.prepare("SELECT task_id FROM events WHERE id = ?")
      .bind(body.id)
      .first();
    expect(row!.task_id).toBe("deploy-42");
  });

  it("upserts event with same task_id", async () => {
    // First event
    const res1 = await post("/notify", {
      title: "Deploy v1",
      message: "Starting",
      source: "ci",
      urgent: false,
      task_id: "deploy-42",
    });
    expect(res1.status).toBe(201);
    const body1 = await res1.json<{ id: number }>();

    // Update same task_id
    const res2 = await post("/notify", {
      title: "Deploy v1",
      message: "Complete!",
      source: "ci",
      urgent: false,
      task_id: "deploy-42",
      level: "info",
    });
    expect(res2.status).toBe(201);
    const body2 = await res2.json<{ id: number }>();

    // Same ID, updated message
    expect(body2.id).toBe(body1.id);
    const row = await env.DB.prepare("SELECT message, level FROM events WHERE id = ?")
      .bind(body1.id)
      .first();
    expect(row!.message).toBe("Complete!");

    // Only one event exists with this task_id
    const { results } = await env.DB.prepare(
      "SELECT * FROM events WHERE task_id = ?"
    ).bind("deploy-42").all();
    expect(results).toHaveLength(1);
  });

  it("upsert clears read_at", async () => {
    // Create and mark read
    await post("/notify", {
      title: "Deploy",
      message: "v1",
      source: "ci",
      urgent: false,
      task_id: "deploy-99",
    });
    await env.DB.prepare(
      "UPDATE events SET read_at = '2026-01-01T00:00:00Z' WHERE task_id = ?"
    ).bind("deploy-99").run();

    // Upsert
    await post("/notify", {
      title: "Deploy",
      message: "v2",
      source: "ci",
      urgent: false,
      task_id: "deploy-99",
    });

    const row = await env.DB.prepare(
      "SELECT read_at, message FROM events WHERE task_id = ?"
    ).bind("deploy-99").first();
    expect(row!.read_at).toBeNull();
    expect(row!.message).toBe("v2");
  });
});
