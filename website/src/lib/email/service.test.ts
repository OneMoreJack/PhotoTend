import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import {
  createEmailService,
  type EmailSender,
  type GrantCreator,
} from "./service";

function sender(): EmailSender {
  return { send: vi.fn().mockResolvedValue({ id: "email-1" }) };
}

const grantCreator: GrantCreator = {
  createGrant: vi.fn().mockResolvedValue({
    token: "download-token",
    expiresAt: "2026-08-02T00:00:00.000Z",
  }),
};

describe("email service", () => {
  it("sends a localized download email with platform and expiration", async () => {
    const emailSender = sender();
    const service = createEmailService({
      sender: emailSender,
      grants: grantCreator,
      siteUrl: "https://phototend.onemorejack.top",
      from: "PhotoTend <hello@phototend.onemorejack.top>",
    });

    await service.sendDownload({
      entryId: "entry-1",
      email: "user@example.com",
      locale: "zh-CN",
      release: {
        id: "release-1",
        platform: "android",
        version: "1.0.0",
      },
      unsubscribeToken: "unsubscribe-token",
    });

    const message = vi.mocked(emailSender.send).mock.calls[0]![0];
    expect(message.subject).toBe("你的 PhotoTend 体验版已准备好");
    expect(message.idempotencyKey).toBe(
      "download-entry-1-release-1-2026-08-02",
    );
    const html = renderToStaticMarkup(message.react);
    expect(html).toContain("Android");
    expect(html).toContain("1.0.0");
    expect(html).toContain(
      "https://phototend.onemorejack.top/download/download-token?locale=zh-CN",
    );
    expect(html).toContain("2026-08-02");
    expect(html).toContain("/zh-CN/unsubscribe/unsubscribe-token");
  });

  it("sends an English waiting email without creating a download grant", async () => {
    const emailSender = sender();
    const grants: GrantCreator = { createGrant: vi.fn() };
    const service = createEmailService({
      sender: emailSender,
      grants,
      siteUrl: "https://phototend.onemorejack.top",
      from: "PhotoTend <hello@phototend.onemorejack.top>",
    });

    await service.sendWaiting({
      entryId: "entry-1",
      email: "user@example.com",
      locale: "en",
      platform: "ios",
      unsubscribeToken: "unsubscribe-token",
    });

    expect(grants.createGrant).not.toHaveBeenCalled();
    const message = vi.mocked(emailSender.send).mock.calls[0]![0];
    expect(message.subject).toBe("You’re on the PhotoTend preview list");
    expect(renderToStaticMarkup(message.react)).toContain(
      "We’ll let you know when the iPhone preview opens.",
    );
  });

  it("propagates delivery failures after the entry has already been saved", async () => {
    const emailSender: EmailSender = {
      send: vi.fn().mockRejectedValue(new Error("email provider unavailable")),
    };
    const service = createEmailService({
      sender: emailSender,
      grants: grantCreator,
      siteUrl: "https://phototend.onemorejack.top",
      from: "PhotoTend <hello@phototend.onemorejack.top>",
    });

    await expect(
      service.sendWaiting({
        entryId: "entry-1",
        email: "user@example.com",
        locale: "zh-CN",
        platform: "ios",
        unsubscribeToken: "unsubscribe-token",
      }),
    ).rejects.toThrow("email provider unavailable");
  });
});
