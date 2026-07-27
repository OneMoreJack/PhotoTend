import { render, screen } from "@testing-library/react";
import { LocaleSwitcher } from "./locale-switcher";

describe("LocaleSwitcher", () => {
  it("links Chinese pages to the matching English location", () => {
    render(<LocaleSwitcher locale="zh-CN" />);

    expect(screen.getByRole("link", { name: "English" })).toHaveAttribute(
      "href",
      "/en",
    );
  });

  it("links English pages to the matching Chinese location", () => {
    render(<LocaleSwitcher locale="en" />);

    expect(screen.getByRole("link", { name: "简体中文" })).toHaveAttribute(
      "href",
      "/zh-CN",
    );
  });
});
