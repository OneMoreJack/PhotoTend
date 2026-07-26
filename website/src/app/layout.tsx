import type { Metadata, Viewport } from "next";
import { headers } from "next/headers";
import type { ReactNode } from "react";
import { isLocale } from "@/i18n/config";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://phototend.onemorejack.top"),
  title: "理好相册 PhotoTend",
  description: "轻松整理，留下真正重要的照片。",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#F4F0E8",
};

export default async function RootLayout({
  children,
}: {
  children: ReactNode;
}) {
  const requestHeaders = await headers();
  const localeHeader = requestHeaders.get("x-phototend-locale");
  const locale = localeHeader && isLocale(localeHeader) ? localeHeader : "zh-CN";

  return (
    <html lang={locale}>
      <body>{children}</body>
    </html>
  );
}
