import "server-only";

import { Resend } from "resend";
import type { EmailSender } from "./service";

export function createResendEmailSender(apiKey: string): EmailSender {
  const resend = new Resend(apiKey);

  return {
    async send({ idempotencyKey, ...message }) {
      const { data, error } = await resend.emails.send(message, {
        idempotencyKey,
      });
      if (error || !data) {
        throw new Error("Unable to submit email for delivery", {
          cause: error ?? undefined,
        });
      }
      return { id: data.id };
    },
  };
}
