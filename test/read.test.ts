import { describe, it, expect, beforeEach } from "vitest";
import { env } from "cloudflare:test";
import { applySchema, clearEvents, seedEvent, put, del } from "./helpers";

describe("PUT /events/:id/read", () => {
  beforeEach(async () => {
    await applySchema();
    await clearEvents();
  });

  it("marks an event as read", async () => {
    const id = await seedEvent({ title: "Unread event" });

    const res = await put(`/events/${id}/read`);
    expect(res.status).toBe(204);

    const row = await env.DB.prepare("SELECT read_at FROM events WHERE id = ?")
      .bind(id)
      .first();
    expect(row!.read_at).toBeTruthy();
  });

  it("is idempotent — marking already-read event returns 204", async () => {
    const id = await seedEvent({
      title: "Already read",
      read_at: "2026-01-01T00:00:00Z",
    });

    const res = await put(`/events/${id}/read`);
    expect(res.status).toBe(204);

    // read_at should not change
    const row = await env.DB.prepare("SELECT read_at FROM events WHERE id = ?")
      .bind(id)
      .first();
    expect(row!.read_at).toBe("2026-01-01T00:00:00Z");
  });

  it("returns 404 for non-existent event", async () => {
    const res = await put("/events/99999/read");
    expect(res.status).toBe(404);
  });
});

describe("DELETE /events/:id/read", () => {
  beforeEach(async () => {
    await applySchema();
    await clearEvents();
  });

  it("marks an event as unread", async () => {
    const id = await seedEvent({
      title: "Read event",
      read_at: "2026-01-01T00:00:00Z",
    });

    const res = await del(`/events/${id}/read`);
    expect(res.status).toBe(204);

    const row = await env.DB.prepare("SELECT read_at FROM events WHERE id = ?")
      .bind(id)
      .first();
    expect(row!.read_at).toBeNull();
  });

  it("is idempotent — unmarking already-unread event returns 204", async () => {
    const id = await seedEvent({ title: "Unread event", read_at: null });

    const res = await del(`/events/${id}/read`);
    expect(res.status).toBe(204);
  });

  it("returns 404 for non-existent event", async () => {
    const res = await del("/events/99999/read");
    expect(res.status).toBe(404);
  });
});
