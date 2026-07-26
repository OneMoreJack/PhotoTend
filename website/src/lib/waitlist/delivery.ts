import type { Platform } from "@/lib/database.types";
import { waitlistInputSchema } from "./schema";
import type { WaitlistResult } from "./service";

type Waitlist = {
  join(input: unknown): Promise<WaitlistResult>;
};

type UnsubscribeIssuer = {
  issue(entryId: string): Promise<string>;
};

type EmailDelivery = {
  sendDownload(input: {
    entryId: string;
    email: string;
    locale: "zh-CN" | "en";
    release: {
      id: string;
      platform: Platform;
      version: string;
    };
    unsubscribeToken: string;
  }): Promise<unknown>;
  sendWaiting(input: {
    entryId: string;
    email: string;
    locale: "zh-CN" | "en";
    platform: Platform;
    unsubscribeToken: string;
  }): Promise<unknown>;
};

export function createWaitlistDeliveryService({
  waitlist,
  unsubscribe,
  email,
}: {
  waitlist: Waitlist;
  unsubscribe: UnsubscribeIssuer;
  email: EmailDelivery;
}) {
  return {
    async join(input: unknown) {
      const parsed = waitlistInputSchema.parse(input);
      const result = await waitlist.join(parsed);
      const unsubscribeToken = await unsubscribe.issue(result.entryId);

      if (result.kind === "download-ready") {
        await email.sendDownload({
          entryId: result.entryId,
          email: parsed.email,
          locale: parsed.locale,
          release: {
            id: result.release.id,
            platform: result.release.platform,
            version: result.release.version,
          },
          unsubscribeToken,
        });
      } else {
        await email.sendWaiting({
          entryId: result.entryId,
          email: parsed.email,
          locale: parsed.locale,
          platform: parsed.platform,
          unsubscribeToken,
        });
      }

      return result;
    },
  };
}
