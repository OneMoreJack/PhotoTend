import { isLocale } from "@/i18n/config";
import Link from "next/link";
import { notFound } from "next/navigation";

type Props = { params: Promise<{ locale: string }> };

export default async function PrivacyPage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) {
    notFound();
  }
  const chinese = locale === "zh-CN";

  return (
    <main className="legal-page">
      <Link href={`/${locale}`}>← {chinese ? "返回 PhotoTend" : "Back to PhotoTend"}</Link>
      <h1>{chinese ? "隐私说明" : "Privacy notice"}</h1>
      <p>
        {chinese
          ? "更新日期：2026 年 7 月 26 日"
          : "Last updated: July 26, 2026"}
      </p>

      <section>
        <h2>{chinese ? "我们收集什么" : "What we collect"}</h2>
        <p>
          {chinese
            ? "当你加入体验名单时，我们收集邮箱、所选平台、页面语言、提交时间和同意时间。为防止滥用，我们还会短期处理请求来源的不可逆摘要。"
            : "When you join the preview list, we collect your email, selected platform, page language, submission time, and consent time. To prevent abuse, we also process a short-lived irreversible request-source digest."}
        </p>
      </section>

      <section>
        <h2>{chinese ? "为什么使用这些数据" : "Why we use it"}</h2>
        <p>
          {chinese
            ? "这些数据只用于管理体验名单、发送下载方式和重要版本通知、处理退订、保护服务以及排查邮件和下载问题。"
            : "We use this data only to manage preview access, send download details and important release updates, process unsubscribe requests, protect the service, and troubleshoot email or download issues."}
        </p>
      </section>

      <section>
        <h2>{chinese ? "服务提供商与跨境处理" : "Providers and international processing"}</h2>
        <p>
          {chinese
            ? "宣传站使用 Vercel 托管，使用 Supabase 保存名单和私有安装包，使用 Resend 发送邮件。这些服务可能在你所在国家或地区之外处理数据。"
            : "The site is hosted by Vercel, uses Supabase for the list and private release files, and uses Resend for email. These providers may process data outside your country or region."}
        </p>
      </section>

      <section>
        <h2>{chinese ? "保存、退订与删除" : "Retention, unsubscribe, and deletion"}</h2>
        <p>
          {chinese
            ? "我们只在提供体验和履行上述用途所需的时间内保存数据。你可以使用每封邮件中的退订链接停止非必要邮件，也可以提交数据删除请求。为证明退订并避免再次发送，我们可能保留最少的抑制记录。"
            : "We retain data only as long as needed for preview access and the purposes above. You can stop non-essential email using the unsubscribe link in every message or submit a deletion request. We may retain a minimal suppression record to honor your opt-out."}
        </p>
      </section>

      <section>
        <h2>{chinese ? "联系我们" : "Contact"}</h2>
        <p>
          <Link href={`/${locale}/data-request`}>
            {chinese ? "提交数据访问或删除请求" : "Submit a data access or deletion request"}
          </Link>
        </p>
      </section>
    </main>
  );
}
