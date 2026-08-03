import { MarketingPageContent } from "@/components/marketing/marketing-page";
import { isLocale, locales, type Locale } from "@/i18n/config";
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
  return <MarketingPageContent locale={locale} />;
}
