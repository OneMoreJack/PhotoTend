import type { MetadataRoute } from "next";

const siteUrl = "https://phototend.onemorejack.top";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: ["/api/", "/download/"],
    },
    sitemap: `${siteUrl}/sitemap.xml`,
  };
}
