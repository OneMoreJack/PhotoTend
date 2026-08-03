import { render, screen, within } from "@testing-library/react";
import HomePage from "./page";

describe("HomePage", () => {
  it("presents the complete Chinese product story", () => {
    render(<HomePage />);

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "让整理照片，变成一件顺手的小事。",
      }),
    ).toBeInTheDocument();

    const gestures = screen.getByLabelText("手势整理方式");
    expect(within(gestures).getByText("左滑")).toBeInTheDocument();
    expect(within(gestures).getByText("右滑")).toBeInTheDocument();
    expect(within(gestures).getByText("上滑")).toBeInTheDocument();

    expect(
      screen.getByRole("heading", {
        name: "手机里的，相机里的，都可以一起理好。",
      }),
    ).toBeInTheDocument();

    const downloadLinks = screen.getAllByRole("link", {
      name: "下载 Android 版",
    });
    expect(downloadLinks).toHaveLength(3);
    expect(downloadLinks[0]).toHaveAttribute(
      "href",
      "https://github.com/OneMoreJack/PhotoTend/releases/latest/download/phototend-android.apk",
    );
  });
});
