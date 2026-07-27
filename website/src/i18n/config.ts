export const locales = ["zh-CN", "en"] as const;
export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = "zh-CN";

export function isLocale(value: string): value is Locale {
  return locales.includes(value as Locale);
}

export function getPreferredLocale(acceptLanguage: string | null): Locale {
  if (!acceptLanguage) {
    return "en";
  }

  return acceptLanguage
    .split(",")
    .map((part) => part.trim().split(";")[0]?.toLowerCase())
    .some((language) => language?.startsWith("zh"))
    ? "zh-CN"
    : "en";
}
