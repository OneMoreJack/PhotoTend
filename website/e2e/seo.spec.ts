import { expect, test } from "@playwright/test";

test("Chinese page exposes localized canonical and alternate metadata", async ({
  page,
}) => {
  await page.goto("/zh-CN");

  await expect(page).toHaveTitle("理好相册 PhotoTend");
  await expect(page.locator('meta[name="description"]')).toHaveAttribute(
    "content",
    "轻松整理，留下真正重要的照片。",
  );
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    "https://phototend.onemorejack.top/zh-CN",
  );
  await expect(page.locator('link[hreflang="en"]')).toHaveAttribute(
    "href",
    "https://phototend.onemorejack.top/en",
  );
  await expect(page.locator('meta[property="og:image"]')).toHaveAttribute(
    "content",
    /opengraph-image/,
  );
});

test("robots and sitemap are public", async ({ request }) => {
  const robots = await request.get("/robots.txt");
  expect(robots.ok()).toBe(true);
  expect(await robots.text()).toContain(
    "Sitemap: https://phototend.onemorejack.top/sitemap.xml",
  );

  const sitemap = await request.get("/sitemap.xml");
  expect(sitemap.ok()).toBe(true);
  expect(await sitemap.text()).toContain(
    "https://phototend.onemorejack.top/zh-CN",
  );
});
