import { BrandLockup } from "@/components/brand/brand-lockup";
import { LocaleSwitcher } from "@/components/locale-switcher";
import { isLocale, locales, type Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import Link from "next/link";
import { notFound } from "next/navigation";

type PageProps = {
  params: Promise<{ locale: string }>;
};

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export default async function MarketingPage({ params }: PageProps) {
  const { locale: localeParam } = await params;

  if (!isLocale(localeParam)) {
    notFound();
  }

  const locale: Locale = localeParam;
  const messages = getMessages(locale);

  return (
    <main>
      <BrandLockup locale={locale} />
      <LocaleSwitcher locale={locale} />
      <p>{messages.hero.eyebrow}</p>
      <h1>{messages.hero.title}</h1>
      <p>{messages.hero.body}</p>
      <Link href={`/${locale}#waitlist`}>{messages.hero.cta}</Link>
    </main>
  );
}
