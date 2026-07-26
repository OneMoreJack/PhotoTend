import { isLocale } from "@/i18n/config";
import Link from "next/link";
import { notFound } from "next/navigation";

type Props = {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ reason?: string }>;
};

export default async function DownloadErrorPage({
  params,
  searchParams,
}: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) {
    notFound();
  }
  const { reason } = await searchParams;
  const expired = reason === "expired";

  return (
    <main>
      <h1>
        {locale === "zh-CN"
          ? expired
            ? "下载链接已过期"
            : "这个下载链接暂时不可用"
          : expired
            ? "This download link has expired"
            : "This download link is not available"}
      </h1>
      <p>
        {locale === "zh-CN"
          ? "重新留下邮箱，我们会为你准备新的下载方式。"
          : "Leave your email again and we will prepare a new download path."}
      </p>
      <Link href={`/${locale}#waitlist`}>
        {locale === "zh-CN" ? "重新获取体验版" : "Get a new link"}
      </Link>
    </main>
  );
}
