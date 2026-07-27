import { render, screen } from "@testing-library/react";
import HomePage from "./page";

describe("HomePage", () => {
  it("introduces PhotoTend and offers the Android download", () => {
    render(<HomePage />);

    expect(
      screen.getByRole("heading", { name: /理好相册 PhotoTend/i }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("link", { name: "下载 Android 版" }),
    ).toHaveAttribute(
      "href",
      "https://github.com/OneMoreJack/PhotoTend/releases/latest/download/phototend-android.apk",
    );
  });
});
