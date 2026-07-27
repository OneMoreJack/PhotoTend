import { render, screen } from "@testing-library/react";
import { BrandLockup } from "./brand-lockup";

describe("BrandLockup", () => {
  it("uses the localized brand name as one accessible label", () => {
    render(<BrandLockup locale="zh-CN" />);

    expect(
      screen.getByRole("link", { name: "理好相册 PhotoTend" }),
    ).toHaveAttribute("href", "/zh-CN");
    expect(screen.getByAltText("")).toBeInTheDocument();
    expect(screen.getAllByText("理好相册 PhotoTend")).toHaveLength(1);
  });

  it("uses the English brand name on English pages", () => {
    render(<BrandLockup locale="en" />);

    expect(screen.getByRole("link", { name: "PhotoTend" })).toHaveAttribute(
      "href",
      "/en",
    );
  });
});
