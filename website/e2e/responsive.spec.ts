import { expect, test } from "@playwright/test";

const viewports = [
  { name: "mobile", width: 390, height: 844 },
  { name: "tablet", width: 768, height: 1024 },
  { name: "desktop", width: 1440, height: 1000 },
];

for (const viewport of viewports) {
  test(`${viewport.name} layout stays usable without horizontal overflow`, async ({
    page,
  }) => {
    await page.setViewportSize(viewport);
    await page.goto("/zh-CN");

    await expect(
      page.getByRole("heading", {
        level: 1,
        name: "让整理照片，变成一件顺手的小事。",
      }),
    ).toBeVisible();
    await expect(
      page.getByRole("link", { name: "下载 Android 版" }).first(),
    ).toBeVisible();

    const dimensions = await page.evaluate(() => {
      const clientWidth = document.documentElement.clientWidth;
      const offenders = Array.from(document.querySelectorAll<HTMLElement>("body *"))
        .filter((element) => {
          const box = element.getBoundingClientRect();
          return box.right > clientWidth + 1 || box.left < -1;
        })
        .map((element) => ({
          className: element.className,
          left: element.getBoundingClientRect().left,
          right: element.getBoundingClientRect().right,
        }));

      return {
        clientWidth,
        scrollWidth: document.documentElement.scrollWidth,
        offenders,
      };
    });
    expect(
      dimensions.scrollWidth,
      JSON.stringify(dimensions.offenders),
    ).toBeLessThanOrEqual(dimensions.clientWidth);
  });
}
