import { describe, expect, it } from "vitest";
import {
  createRequestFingerprint,
  getRequestSource,
} from "./request-fingerprint";

describe("request fingerprints", () => {
  it("creates a stable keyed digest without exposing the source", () => {
    const first = createRequestFingerprint("203.0.113.8", "test-secret");
    const second = createRequestFingerprint("203.0.113.8", "test-secret");

    expect(first).toBe(second);
    expect(first).toMatch(/^[a-f0-9]{64}$/);
    expect(first).not.toContain("203.0.113.8");
  });

  it("prefers the Vercel source header and accepts the first forwarded value", () => {
    expect(
      getRequestSource(
        new Headers({
          "x-vercel-forwarded-for": "203.0.113.8",
          "x-forwarded-for": "198.51.100.2",
        }),
      ),
    ).toBe("203.0.113.8");

    expect(
      getRequestSource(
        new Headers({
          "x-forwarded-for": "198.51.100.2, 10.0.0.1",
        }),
      ),
    ).toBe("198.51.100.2");
  });

  it("uses a neutral value for missing or malformed forwarding headers", () => {
    expect(getRequestSource(new Headers())).toBe("unknown");
    expect(
      getRequestSource(
        new Headers({ "x-forwarded-for": "not-an-ip" }),
      ),
    ).toBe("unknown");
  });
});
