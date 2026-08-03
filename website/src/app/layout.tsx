import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import "../styles/marketing.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://phototend.onemorejack.top"),
  title: "理好相册 PhotoTend",
  description: "轻松整理，留下真正重要的照片。",
  icons: {
    icon: "/brand/phototend-app-icon.png",
    apple: "/brand/phototend-app-icon.png",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#F4F0E8",
};

export default function RootLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
