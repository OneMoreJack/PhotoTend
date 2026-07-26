import type { Platform } from "@/lib/database.types";

type Props = {
  locale: "zh-CN" | "en";
  platform: Platform;
  unsubscribeUrl: string;
};

const platformNames: Record<Platform, { zh: string; en: string }> = {
  android: { zh: "Android", en: "Android" },
  macos: { zh: "macOS", en: "macOS" },
  ios: { zh: "iPhone", en: "iPhone" },
};

export function WaitlistEmail({ locale, platform, unsubscribeUrl }: Props) {
  const chinese = locale === "zh-CN";
  const platformName = chinese
    ? platformNames[platform].zh
    : platformNames[platform].en;

  return (
    <html lang={locale}>
      <body
        style={{
          margin: 0,
          padding: "32px 16px",
          background: "#F4F0E8",
          color: "#171A1C",
          fontFamily: "-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif",
        }}
      >
        <main
          style={{
            maxWidth: "560px",
            margin: "0 auto",
            padding: "36px",
            background: "#FFFCF6",
            borderRadius: "16px",
          }}
        >
          <p style={{ color: "#B55A30", fontWeight: 800 }}>PhotoTend</p>
          <h1>{chinese ? "已加入体验名单" : "You’re on the PhotoTend preview list"}</h1>
          <p>
            {chinese
              ? `${platformName} 体验版还在准备中，开放后我们会第一时间通知你。`
              : `We’ll let you know when the ${platformName} preview opens.`}
          </p>
          <p style={{ color: "#756F66", fontSize: "13px", lineHeight: 1.6 }}>
            {chinese
              ? "在此之前，我们不会发送无关邮件。"
              : "Until then, we won’t send unrelated email."}
          </p>
          <a
            href={unsubscribeUrl}
            style={{ color: "#756F66", fontSize: "13px" }}
          >
            {chinese ? "退出体验名单" : "Leave the preview list"}
          </a>
        </main>
      </body>
    </html>
  );
}
