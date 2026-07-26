import { isLocale } from "@/i18n/config";
import { notFound } from "next/navigation";

type Props = { params: Promise<{ locale: string }> };

export default async function DataRequestPage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) {
    notFound();
  }
  const chinese = locale === "zh-CN";
  const supportEmail =
    process.env.SUPPORT_EMAIL ?? "hello@phototend.onemorejack.top";
  const subject = encodeURIComponent(
    chinese ? "PhotoTend 数据请求" : "PhotoTend data request",
  );

  return (
    <main className="legal-page">
      <h1>{chinese ? "数据请求" : "Data request"}</h1>
      <p>
        {chinese
          ? "你可以申请查询或删除与 Waitlist 邮箱相关的数据。为保护你的信息，请使用加入名单时的邮箱发送请求。"
          : "You can request access to or deletion of data associated with your waitlist email. To protect your information, send the request from the address used to join."}
      </p>
      <a className="button" href={`mailto:${supportEmail}?subject=${subject}`}>
        {chinese ? "发送数据请求" : "Send a data request"}
      </a>
    </main>
  );
}
