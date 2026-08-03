import { SiteFooter } from "@/components/site/site-footer";
import { SiteHeader } from "@/components/site/site-header";
import type { Locale } from "@/i18n/config";
import { FeatureGrid } from "./feature-grid";
import { FinalCta } from "./final-cta";
import { GestureStory } from "./gesture-story";
import { Hero } from "./hero";
import { ImportStory } from "./import-story";
import { Philosophy } from "./philosophy";
import { PlatformStatus } from "./platform-status";

export function MarketingPageContent({ locale }: { locale: Locale }) {
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
