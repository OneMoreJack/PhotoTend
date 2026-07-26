import { DownloadEmail } from "@/emails/download-email";
import { WaitlistEmail } from "@/emails/waitlist-email";
import type { Platform } from "@/lib/database.types";
import type { ReactElement } from "react";

export type EmailMessage = {
  from: string;
  to: string;
  subject: string;
  react: ReactElement;
  text: string;
  idempotencyKey: string;
  tags: Array<{ name: string; value: string }>;
};

export type EmailSender = {
  send(message: EmailMessage): Promise<{ id: string }>;
};

export type GrantCreator = {
  createGrant(input: {
    waitlistEntryId: string;
    releaseId: string;
  }): Promise<{ token: string; expiresAt: string }>;
};

type ServiceOptions = {
  sender: EmailSender;
  grants: GrantCreator;
  siteUrl: string;
  from: string;
};

type CommonInput = {
  entryId: string;
  email: string;
  locale: "zh-CN" | "en";
  unsubscribeToken: string;
};

export function createEmailService({
  sender,
  grants,
  siteUrl,
  from,
}: ServiceOptions) {
  const baseUrl = siteUrl.replace(/\/$/, "");

  return {
    async sendDownload(
      input: CommonInput & {
        release: {
          id: string;
          platform: Platform;
          version: string;
        };
      },
    ) {
      const grant = await grants.createGrant({
        waitlistEntryId: input.entryId,
        releaseId: input.release.id,
      });
      const downloadUrl = `${baseUrl}/download/${grant.token}?locale=${input.locale}`;
      const unsubscribeUrl = `${baseUrl}/${input.locale}/unsubscribe/${input.unsubscribeToken}`;
      const expiryDay = grant.expiresAt.slice(0, 10);
      return sender.send({
        from,
        to: input.email,
        subject:
          input.locale === "zh-CN"
            ? "你的 PhotoTend 体验版已准备好"
            : "Your PhotoTend preview is ready",
        react: (
          <DownloadEmail
            locale={input.locale}
            platform={input.release.platform}
            version={input.release.version}
            downloadUrl={downloadUrl}
            expiresAt={grant.expiresAt}
            unsubscribeUrl={unsubscribeUrl}
          />
        ),
        text:
          input.locale === "zh-CN"
            ? `下载 ${input.release.platform} ${input.release.version}：${downloadUrl}`
            : `Download ${input.release.platform} ${input.release.version}: ${downloadUrl}`,
        idempotencyKey: `download-${input.entryId}-${input.release.id}-${expiryDay}`,
        tags: [{ name: "entry_id", value: input.entryId }],
      });
    },

    async sendWaiting(
      input: CommonInput & {
        platform: Platform;
      },
    ) {
      const unsubscribeUrl = `${baseUrl}/${input.locale}/unsubscribe/${input.unsubscribeToken}`;
      const day = new Date().toISOString().slice(0, 10);
      return sender.send({
        from,
        to: input.email,
        subject:
          input.locale === "zh-CN"
            ? "你已加入 PhotoTend 体验名单"
            : "You’re on the PhotoTend preview list",
        react: (
          <WaitlistEmail
            locale={input.locale}
            platform={input.platform}
            unsubscribeUrl={unsubscribeUrl}
          />
        ),
        text:
          input.locale === "zh-CN"
            ? "已加入 PhotoTend 体验名单。版本开放后，我们会第一时间通知你。"
            : "You’re on the PhotoTend preview list. We’ll let you know when it opens.",
        idempotencyKey: `waiting-${input.entryId}-${input.platform}-${day}`,
        tags: [{ name: "entry_id", value: input.entryId }],
      });
    },
  };
}
