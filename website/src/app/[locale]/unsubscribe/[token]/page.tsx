import { UnsubscribeForm } from "@/components/unsubscribe/unsubscribe-form";
import { isLocale } from "@/i18n/config";
import { notFound } from "next/navigation";

type Props = {
  params: Promise<{ locale: string; token: string }>;
};

export default async function UnsubscribePage({ params }: Props) {
  const { locale, token } = await params;
  if (!isLocale(locale) || token.length < 32 || token.length > 256) {
    notFound();
  }

  return (
    <main>
      <h1>{locale === "zh-CN" ? "退订 PhotoTend 邮件" : "Unsubscribe from PhotoTend"}</h1>
      <p>
        {locale === "zh-CN"
          ? "退订后，我们将停止发送测试邀请和版本通知。"
          : "We’ll stop sending preview invitations and release updates."}
      </p>
      <UnsubscribeForm locale={locale} token={token} />
    </main>
  );
}
