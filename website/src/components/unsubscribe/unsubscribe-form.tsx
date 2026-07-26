"use client";

import { useState } from "react";
import type { Locale } from "@/i18n/config";

export function UnsubscribeForm({
  locale,
  token,
}: {
  locale: Locale;
  token: string;
}) {
  const [status, setStatus] = useState<"idle" | "working" | "done" | "error">(
    "idle",
  );

  async function unsubscribe() {
    setStatus("working");
    try {
      const response = await fetch("/api/unsubscribe", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ token }),
      });
      setStatus(response.ok ? "done" : "error");
    } catch {
      setStatus("error");
    }
  }

  if (status === "done") {
    return (
      <p role="status">
        {locale === "zh-CN"
          ? "已退订。我们不会再发送非必要产品邮件。"
          : "You’re unsubscribed. We won’t send non-essential product email."}
      </p>
    );
  }

  return (
    <div>
      <button
        className="button"
        type="button"
        disabled={status === "working"}
        onClick={() => void unsubscribe()}
      >
        {status === "working"
          ? locale === "zh-CN"
            ? "正在退订……"
            : "Unsubscribing…"
          : locale === "zh-CN"
            ? "确认退订"
            : "Confirm unsubscribe"}
      </button>
      {status === "error" ? (
        <p role="alert">
          {locale === "zh-CN"
            ? "暂时无法完成，请稍后重试。"
            : "We couldn’t complete that. Please try again."}
        </p>
      ) : null}
    </div>
  );
}
