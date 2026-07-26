import { render, screen } from "@testing-library/react";
import HomePage from "./page";

describe("HomePage", () => {
  it("introduces PhotoTend and offers the waitlist call to action", () => {
    render(<HomePage />);

    expect(
      screen.getByRole("heading", { name: /理好相册 PhotoTend/i }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("link", { name: "获取体验版" }),
    ).toHaveAttribute("href", "/zh-CN#waitlist");
  });
});
