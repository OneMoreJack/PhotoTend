import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { WaitlistForm } from "./waitlist-form";

afterEach(() => {
  vi.unstubAllGlobals();
});

function fillValidForm() {
  fireEvent.change(screen.getByLabelText("邮箱"), {
    target: { value: "user@example.com" },
  });
  fireEvent.click(screen.getByLabelText("Android"));
  fireEvent.click(screen.getByLabelText(/同意接收/));
}

describe("WaitlistForm", () => {
  it("uses visible labels and requires platform and consent", () => {
    render(<WaitlistForm locale="zh-CN" source="footer" />);

    expect(screen.getByLabelText("邮箱")).toBeVisible();
    expect(screen.getByRole("group", { name: "选择平台" })).toBeVisible();
    expect(screen.getByLabelText("Android")).toBeVisible();
    expect(screen.getByLabelText("macOS")).toBeVisible();
    expect(screen.getByLabelText("iPhone")).toBeVisible();
    expect(screen.getByRole("button", { name: "获取体验版" })).toBeDisabled();
  });

  it("shows a useful error after an invalid email loses focus", () => {
    render(<WaitlistForm locale="zh-CN" source="hero" />);
    const email = screen.getByLabelText("邮箱");

    fireEvent.change(email, { target: { value: "not-an-email" } });
    fireEvent.blur(email);

    expect(
      screen.getByText("邮箱格式不完整，请检查是否包含 @ 和域名。"),
    ).toBeVisible();
    expect(email).toHaveAttribute("aria-invalid", "true");
  });

  it("announces a waiting result and keeps the form usable", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ result: "waiting" }), {
          status: 200,
          headers: { "content-type": "application/json" },
        }),
      ),
    );
    render(<WaitlistForm locale="zh-CN" source="footer" />);
    fillValidForm();

    fireEvent.click(screen.getByRole("button", { name: "获取体验版" }));

    expect(
      screen.getByRole("button", { name: "正在加入体验名单……" }),
    ).toBeDisabled();
    await waitFor(() =>
      expect(screen.getByRole("status")).toHaveTextContent(
        "已加入名单。版本开放后，我们会第一时间通知你。",
      ),
    );
  });

  it("announces when the download email has been prepared", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ result: "download-ready" }), {
          status: 200,
        }),
      ),
    );
    render(<WaitlistForm locale="zh-CN" source="footer" />);
    fillValidForm();
    fireEvent.click(screen.getByRole("button", { name: "获取体验版" }));

    await waitFor(() =>
      expect(screen.getByRole("status")).toHaveTextContent(
        "邮件已出发，请打开邮箱查看下载方式。",
      ),
    );
  });

  it("preserves input and offers retry after a service failure", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ result: "try-again" }), {
          status: 503,
        }),
      ),
    );
    render(<WaitlistForm locale="zh-CN" source="footer" />);
    fillValidForm();
    fireEvent.click(screen.getByRole("button", { name: "获取体验版" }));

    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent(
        "暂时没能提交，请稍后再试。你的邮箱尚未被保存。",
      ),
    );
    expect(screen.getByLabelText("邮箱")).toHaveValue("user@example.com");
    expect(screen.getByRole("button", { name: "再次尝试" })).toBeEnabled();
  });

  it("renders the equivalent English experience", () => {
    render(<WaitlistForm locale="en" source="footer" />);

    expect(screen.getByLabelText("Email")).toBeVisible();
    expect(screen.getByRole("group", { name: "Choose a platform" })).toBeVisible();
    expect(screen.getByRole("button", { name: "Get early access" })).toBeDisabled();
  });
});
