import { describe, expect, it, vi } from "vitest";
import { createWaitlistDeliveryService } from "./delivery";

const input = {
  email: "user@example.com",
  platform: "android",
  locale: "zh-CN",
  source: "footer",
  consent: true,
  website: "",
} as const;

describe("waitlist delivery", () => {
  it("saves first, then sends an update subscription confirmation", async () => {
    const join = vi.fn().mockResolvedValue({
      kind: "download-ready",
      entryId: "entry-1",
      release: {
        id: "release-1",
        platform: "android",
        version: "1.0.0",
        storagePath: "private.apk",
      },
    });
    const issue = vi.fn().mockResolvedValue("unsubscribe-token");
    const sendDownload = vi.fn().mockResolvedValue({ id: "email-1" });
    const sendWaiting = vi.fn().mockResolvedValue({ id: "email-1" });
    const delivery = createWaitlistDeliveryService({
      waitlist: { join },
      unsubscribe: { issue },
      email: { sendDownload, sendWaiting },
    });

    await expect(delivery.join(input)).resolves.toMatchObject({
      kind: "waiting",
    });
    expect(join).toHaveBeenCalledBefore(issue);
    expect(issue).toHaveBeenCalledBefore(sendWaiting);
    expect(sendWaiting).toHaveBeenCalledWith(
      expect.objectContaining({
        email: "user@example.com",
        unsubscribeToken: "unsubscribe-token",
      }),
    );
    expect(sendDownload).not.toHaveBeenCalled();
  });

  it("preserves the saved entry when email delivery fails", async () => {
    const join = vi.fn().mockResolvedValue({
      kind: "waiting",
      entryId: "entry-1",
    });
    const delivery = createWaitlistDeliveryService({
      waitlist: { join },
      unsubscribe: { issue: vi.fn().mockResolvedValue("token") },
      email: {
        sendDownload: vi.fn(),
        sendWaiting: vi.fn().mockRejectedValue(new Error("email failed")),
      },
    });

    await expect(delivery.join(input)).rejects.toThrow("email failed");
    expect(join).toHaveBeenCalledOnce();
  });
});
