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
    expect(within(imports).getByText("macOS 文件夹")).toBeInTheDocument();

    expect(
      screen.getByRole("heading", { name: "整理不用从头开始" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "照片和视频一起看" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "给反悔留出空间" }),
    ).toBeInTheDocument();

    expect(screen.getAllByText("获取体验版")).toHaveLength(2);
    expect(screen.getByText("Android 体验版")).toBeInTheDocument();
    expect(screen.getByText("macOS 体验版")).toBeInTheDocument();
    expect(screen.getByText("iPhone 即将开放")).toBeInTheDocument();
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
    expect(screen.getAllByText("Get early access")).toHaveLength(2);
  });
});
