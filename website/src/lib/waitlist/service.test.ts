import { describe, expect, it, vi } from "vitest";
import {
  createWaitlistService,
  type WaitlistRepository,
} from "./service";

function repository(
  overrides: Partial<WaitlistRepository> = {},
): WaitlistRepository {
  return {
    saveEntry: vi.fn().mockResolvedValue({ id: "entry-1" }),
    findActiveRelease: vi.fn().mockResolvedValue(null),
    ...overrides,
  };
}

const validInput = {
  email: "  User@Example.COM ",
  platform: "android",
  locale: "zh-CN",
  source: "hero",
  consent: true,
  website: "",
} as const;

describe("waitlist service", () => {
  it("normalizes email before persisting a valid entry", async () => {
    const repo = repository();
    const service = createWaitlistService(repo);

    await service.join(validInput);

    expect(repo.saveEntry).toHaveBeenCalledWith(
      expect.objectContaining({ email: "user@example.com" }),
    );
  });

  it("rejects malformed or oversized public fields", async () => {
    const service = createWaitlistService(repository());

    await expect(
      service.join({ ...validInput, email: "not-an-email" }),
    ).rejects.toMatchObject({ name: "WaitlistValidationError" });
    await expect(
      service.join({ ...validInput, source: "x".repeat(65) }),
    ).rejects.toMatchObject({ name: "WaitlistValidationError" });
    await expect(
      service.join({ ...validInput, platform: "windows" }),
    ).rejects.toMatchObject({ name: "WaitlistValidationError" });
  });

  it("silently rejects a filled honeypot before persistence", async () => {
    const repo = repository();
    const service = createWaitlistService(repo);

    await expect(
      service.join({ ...validInput, website: "https://bot.invalid" }),
    ).rejects.toMatchObject({ name: "WaitlistAbuseError" });
    expect(repo.saveEntry).not.toHaveBeenCalled();
  });

  it("returns a waiting result when no release is active", async () => {
    const service = createWaitlistService(repository());

    await expect(service.join(validInput)).resolves.toEqual({
      kind: "waiting",
      entryId: "entry-1",
    });
  });

  it("returns release details when the selected platform is active", async () => {
    const repo = repository({
      findActiveRelease: vi.fn().mockResolvedValue({
        id: "release-1",
        platform: "android",
        version: "1.0.0",
        storagePath: "android/phototend-1.0.0.apk",
      }),
    });
    const service = createWaitlistService(repo);

    await expect(service.join(validInput)).resolves.toEqual({
      kind: "download-ready",
      entryId: "entry-1",
      release: {
        id: "release-1",
        platform: "android",
        version: "1.0.0",
        storagePath: "android/phototend-1.0.0.apk",
      },
    });
  });

  it("does not convert database failures into false success", async () => {
    const service = createWaitlistService(
      repository({
        saveEntry: vi.fn().mockRejectedValue(new Error("database offline")),
      }),
    );

    await expect(service.join(validInput)).rejects.toThrow("database offline");
  });
});
