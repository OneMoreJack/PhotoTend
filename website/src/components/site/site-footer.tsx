import { BrandLockup } from "@/components/brand/brand-lockup";
import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import Link from "next/link";
import { githubRepositoryUrl } from "@/lib/links";

export function SiteFooter({ locale }: { locale: Locale }) {
  const { footer } = getMessages(locale);
  return (
    <footer className="site-footer">
      <div>
        <BrandLockup locale={locale} />
        <p>{footer.tagline}</p>
      </div>
      <nav aria-label={locale === "zh-CN" ? "页脚导航" : "Footer navigation"}>
        <Link href={`/${locale}/privacy`}>{footer.privacy}</Link>
        <a href={githubRepositoryUrl}>{footer.github}</a>
        <a href="mailto:hello@phototend.onemorejack.top">{footer.contact}</a>
      </nav>
      <small>{footer.copyright}</small>
    </footer>
  );
}
