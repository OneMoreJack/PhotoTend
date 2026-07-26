import { describe, expect, it, vi } from "vitest";
import { createWaitlistHandler } from "./route";

const requestBody = {
  email: "user@example.com",
  platform: "android",
  locale: "zh-CN",
  source: "hero",
  consent: true,
  website: "",
};

function request(body: unknown = requestBody, headers: HeadersInit = {}) {
  return new Request("https://phototend.onemorejack.top/api/waitlist", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      origin: "https://phototend.onemorejack.top",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

describe("waitlist route", () => {
  it("returns a localized waiting result without caching", async () => {
    const join = vi.fn().mockResolvedValue({
      kind: "waiting",
      entryId: "entry-1",
    });
    const response = await createWaitlistHandler({ join })(request());

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({ result: "waiting" });
  });

  it("returns download-ready without exposing internal identifiers", async () => {
    const join = vi.fn().mockResolvedValue({
      kind: "download-ready",
      entryId: "entry-1",
      release: {
        id: "release-1",
        platform: "android",
        version: "1.0.0",
        storagePath: "private/path.apk",
      },
    });
    const response = await createWaitlistHandler({ join })(request());

    await expect(response.json()).resolves.toEqual({
      result: "download-ready",
    });
  });

  it("rejects non-JSON and foreign-origin requests", async () => {
    const join = vi.fn();
    const handler = createWaitlistHandler({ join });

    const nonJson = await handler(
      request(requestBody, { "content-type": "text/plain" }),
    );
    expect(nonJson.status).toBe(415);

    const foreign = await handler(
      request(requestBody, { origin: "https://attacker.invalid" }),
    );
    expect(foreign.status).toBe(403);
    expect(join).not.toHaveBeenCalled();
  });

  it("uses a safe response for invalid input", async () => {
    const error = new Error("invalid");
    error.name = "WaitlistValidationError";
    const response = await createWaitlistHandler({
      join: vi.fn().mockRejectedValue(error),
    })(request());

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({
      result: "invalid-input",
    });
  });

  it("uses a retryable response for provider failures", async () => {
    const response = await createWaitlistHandler({
      join: vi.fn().mockRejectedValue(new Error("database offline")),
    })(request());

    expect(response.status).toBe(503);
    await expect(response.json()).resolves.toEqual({
      result: "try-again",
    });
  });
});
