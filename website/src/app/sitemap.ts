import type { MetadataRoute } from "next";

const siteUrl = "https://phototend.onemorejack.top";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: `${siteUrl}/zh-CN`,
      changeFrequency: "weekly",
      priority: 1,
      alternates: {
        languages: {
          "zh-CN": `${siteUrl}/zh-CN`,
          en: `${siteUrl}/en`,
        },
      },
    },
    {
      url: `${siteUrl}/en`,
      changeFrequency: "weekly",
      priority: 0.9,
      alternates: {
        languages: {
          "zh-CN": `${siteUrl}/zh-CN`,
          en: `${siteUrl}/en`,
        },
      },
    },
    {
      url: `${siteUrl}/zh-CN/privacy`,
      changeFrequency: "monthly",
      priority: 0.3,
    },
    {
      url: `${siteUrl}/en/privacy`,
      changeFrequency: "monthly",
      priority: 0.3,
    },
  ];
}
