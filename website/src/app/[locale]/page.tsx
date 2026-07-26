import { FeatureGrid } from "@/components/marketing/feature-grid";
import { FinalCta } from "@/components/marketing/final-cta";
import { GestureStory } from "@/components/marketing/gesture-story";
import { Hero } from "@/components/marketing/hero";
import { ImportStory } from "@/components/marketing/import-story";
import { Philosophy } from "@/components/marketing/philosophy";
import { PlatformStatus } from "@/components/marketing/platform-status";
import { SiteFooter } from "@/components/site/site-footer";
import { SiteHeader } from "@/components/site/site-header";
import { isLocale, locales, type Locale } from "@/i18n/config";
import { notFound } from "next/navigation";
import "../../styles/marketing.css";

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
  return (
    <>
      <a className="skip-link" href="#main-content">
        {locale === "zh-CN" ? "跳到主要内容" : "Skip to main content"}
      </a>
      <SiteHeader locale={locale} />
      <main id="main-content" className="marketing-page">
        <Hero locale={locale} />
        <GestureStory locale={locale} />
        <ImportStory locale={locale} />
        <FeatureGrid locale={locale} />
        <Philosophy locale={locale} />
        <PlatformStatus locale={locale} />
        <FinalCta locale={locale} />
      </main>
      <SiteFooter locale={locale} />
    </>
  );
}
