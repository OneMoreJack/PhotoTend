"use client";

import { useState } from "react";
import type { Locale } from "@/i18n/config";
import type { Platform } from "@/lib/database.types";

type Status = "idle" | "submitting" | "waiting" | "download-ready" | "error";

export function useWaitlist({
  locale,
  source,
}: {
  locale: Locale;
  source: string;
}) {
  const [status, setStatus] = useState<Status>("idle");

  async function submit(input: {
    email: string;
    platform: Platform;
    consent: boolean;
    website: string;
  }) {
    setStatus("submitting");
    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ ...input, locale, source }),
      });
      const body = (await response.json()) as { result?: string };
      if (response.ok && body.result === "waiting") {
        setStatus("waiting");
        return;
      }
      if (response.ok && body.result === "download-ready") {
        setStatus("download-ready");
        return;
      }
      setStatus("error");
    } catch {
      setStatus("error");
    }
  }

  return {
    status,
    submit,
    retry: () => setStatus("idle"),
  };
}
