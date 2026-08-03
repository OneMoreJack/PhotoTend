import {
  isLocale,
  locales,
  type Locale,
} from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import type { ReactNode } from "react";

type LayoutProps = {
  children: ReactNode;
  params: Promise<{ locale: string }>;
};

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: LayoutProps): Promise<Metadata> {
  const { locale: localeParam } = await params;

  if (!isLocale(localeParam)) {
    return {};
  }

  const locale: Locale = localeParam;
  const messages = getMessages(locale);
  const path = `/${locale}`;

  return {
    title: messages.metadata.title,
    description: messages.metadata.description,
    alternates: {
      canonical: path,
      languages: {
        "zh-CN": "/zh-CN",
        en: "/en",
      },
    },
    openGraph: {
      title: messages.metadata.title,
      description: messages.metadata.description,
      url: path,
      locale: locale === "zh-CN" ? "zh_CN" : "en_US",
      images: [
        {
          url: "/opengraph-image",
          width: 1200,
          height: 630,
          alt: messages.metadata.title,
        },
      ],
    },
  };
}

export default async function LocaleLayout({
  children,
  params,
}: LayoutProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return (
    <>
      <script
        dangerouslySetInnerHTML={{
          __html: `document.documentElement.lang=${JSON.stringify(locale)};`,
        }}
      />
      {children}
    </>
  );
}
