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
          ? "Android 安装包可能正在更新，请稍后直接重试；下载不需要提供邮箱。"
          : "The Android package may be updating. Try the direct download again shortly—no email is required."}
      </p>
      <Link href={`/api/download/android?locale=${locale}`}>
        {locale === "zh-CN" ? "重新下载 Android 版" : "Retry Android download"}
      </Link>
    </main>
  );
}
