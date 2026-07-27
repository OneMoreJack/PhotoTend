import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

test("Chinese marketing page has no serious accessibility violations", async ({
  page,
}) => {
  await page.goto("/zh-CN");

  await expect(page.locator("main")).toHaveCount(1);
  await expect(page.getByRole("heading", { level: 1 })).toHaveCount(1);
  await expect(
    page.getByRole("link", { name: "在 GitHub 查看源码" }),
  ).toBeVisible();
  await expect(page.getByRole("textbox", { name: /邮箱/i })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "跳到主要内容" })).toBeAttached();

  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
    .analyze();
  const serious = results.violations.filter((violation) =>
    ["serious", "critical"].includes(violation.impact ?? ""),
  );
  expect(serious).toEqual([]);
});

test("keyboard focus is visible on the primary action", async ({ page }) => {
  await page.goto("/zh-CN");
  await page.keyboard.press("Tab");
  await expect(page.getByRole("link", { name: "跳到主要内容" })).toBeFocused();
});
