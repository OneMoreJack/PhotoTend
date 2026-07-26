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

    expect(screen.getByTestId("waitlist-identity-group")).toBeVisible();
    expect(screen.getByTestId("waitlist-preferences-group")).toBeVisible();
    expect(screen.getByTestId("waitlist-consent-group")).toBeVisible();
    expect(screen.getByTestId("waitlist-submit-group")).toBeVisible();
    expect(screen.getByLabelText("邮箱")).toBeVisible();
    expect(
      screen.getByRole("group", { name: "希望接收哪个平台的通知" }),
    ).toBeVisible();
    expect(screen.getByLabelText("Android")).toBeVisible();
    expect(screen.getByLabelText("macOS")).toBeVisible();
    expect(screen.getByLabelText("iPhone")).toBeVisible();
    expect(screen.getByRole("button", { name: "订阅更新" })).toBeDisabled();
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

    fireEvent.click(screen.getByRole("button", { name: "订阅更新" }));

    expect(
      screen.getByRole("button", { name: "正在订阅……" }),
    ).toBeDisabled();
    await waitFor(() =>
      expect(screen.getByRole("status")).toHaveTextContent(
        "订阅成功。重要版本更新时，我们会通知你。",
      ),
    );
  });

  it("treats a legacy download-ready response as a subscription success", async () => {
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
    fireEvent.click(screen.getByRole("button", { name: "订阅更新" }));

    await waitFor(() =>
      expect(screen.getByRole("status")).toHaveTextContent(
        "订阅成功。重要版本更新时，我们会通知你。",
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
    fireEvent.click(screen.getByRole("button", { name: "订阅更新" }));

    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent(
        "暂时没能完成，请稍后再试。我们会安全地处理你的重复提交。",
      ),
    );
    expect(screen.getByLabelText("邮箱")).toHaveValue("user@example.com");
    expect(screen.getByRole("button", { name: "再次尝试" })).toBeEnabled();
  });

  it("renders the equivalent English experience", () => {
    render(<WaitlistForm locale="en" source="footer" />);

    expect(screen.getByLabelText("Email")).toBeVisible();
    expect(
      screen.getByRole("group", { name: "Choose a platform for updates" }),
    ).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Subscribe to updates" }),
    ).toBeDisabled();
  });
});
