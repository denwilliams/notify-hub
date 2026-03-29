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
});
