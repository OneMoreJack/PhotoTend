import type { Locale } from "@/i18n/config";
import Link from "next/link";

export function LocaleSwitcher({ locale }: { locale: Locale }) {
  const targetLocale = locale === "zh-CN" ? "en" : "zh-CN";
  const label = targetLocale === "en" ? "English" : "简体中文";

  return <Link href={`/${targetLocale}`}>{label}</Link>;
}
