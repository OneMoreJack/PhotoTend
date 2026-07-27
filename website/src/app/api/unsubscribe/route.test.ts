import { describe, expect, it, vi } from "vitest";
import { createUnsubscribeHandler } from "./route";

function request(body: unknown) {
  return new Request(
    "https://phototend.onemorejack.top/api/unsubscribe",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://phototend.onemorejack.top",
      },
      body: JSON.stringify(body),
    },
  );
}

describe("unsubscribe route", () => {
  it("returns the same success result for first and repeat requests", async () => {
    const unsubscribe = vi.fn().mockResolvedValue(true);
    const first = await createUnsubscribeHandler({ unsubscribe })(
      request({ token: "valid-token-that-is-long-enough-for-production-use" }),
    );
    expect(first.status).toBe(200);
    await expect(first.json()).resolves.toEqual({ result: "unsubscribed" });

    unsubscribe.mockResolvedValue(false);
    const repeat = await createUnsubscribeHandler({ unsubscribe })(
      request({ token: "valid-token-that-is-long-enough-for-production-use" }),
    );
    expect(repeat.status).toBe(200);
    await expect(repeat.json()).resolves.toEqual({ result: "unsubscribed" });
  });

  it("rejects malformed tokens without calling persistence", async () => {
    const unsubscribe = vi.fn();
    const response = await createUnsubscribeHandler({ unsubscribe })(
      request({ token: "x" }),
    );

    expect(response.status).toBe(400);
    expect(unsubscribe).not.toHaveBeenCalled();
  });
});
