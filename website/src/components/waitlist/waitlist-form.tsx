"use client";

import type { FormEvent } from "react";
import { useState } from "react";
import type { Locale } from "@/i18n/config";
import type { Platform } from "@/lib/database.types";
import { useWaitlist } from "./use-waitlist";

const copy = {
  "zh-CN": {
    email: "邮箱",
    emailPlaceholder: "you@example.com",
    emailError: "邮箱格式不完整，请检查是否包含 @ 和域名。",
    platform: "希望接收哪个平台的通知",
    consent: "同意接收 PhotoTend 的重要版本与平台上线通知",
    submit: "订阅更新",
    submitting: "正在订阅……",
    retry: "再次尝试",
    waiting: "订阅成功。重要版本更新时，我们会通知你。",
    ready: "订阅成功。重要版本更新时，我们会通知你。",
    error: "暂时没能完成，请稍后再试。我们会安全地处理你的重复提交。",
  },
  en: {
    email: "Email",
    emailPlaceholder: "you@example.com",
    emailError: "Enter a complete email address with an @ sign and domain.",
    platform: "Choose a platform for updates",
    consent: "I agree to receive important PhotoTend release and platform availability updates",
    submit: "Subscribe to updates",
    submitting: "Subscribing…",
    retry: "Try again",
    waiting: "You’re subscribed. We’ll email you about important releases.",
    ready: "You’re subscribed. We’ll email you about important releases.",
    error: "We couldn’t finish that. Please try again in a moment; repeat submissions are handled safely.",
  },
} as const;

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function WaitlistForm({
  locale,
  source,
}: {
  locale: Locale;
  source: string;
}) {
  const messages = copy[locale];
  const waitlist = useWaitlist({ locale, source });
  const [email, setEmail] = useState("");
  const [emailTouched, setEmailTouched] = useState(false);
  const [platform, setPlatform] = useState<Platform | null>(null);
  const [consent, setConsent] = useState(false);
  const [website, setWebsite] = useState("");
  const emailValid = emailPattern.test(email);
  const canSubmit =
    emailValid &&
    platform !== null &&
    consent &&
    waitlist.status !== "submitting";

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setEmailTouched(true);
    if (!canSubmit || !platform) {
      return;
    }
    void waitlist.submit({ email, platform, consent, website });
  }

  const buttonLabel =
    waitlist.status === "submitting"
      ? messages.submitting
      : waitlist.status === "error"
        ? messages.retry
        : messages.submit;

  return (
    <form
      className="waitlist-form"
      id="waitlist-form"
      noValidate
      onSubmit={handleSubmit}
    >
      <div className="waitlist-form__field">
        <label htmlFor={`${source}-email`}>{messages.email}</label>
        <input
          id={`${source}-email`}
          name="email"
          type="email"
          inputMode="email"
          autoComplete="email"
          placeholder={messages.emailPlaceholder}
          value={email}
          aria-invalid={emailTouched && !emailValid}
          aria-describedby={
            emailTouched && !emailValid ? `${source}-email-error` : undefined
          }
          onBlur={() => setEmailTouched(true)}
          onChange={(event) => setEmail(event.target.value)}
        />
        {emailTouched && !emailValid ? (
          <span className="waitlist-form__error" id={`${source}-email-error`}>
            {messages.emailError}
          </span>
        ) : null}
      </div>

      <fieldset>
        <legend>{messages.platform}</legend>
        <div className="platform-options">
          {(
            [
              ["android", "Android"],
              ["macos", "macOS"],
              ["ios", "iPhone"],
            ] as const
          ).map(([value, label]) => (
            <label key={value}>
              <input
                type="radio"
                name="platform"
                value={value}
                checked={platform === value}
                onChange={() => setPlatform(value)}
              />
              <span>{label}</span>
            </label>
          ))}
        </div>
      </fieldset>

      <label className="consent-field">
        <input
          type="checkbox"
          checked={consent}
          onChange={(event) => setConsent(event.target.checked)}
        />
        <span>{messages.consent}</span>
      </label>

      <div className="website-field" aria-hidden="true">
        <label htmlFor={`${source}-website`}>Website</label>
        <input
          id={`${source}-website`}
          name="website"
          tabIndex={-1}
          autoComplete="off"
          value={website}
          onChange={(event) => setWebsite(event.target.value)}
        />
      </div>

      <button
        className="button button--light"
        type="submit"
        disabled={!canSubmit}
        onClick={waitlist.status === "error" ? waitlist.retry : undefined}
      >
        {buttonLabel}
      </button>

      {waitlist.status === "waiting" ||
      waitlist.status === "download-ready" ? (
        <p className="waitlist-form__status" role="status">
          {waitlist.status === "waiting" ? messages.waiting : messages.ready}
        </p>
      ) : null}
      {waitlist.status === "error" ? (
        <p className="waitlist-form__error" role="alert">
          {messages.error}
        </p>
      ) : null}
    </form>
  );
}
