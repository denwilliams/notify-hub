import { describe, it, expect, beforeEach } from "vitest";
import { applySchema, fetchNoAuth, get } from "./helpers";

describe("Auth middleware", () => {
  beforeEach(applySchema);

  it("rejects requests without x-api-key", async () => {
    const res = await fetchNoAuth("/timeline");
    expect(res.status).toBe(401);
    const body = await res.json<{ error: string }>();
    expect(body.error).toBe("Unauthorized");
  });

  it("rejects requests with wrong x-api-key", async () => {
    const { SELF } = await import("cloudflare:test");
    const res = await SELF.fetch("http://localhost/timeline", {
      headers: { "x-api-key": "wrong-key" },
    });
    expect(res.status).toBe(401);
  });

  it("allows requests with correct x-api-key", async () => {
    const res = await get("/timeline");
    expect(res.status).toBe(200);
  });
});
