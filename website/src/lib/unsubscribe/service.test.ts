import { describe, expect, it, vi } from "vitest";
import {
  createUnsubscribeService,
  type UnsubscribeRepository,
} from "./service";
import { hashUnsubscribeToken } from "./token";

const secret = "test-unsubscribe-secret-with-more-than-32-bytes";

function repository(): UnsubscribeRepository {
  return {
    setTokenHash: vi.fn().mockResolvedValue(undefined),
    unsubscribeByTokenHash: vi.fn().mockResolvedValue(true),
  };
}

describe("unsubscribe service", () => {
  it("creates an opaque token while persisting only its hash", async () => {
    const repo = repository();
    const service = createUnsubscribeService({
      repository: repo,
      tokenSecret: secret,
    });

    const token = await service.issue("entry-1");

    expect(token.length).toBeGreaterThanOrEqual(43);
    expect(repo.setTokenHash).toHaveBeenCalledWith(
      "entry-1",
      hashUnsubscribeToken(token, secret),
    );
  });

  it("marks the matching entry unsubscribed and remains idempotent", async () => {
    const repo = repository();
    const service = createUnsubscribeService({
      repository: repo,
      tokenSecret: secret,
    });

    await expect(service.unsubscribe("raw-token")).resolves.toBe(true);
    expect(repo.unsubscribeByTokenHash).toHaveBeenCalledWith(
      hashUnsubscribeToken("raw-token", secret),
    );
  });
});
