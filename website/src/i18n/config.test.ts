import {
  defaultLocale,
  getPreferredLocale,
  isLocale,
  locales,
} from "./config";

describe("locale configuration", () => {
  it("supports Chinese and English with Chinese as the fallback", () => {
    expect(locales).toEqual(["zh-CN", "en"]);
    expect(defaultLocale).toBe("zh-CN");
    expect(isLocale("zh-CN")).toBe(true);
    expect(isLocale("en")).toBe(true);
    expect(isLocale("fr")).toBe(false);
  });

  it("maps Chinese browser preferences to Chinese", () => {
    expect(getPreferredLocale("zh-TW,zh;q=0.9,en;q=0.8")).toBe("zh-CN");
  });

  it("falls back to English for non-Chinese preferences", () => {
    expect(getPreferredLocale("fr-FR,fr;q=0.9,en;q=0.8")).toBe("en");
    expect(getPreferredLocale(null)).toBe("en");
  });
});
