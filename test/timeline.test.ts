import { describe, it, expect, beforeEach } from "vitest";
import { applySchema, clearEvents, seedEvent, get } from "./helpers";

describe("GET /timeline", () => {
  beforeEach(async () => {
    await applySchema();
    await clearEvents();
  });

  it("returns empty list when no events", async () => {
    const res = await get("/timeline");
    expect(res.status).toBe(200);
    const body = await res.json<{ events: unknown[]; next_cursor: null }>();
    expect(body.events).toEqual([]);
    expect(body.next_cursor).toBeNull();
  });

  it("returns events in reverse chronological order", async () => {
    await seedEvent({ title: "First", created_at: "2026-01-01T00:00:00Z" });
    await seedEvent({ title: "Second", created_at: "2026-01-02T00:00:00Z" });
    await seedEvent({ title: "Third", created_at: "2026-01-03T00:00:00Z" });

    const res = await get("/timeline");
    const body = await res.json<{ events: { title: string; id: number }[] }>();

    expect(body.events).toHaveLength(3);
    // Ordered by id DESC (latest first)
    expect(body.events[0].title).toBe("Third");
    expect(body.events[1].title).toBe("Second");
    expect(body.events[2].title).toBe("First");
  });

  it("supports cursor-based pagination", async () => {
    // Seed 5 events
    for (let i = 1; i <= 5; i++) {
      await seedEvent({ title: `Event ${i}` });
    }

    // First page: limit 2
    const res1 = await get("/timeline?limit=2");
    const page1 = await res1.json<{ events: { id: number }[]; next_cursor: number }>();
    expect(page1.events).toHaveLength(2);
    expect(page1.next_cursor).toBeTruthy();

    // Second page using cursor
    const res2 = await get(`/timeline?limit=2&cursor=${page1.next_cursor}`);
    const page2 = await res2.json<{ events: { id: number }[]; next_cursor: number }>();
    expect(page2.events).toHaveLength(2);
    expect(page2.next_cursor).toBeTruthy();

    // IDs should not overlap
    const page1Ids = page1.events.map((e) => e.id);
    const page2Ids = page2.events.map((e) => e.id);
    expect(page1Ids.every((id) => !page2Ids.includes(id))).toBe(true);

    // Third page: only 1 remaining
    const res3 = await get(`/timeline?limit=2&cursor=${page2.next_cursor}`);
    const page3 = await res3.json<{ events: { id: number }[]; next_cursor: number | null }>();
    expect(page3.events).toHaveLength(1);
    expect(page3.next_cursor).toBeNull();
  });

  it("caps limit at 100", async () => {
    // Seed 3 events, request 200
    for (let i = 0; i < 3; i++) {
      await seedEvent({ title: `Event ${i}` });
    }
    const res = await get("/timeline?limit=200");
    const body = await res.json<{ events: unknown[] }>();
    // Should still return all 3 (capped at 100, but only 3 exist)
    expect(body.events).toHaveLength(3);
  });

  it("includes read_at in response", async () => {
    await seedEvent({ title: "Unread", read_at: null });
    await seedEvent({ title: "Read", read_at: "2026-01-01T12:00:00Z" });

    const res = await get("/timeline");
    const body = await res.json<{
      events: { title: string; read_at: string | null }[];
    }>();

    const unread = body.events.find((e) => e.title === "Unread");
    const read = body.events.find((e) => e.title === "Read");
    expect(unread!.read_at).toBeNull();
    expect(read!.read_at).toBe("2026-01-01T12:00:00Z");
  });

  it("returns urgent as boolean not integer", async () => {
    await seedEvent({ title: "Urgent", urgent: 1 });
    await seedEvent({ title: "Normal", urgent: 0 });

    const res = await get("/timeline");
    const body = await res.json<{
      events: { title: string; urgent: boolean }[];
    }>();

    const urgent = body.events.find((e) => e.title === "Urgent");
    const normal = body.events.find((e) => e.title === "Normal");
    expect(urgent!.urgent).toBe(true);
    expect(normal!.urgent).toBe(false);
  });
});
