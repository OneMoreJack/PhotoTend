import { describe, expect, it } from "vitest";
import { createMemoryRateLimiter } from "./rate-limit";

describe("waitlist rate limiting", () => {
  it("allows requests below both email and source limits", async () => {
    const limiter = createMemoryRateLimiter({
      emailLimit: 2,
      sourceLimit: 3,
      windowMs: 60_000,
      now: () => 1_000,
    });

    await expect(
      limiter.check({ emailHash: "email-a", sourceHash: "source-a" }),
    ).resolves.toEqual({ allowed: true });
  });

  it("blocks an email during its cooldown window", async () => {
    const limiter = createMemoryRateLimiter({
      emailLimit: 1,
      sourceLimit: 10,
      windowMs: 60_000,
      now: () => 1_000,
    });

    await limiter.check({ emailHash: "email-a", sourceHash: "source-a" });

    await expect(
      limiter.check({ emailHash: "email-a", sourceHash: "source-b" }),
    ).resolves.toEqual({ allowed: false });
  });

  it("blocks a request source independently of email", async () => {
    const limiter = createMemoryRateLimiter({
      emailLimit: 10,
      sourceLimit: 1,
      windowMs: 60_000,
      now: () => 1_000,
    });

    await limiter.check({ emailHash: "email-a", sourceHash: "source-a" });

    await expect(
      limiter.check({ emailHash: "email-b", sourceHash: "source-a" }),
    ).resolves.toEqual({ allowed: false });
  });

  it("forgets expired attempts", async () => {
    let now = 1_000;
    const limiter = createMemoryRateLimiter({
      emailLimit: 1,
      sourceLimit: 1,
      windowMs: 60_000,
      now: () => now,
    });

    await limiter.check({ emailHash: "email-a", sourceHash: "source-a" });
    now += 60_001;

    await expect(
      limiter.check({ emailHash: "email-a", sourceHash: "source-a" }),
    ).resolves.toEqual({ allowed: true });
  });
});
