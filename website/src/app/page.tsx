import { MarketingPageContent } from "@/components/marketing/marketing-page";
import { defaultLocale } from "@/i18n/config";

export default function HomePage() {
  return <MarketingPageContent locale={defaultLocale} />;
}
