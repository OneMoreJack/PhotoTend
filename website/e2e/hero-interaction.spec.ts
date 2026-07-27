import { expect, test } from "@playwright/test";

test("hero demo responds to a horizontal drag", async ({ page }) => {
  await page.goto("/zh-CN");

  const gestureSurface = page.locator("[data-gesture-surface]");
  const bounds = await gestureSurface.boundingBox();
  expect(bounds).not.toBeNull();

  const centerX = bounds!.x + bounds!.width / 2;
  const centerY = bounds!.y + bounds!.height / 2;
  await page.mouse.move(centerX, centerY);
  await page.mouse.down();
  await page.mouse.move(centerX - 100, centerY, { steps: 6 });
  await page.mouse.up();

  await expect(page.getByRole("status")).toContainText(
    "已切换到下一张照片",
  );
});

test("hero auto demo respects reduced motion", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/zh-CN");

  await expect(page.locator(".hero-demo__phone")).toHaveAttribute(
    "data-reduced-motion",
    "true",
  );
  await page.waitForTimeout(3200);
  await expect(page.getByRole("status")).toContainText(
    "拖动照片，体验 PhotoTend 手势",
  );
});

test("import story renders a detailed SD card illustration", async ({
  page,
}) => {
  await page.goto("/zh-CN");

  await expect(page.locator(".sd-import-visual")).toBeVisible();
  await expect(
    page.locator('[data-testid="sd-card-contacts"] path'),
  ).toHaveCount(8);
  await expect(page.getByTestId("sd-traveling-photo")).toHaveCount(3);
});
