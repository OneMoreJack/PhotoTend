import type { Platform } from "@/lib/database.types";

type Props = {
  locale: "zh-CN" | "en";
  platform: Platform;
  version: string;
  downloadUrl: string;
  expiresAt: string;
  unsubscribeUrl: string;
};

const platformNames: Record<Platform, string> = {
  android: "Android",
  macos: "macOS",
  ios: "iPhone",
};

const styles = {
  body: {
    margin: 0,
    padding: "32px 16px",
    background: "#F4F0E8",
    color: "#171A1C",
    fontFamily: "-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif",
  },
  card: {
    maxWidth: "560px",
    margin: "0 auto",
    padding: "36px",
    background: "#FFFCF6",
    borderRadius: "16px",
  },
  button: {
    display: "inline-block",
    margin: "20px 0",
    padding: "14px 20px",
    background: "#B55A30",
    borderRadius: "8px",
    color: "#FFFCF6",
    fontWeight: 800,
    textDecoration: "none",
  },
  muted: { color: "#756F66", fontSize: "13px", lineHeight: 1.6 },
} as const;

export function DownloadEmail({
  locale,
  platform,
  version,
  downloadUrl,
  expiresAt,
  unsubscribeUrl,
}: Props) {
  const chinese = locale === "zh-CN";
  const platformName = platformNames[platform];
  const expiry = expiresAt.slice(0, 10);

  return (
    <html lang={locale}>
      <body style={styles.body}>
        <main style={styles.card}>
          <p style={{ color: "#B55A30", fontWeight: 800 }}>PhotoTend</p>
          <h1>
            {chinese
              ? "你的 PhotoTend 体验版已准备好"
              : "Your PhotoTend preview is ready"}
          </h1>
          <p>
            {chinese
              ? `${platformName} ${version} 已经为你准备好。`
              : `${platformName} ${version} is ready for you.`}
          </p>
          <a href={downloadUrl} style={styles.button}>
            {chinese ? `下载 ${platformName} 体验版` : `Download for ${platformName}`}
          </a>
          <p style={styles.muted}>
            {chinese
              ? `下载链接有效至 ${expiry}。请勿转发此链接。`
              : `This private link expires on ${expiry}. Please do not forward it.`}
          </p>
          <p style={styles.muted}>
            {chinese
              ? "PhotoTend 仍处于体验阶段，安装前请保留重要照片的备份。"
              : "PhotoTend is still in preview. Keep a backup of important photos before installing."}
          </p>
          <a href={unsubscribeUrl} style={styles.muted}>
            {chinese ? "退订产品邮件" : "Unsubscribe from product email"}
          </a>
        </main>
      </body>
    </html>
  );
}
