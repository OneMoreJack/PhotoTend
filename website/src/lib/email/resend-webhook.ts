import "server-only";

import { createSupabaseAdminClient } from "@/lib/supabase/server";
import { Resend } from "resend";
import type {
  EmailEventRepository,
  WebhookVerifier,
} from "./webhook";

export function createResendWebhookVerifier(
  webhookSecret: string,
): WebhookVerifier {
  const resend = new Resend();

  return {
    verify({ rawBody, eventId, timestamp, signature }) {
      const event = resend.webhooks.verify({
        payload: rawBody,
        headers: {
          id: eventId,
          timestamp,
          signature,
        },
        webhookSecret,
      });

      const data =
        "data" in event && typeof event.data === "object" ? event.data : null;
      const emailId =
        data && "email_id" in data && typeof data.email_id === "string"
          ? data.email_id
          : null;
      const tags =
        data && "tags" in data && typeof data.tags === "object"
          ? data.tags
          : null;
      const entryId =
        tags &&
        "entry_id" in tags &&
        typeof (tags as Record<string, unknown>).entry_id === "string"
          ? (tags as Record<string, string>).entry_id
          : null;

      return {
        type: event.type,
        createdAt: event.created_at,
        emailId,
        entryId,
      };
    },
  };
}

export function createSupabaseEmailEventRepository(): EmailEventRepository {
  const supabase = createSupabaseAdminClient();

  return {
    async recordEvent(input) {
      const { error } = await supabase.from("email_events").insert({
        waitlist_entry_id: input.entryId,
        provider_message_id: input.providerMessageId,
        provider_event_id: input.providerEventId,
        event_type: input.eventType,
        occurred_at: input.occurredAt,
      });
      if (error?.code === "23505") {
        return false;
      }
      if (error) {
        throw new Error("Unable to record email event", { cause: error });
      }
      return true;
    },

    async suppressEntry(entryId) {
      const { error } = await supabase
        .from("waitlist_entries")
        .update({
          status: "blocked",
          updated_at: new Date().toISOString(),
        })
        .eq("id", entryId);
      if (error) {
        throw new Error("Unable to suppress waitlist email", { cause: error });
      }
    },
  };
}
