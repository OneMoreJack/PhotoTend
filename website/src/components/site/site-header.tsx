import { BrandLockup } from "@/components/brand/brand-lockup";
import { LocaleSwitcher } from "@/components/locale-switcher";
import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import Link from "next/link";
import { androidDownloadUrl, githubRepositoryUrl } from "@/lib/links";

export function SiteHeader({ locale }: { locale: Locale }) {
  const { nav } = getMessages(locale);

  return (
    <header className="site-header">
      <div className="site-header__inner">
        <BrandLockup locale={locale} />
        <nav className="site-nav" aria-label={locale === "zh-CN" ? "主导航" : "Main navigation"}>
          <Link href={`/${locale}#why`}>{nav.why}</Link>
          <Link href={`/${locale}#workflow`}>{nav.workflow}</Link>
          <Link href={`/${locale}#platforms`}>{nav.platforms}</Link>
          <a href={githubRepositoryUrl}>{nav.github}</a>
        </nav>
        <div className="site-header__actions">
          <LocaleSwitcher locale={locale} />
          <Link
            className="button button--compact"
            href={androidDownloadUrl}
          >
            {nav.join}
          </Link>
        </div>
      </div>
    </header>
  );
}
