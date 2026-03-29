import { describe, it, expect, beforeEach, vi } from "vitest";
import { env } from "cloudflare:test";
import { applySchema, clearEvents, seedEvent } from "./helpers";
import { handleCron } from "../src/cron";
import type { EventRow } from "../src/types";

// Mock fetch to intercept Pushover calls
const originalFetch = globalThis.fetch;

function mockPushover() {
  const calls: { body: string }[] = [];
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input.toString();
    if (url.includes("pushover.net")) {
      calls.push({ body: init?.body as string });
      return new Response(JSON.stringify({ status: 1 }), { status: 200 });
    }
    return originalFetch(input, init);
  };
  return calls;
}

function restoreFetch() {
  globalThis.fetch = originalFetch;
}

describe("Cron batch handler", () => {
  beforeEach(async () => {
    await applySchema();
    await clearEvents();
    restoreFetch();
  });

  it("sends digest for unpushed events", async () => {
    await seedEvent({ title: "Event A", source: "github", pushed: 0 });
    await seedEvent({ title: "Event B", source: "github", pushed: 0 });

    const calls = mockPushover();
    await handleCron(env as any);

    expect(calls).toHaveLength(1);
    expect(calls[0].body).toContain("github");

    // Events should now be marked as pushed
    const { results } = await env.DB.prepare(
      "SELECT pushed FROM events"
    ).all<EventRow>();
    expect(results.every((r) => r.pushed === 1)).toBe(true);
  });

  it("skips when no unpushed events exist", async () => {
    await seedEvent({ title: "Already pushed", pushed: 1 });

    const calls = mockPushover();
    await handleCron(env as any);

    expect(calls).toHaveLength(0);
  });

  it("does not re-send already pushed events", async () => {
    await seedEvent({ title: "Pushed", pushed: 1 });
    await seedEvent({ title: "New", pushed: 0 });

    const calls = mockPushover();
    await handleCron(env as any);

    expect(calls).toHaveLength(1);
    // Only 1 event in the digest
    expect(calls[0].body).toContain("1+new+event");
  });

  it("groups events by source in digest", async () => {
    await seedEvent({ title: "GH Event", source: "github", pushed: 0 });
    await seedEvent({ title: "AWS Event", source: "aws", pushed: 0 });

    const calls = mockPushover();
    await handleCron(env as any);

    expect(calls).toHaveLength(1);
    const body = decodeURIComponent(calls[0].body);
    expect(body).toContain("[github]");
    expect(body).toContain("[aws]");
  });

  it("respects quiet hours", async () => {
    await seedEvent({ title: "Event", pushed: 0 });

    // Set quiet hours to cover all 24 hours
    const quietEnv = {
      ...env,
      QUIET_START: "0",
      QUIET_END: "0",
      TZ_OFFSET: "0",
    } as any;

    // With start=0 and end=0, start > end is false, and localHour >= 0 && localHour < 0 is false
    // So this won't actually be quiet. Let me use a range that covers current hour.
    const now = new Date();
    const currentHour = now.getUTCHours();
    const quietStart = currentHour;
    const quietEnd = (currentHour + 2) % 24;

    const quietEnv2 = {
      ...env,
      QUIET_START: String(quietStart),
      QUIET_END: String(quietEnd),
      TZ_OFFSET: "0",
    } as any;

    const calls = mockPushover();
    await handleCron(quietEnv2);

    expect(calls).toHaveLength(0);

    // Event should still be unpushed
    const row = await env.DB.prepare("SELECT pushed FROM events").first();
    expect(row!.pushed).toBe(0);
  });

  it("sends during non-quiet hours", async () => {
    await seedEvent({ title: "Event", pushed: 0 });

    // Set quiet hours to a window that doesn't include current hour
    const now = new Date();
    const currentHour = now.getUTCHours();
    const quietStart = (currentHour + 12) % 24;
    const quietEnd = (currentHour + 14) % 24;

    const nonQuietEnv = {
      ...env,
      QUIET_START: String(quietStart),
      QUIET_END: String(quietEnd),
      TZ_OFFSET: "0",
    } as any;

    const calls = mockPushover();
    await handleCron(nonQuietEnv);

    expect(calls).toHaveLength(1);
  });
});
