export type VerifiedWebhookEvent = {
  type: string;
  createdAt: string;
  emailId: string | null;
  entryId: string | null;
};

export type WebhookVerifier = {
  verify(input: {
    rawBody: string;
    eventId: string;
    timestamp: string;
    signature: string;
  }): VerifiedWebhookEvent;
};

type StoredEventType =
  | "sent"
  | "delivered"
  | "delivery_delayed"
  | "failed"
  | "bounced"
  | "complained"
  | "clicked"
  | "suppressed";

export type EmailEventRepository = {
  recordEvent(input: {
    entryId: string | null;
    providerMessageId: string | null;
    providerEventId: string;
    eventType: StoredEventType;
    occurredAt: string;
  }): Promise<boolean>;
  suppressEntry(entryId: string): Promise<void>;
};

const supportedEvents = new Map<string, StoredEventType>([
  ["email.sent", "sent"],
  ["email.delivered", "delivered"],
  ["email.delivery_delayed", "delivery_delayed"],
  ["email.failed", "failed"],
  ["email.bounced", "bounced"],
  ["email.complained", "complained"],
  ["email.clicked", "clicked"],
  ["email.suppressed", "suppressed"],
]);

const suppressingEvents = new Set<StoredEventType>([
  "bounced",
  "complained",
  "suppressed",
]);

export function createEmailWebhookProcessor({
  verifier,
  repository,
}: {
  verifier: WebhookVerifier;
  repository: EmailEventRepository;
}) {
  return {
    async process(input: {
      rawBody: string;
      eventId: string;
      timestamp: string;
      signature: string;
    }) {
      const verified = verifier.verify(input);
      const eventType = supportedEvents.get(verified.type);
      if (!eventType) {
        return { kind: "ignored" as const };
      }

      const inserted = await repository.recordEvent({
        entryId: verified.entryId,
        providerMessageId: verified.emailId,
        providerEventId: input.eventId,
        eventType,
        occurredAt: verified.createdAt,
      });
      if (!inserted) {
        return { kind: "duplicate" as const };
      }

      if (verified.entryId && suppressingEvents.has(eventType)) {
        await repository.suppressEntry(verified.entryId);
      }

      return { kind: "processed" as const };
    },
  };
}
