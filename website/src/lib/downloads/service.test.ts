import { describe, expect, it, vi } from "vitest";
import {
  createDownloadService,
  type DownloadRepository,
  type ReleaseSigner,
} from "./service";
import { createDownloadToken, hashDownloadToken } from "./token";

const secret = "test-download-secret-with-more-than-32-bytes";

function repository(
  overrides: Partial<DownloadRepository> = {},
): DownloadRepository {
  return {
    createGrant: vi.fn().mockResolvedValue(undefined),
    findGrantByTokenHash: vi.fn().mockResolvedValue(null),
    recordEvent: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  };
}

const activeGrant = {
  id: "grant-1",
  expiresAt: new Date(Date.now() + 60_000).toISOString(),
  revokedAt: null,
  release: {
    id: "release-1",
    status: "active" as const,
    storagePath: "android/phototend-1.0.0.apk",
  },
};

describe("download tokens", () => {
  it("generates an opaque token and stores only a stable keyed hash", () => {
    const token = createDownloadToken();
    const hash = hashDownloadToken(token, secret);

    expect(token.length).toBeGreaterThanOrEqual(43);
    expect(hash).toMatch(/^[a-f0-9]{64}$/);
    expect(hash).not.toContain(token);
    expect(hashDownloadToken(token, secret)).toBe(hash);
  });
});

describe("download service", () => {
  it("creates an expiring grant without returning the hash", async () => {
    const repo = repository();
    const service = createDownloadService({
      repository: repo,
      signer: { sign: vi.fn() },
      tokenSecret: secret,
      now: () => new Date("2026-07-26T00:00:00.000Z"),
    });

    const grant = await service.createGrant({
      waitlistEntryId: "entry-1",
      releaseId: "release-1",
    });

    expect(grant.token).toBeTruthy();
    expect(grant.expiresAt).toBe("2026-08-02T00:00:00.000Z");
    expect(repo.createGrant).toHaveBeenCalledWith({
      waitlistEntryId: "entry-1",
      releaseId: "release-1",
      tokenHash: hashDownloadToken(grant.token, secret),
      expiresAt: grant.expiresAt,
    });
  });

  it("authorizes an active grant and records the redirect", async () => {
    const repo = repository({
      findGrantByTokenHash: vi.fn().mockResolvedValue(activeGrant),
    });
    const signer: ReleaseSigner = {
      sign: vi.fn().mockResolvedValue("https://signed.example/file.apk"),
    };
    const service = createDownloadService({
      repository: repo,
      signer,
      tokenSecret: secret,
    });

    await expect(service.authorize("raw-token")).resolves.toEqual({
      kind: "redirect",
      url: "https://signed.example/file.apk",
    });
    expect(signer.sign).toHaveBeenCalledWith(
      "android/phototend-1.0.0.apk",
      300,
    );
    expect(repo.recordEvent).toHaveBeenCalledWith("grant-1", "redirected");
  });

  it.each([
    {
      name: "expired",
      grant: { ...activeGrant, expiresAt: "2020-01-01T00:00:00.000Z" },
      result: "expired",
    },
    {
      name: "revoked",
      grant: { ...activeGrant, revokedAt: "2026-07-26T00:00:00.000Z" },
      result: "revoked",
    },
    {
      name: "retired release",
      grant: {
        ...activeGrant,
        release: { ...activeGrant.release, status: "retired" as const },
      },
      result: "unavailable",
    },
  ])("rejects a $name grant", async ({ grant, result }) => {
    const repo = repository({
      findGrantByTokenHash: vi.fn().mockResolvedValue(grant),
    });
    const service = createDownloadService({
      repository: repo,
      signer: { sign: vi.fn() },
      tokenSecret: secret,
    });

    await expect(service.authorize("raw-token")).resolves.toEqual({
      kind: "error",
      reason: result,
    });
  });

  it("rejects an unknown token without trying storage", async () => {
    const signer = { sign: vi.fn() };
    const service = createDownloadService({
      repository: repository(),
      signer,
      tokenSecret: secret,
    });

    await expect(service.authorize("unknown")).resolves.toEqual({
      kind: "error",
      reason: "invalid",
    });
    expect(signer.sign).not.toHaveBeenCalled();
  });
});
