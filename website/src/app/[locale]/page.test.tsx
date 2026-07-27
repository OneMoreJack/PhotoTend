import { render, screen, within } from "@testing-library/react";
import MarketingPage from "./page";

describe("MarketingPage", () => {
  it("presents the complete Chinese product story", async () => {
    render(
      await MarketingPage({
        params: Promise.resolve({ locale: "zh-CN" }),
      }),
    );

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
    expect(within(gestures).getByText("下滑")).toBeInTheDocument();

    const imports = screen.getByLabelText("支持的导入来源");
    expect(within(imports).getByText("手机系统相册")).toBeInTheDocument();
    expect(within(imports).getByText("相机与存储卡")).toBeInTheDocument();
    expect(within(imports).getByText("移动存储设备")).toBeInTheDocument();
    expect(within(imports).getByText("外部文件夹")).toBeInTheDocument();

    expect(
      screen.getByRole("heading", { name: "整理不用从头开始" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "照片和视频一起看" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "给反悔留出空间" }),
    ).toBeInTheDocument();

    const downloadLinks = screen.getAllByRole("link", {
      name: "下载 Android 版",
    });
    expect(downloadLinks).toHaveLength(3);
    expect(downloadLinks[0]).toHaveAttribute(
      "href",
      "https://github.com/OneMoreJack/PhotoTend/releases/latest/download/phototend-android.apk",
    );
    expect(
      screen.getAllByRole("link", { name: "在 GitHub 查看源码" }),
    ).not.toHaveLength(0);
    const platformSection = screen
      .getByRole("heading", { name: "在熟悉的设备上开始。" })
      .closest("section");
    expect(platformSection).not.toBeNull();
    expect(within(platformSection!).getByText("Android 版")).toBeInTheDocument();
    expect(within(platformSection!).getByText("macOS")).toBeInTheDocument();
    expect(within(platformSection!).getByText("iPhone")).toBeInTheDocument();
    expect(within(platformSection!).getAllByText("Coming soon")).toHaveLength(2);
    expect(screen.getByText("开源，也保持开源。")).toBeInTheDocument();
    expect(screen.getByText(/GNU GPLv3/)).toBeInTheDocument();
    expect(screen.queryByRole("textbox", { name: /邮箱/i })).not.toBeInTheDocument();
    expect(screen.queryByText("订阅版本通知")).not.toBeInTheDocument();
  });

  it("presents the complete English product story", async () => {
    render(
      await MarketingPage({
        params: Promise.resolve({ locale: "en" }),
      }),
    );

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "Make photo organizing feel effortless.",
      }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", {
        name: "From your phone or your camera, bring it all together.",
      }),
    ).toBeInTheDocument();
    expect(
      screen.getAllByRole("link", { name: "Download for Android" }),
    ).toHaveLength(3);
    expect(
      screen.getAllByRole("link", { name: "View source on GitHub" }),
    ).not.toHaveLength(0);
    expect(screen.getAllByText("Coming soon")).toHaveLength(2);
    expect(screen.getByText("Open source, and staying that way.")).toBeInTheDocument();
    expect(screen.getByText(/GNU GPLv3/)).toBeInTheDocument();
    expect(screen.queryByRole("textbox", { name: /email/i })).not.toBeInTheDocument();
    expect(screen.queryByText("Get release updates")).not.toBeInTheDocument();
  });
});
