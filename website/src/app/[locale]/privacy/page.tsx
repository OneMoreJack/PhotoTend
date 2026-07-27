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
          ? "更新日期：2026 年 7 月 27 日"
          : "Last updated: July 27, 2026"}
      </p>

      <section>
        <h2>{chinese ? "宣传网站" : "Marketing website"}</h2>
        <p>
          {chinese
            ? "PhotoTend 宣传网站不要求注册，不收集邮箱，也不设置用户数据库。Android 安装包由 GitHub Releases 直接提供。"
            : "The PhotoTend marketing site requires no account, collects no email address, and has no user database. Android packages are served directly by GitHub Releases."}
        </p>
      </section>

      <section>
        <h2>{chinese ? "照片与视频" : "Photos and videos"}</h2>
        <p>
          {chinese
            ? "宣传网站无法访问你的相册。Android 应用的照片整理与导入发生在你的设备上；具体权限由 Android 系统管理。"
            : "The marketing site cannot access your library. Photo organization and import happen on your Android device, with permissions managed by Android."}
        </p>
      </section>

      <section>
        <h2>{chinese ? "托管服务" : "Hosting providers"}</h2>
        <p>
          {chinese
            ? "宣传网站由 Vercel 托管，源代码与安装包由 GitHub 托管。访问这些服务时，它们可能按各自隐私政策处理常规网络日志。"
            : "Vercel hosts the marketing site, while GitHub hosts the source and packages. These providers may process standard web logs under their own privacy policies."}
        </p>
      </section>

      <section>
        <h2>{chinese ? "联系我们" : "Contact"}</h2>
        <p>
          <a href="mailto:hello@phototend.onemorejack.top">
            hello@phototend.onemorejack.top
          </a>
        </p>
      </section>
    </main>
  );
}
