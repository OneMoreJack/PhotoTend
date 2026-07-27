import { describe, expect, it, vi } from "vitest";
import {
  createEmailWebhookProcessor,
  type EmailEventRepository,
  type WebhookVerifier,
} from "./webhook";

function repository(): EmailEventRepository {
  return {
    recordEvent: vi.fn().mockResolvedValue(true),
    suppressEntry: vi.fn().mockResolvedValue(undefined),
  };
}

const baseEvent = {
  type: "email.delivered",
  createdAt: "2026-07-26T00:00:00.000Z",
  emailId: "email-1",
  entryId: "entry-1",
};

describe("email webhook processor", () => {
  it("verifies the raw payload before recording a supported event", async () => {
    const repo = repository();
    const verifier: WebhookVerifier = {
      verify: vi.fn().mockReturnValue(baseEvent),
    };
    const processor = createEmailWebhookProcessor({
      verifier,
      repository: repo,
    });

    await expect(
      processor.process({
        rawBody: '{"type":"email.delivered"}',
        eventId: "event-1",
        timestamp: "123",
        signature: "signature",
      }),
    ).resolves.toEqual({ kind: "processed" });
    expect(verifier.verify).toHaveBeenCalledBefore(
      vi.mocked(repo.recordEvent),
    );
    expect(repo.recordEvent).toHaveBeenCalledWith({
      entryId: "entry-1",
      providerMessageId: "email-1",
      providerEventId: "event-1",
      eventType: "delivered",
      occurredAt: "2026-07-26T00:00:00.000Z",
    });
  });

  it("treats duplicate provider event ids as successful no-ops", async () => {
    const repo = repository();
    vi.mocked(repo.recordEvent).mockResolvedValue(false);
    const processor = createEmailWebhookProcessor({
      verifier: { verify: vi.fn().mockReturnValue(baseEvent) },
      repository: repo,
    });

    await expect(
      processor.process({
        rawBody: "{}",
        eventId: "event-1",
        timestamp: "123",
        signature: "signature",
      }),
    ).resolves.toEqual({ kind: "duplicate" });
  });

  it.each(["bounced", "complained", "suppressed"] as const)(
    "suppresses future email after a %s event",
    async (eventType) => {
      const repo = repository();
      const processor = createEmailWebhookProcessor({
        verifier: {
          verify: vi.fn().mockReturnValue({
            ...baseEvent,
            type: `email.${eventType}`,
          }),
        },
        repository: repo,
      });

      await processor.process({
        rawBody: "{}",
        eventId: `event-${eventType}`,
        timestamp: "123",
        signature: "signature",
      });

      expect(repo.suppressEntry).toHaveBeenCalledWith("entry-1");
    },
  );

  it("ignores unsupported verified event families", async () => {
    const repo = repository();
    const processor = createEmailWebhookProcessor({
      verifier: {
        verify: vi.fn().mockReturnValue({
          type: "contact.created",
          createdAt: "2026-07-26T00:00:00.000Z",
          emailId: null,
          entryId: null,
        }),
      },
      repository: repo,
    });

    await expect(
      processor.process({
        rawBody: "{}",
        eventId: "event-1",
        timestamp: "123",
        signature: "signature",
      }),
    ).resolves.toEqual({ kind: "ignored" });
    expect(repo.recordEvent).not.toHaveBeenCalled();
  });
});
