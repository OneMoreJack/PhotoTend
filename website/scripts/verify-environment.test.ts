// @ts-expect-error The production verifier is an executable JavaScript module.
import { verifyEnvironment } from "./verify-environment.mjs";

const completeEnvironment = {
  NEXT_PUBLIC_SITE_URL: "https://phototend.onemorejack.top",
  NEXT_PUBLIC_SUPABASE_URL: "https://abcdefghijklmnopqrst.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: `eyJ${"a".repeat(64)}`,
  DOWNLOAD_TOKEN_SECRET: "download-secret-with-at-least-32-characters",
  UNSUBSCRIBE_TOKEN_SECRET: "unsubscribe-secret-with-at-least-32-characters",
  REQUEST_FINGERPRINT_SECRET: "fingerprint-secret-with-at-least-32-characters",
  RESEND_API_KEY: `re_${"a".repeat(32)}`,
  RESEND_WEBHOOK_SECRET: `whsec_${"a".repeat(32)}`,
  RESEND_FROM: "PhotoTend <hello@phototend.onemorejack.top>",
  SUPPORT_EMAIL: "hello@phototend.onemorejack.top",
};

describe("verifyEnvironment", () => {
  it("accepts a complete production configuration", () => {
    const result = verifyEnvironment(completeEnvironment);

    expect(result.ready).toBe(true);
    expect(
      result.checks.every(
        (check: { name: string; status: string }) => check.status === "ready",
      ),
    ).toBe(true);
  });

  it("reports missing variables by name", () => {
    const result = verifyEnvironment({});

    expect(result.ready).toBe(false);
    expect(result.checks).toContainEqual({
      name: "NEXT_PUBLIC_SITE_URL",
      status: "missing",
    });
  });

  it("rejects placeholders without echoing their contents", () => {
    const result = verifyEnvironment({
      ...completeEnvironment,
      SUPABASE_SERVICE_ROLE_KEY:
        "replace-with-server-only-service-role-key",
    });
    const serialized = JSON.stringify(result);

    expect(result.ready).toBe(false);
    expect(result.checks).toContainEqual({
      name: "SUPABASE_SERVICE_ROLE_KEY",
      status: "placeholder",
    });
    expect(serialized).not.toContain(
      "replace-with-server-only-service-role-key",
    );
  });

  it("rejects malformed public URLs and weak secrets", () => {
    const result = verifyEnvironment({
      ...completeEnvironment,
      NEXT_PUBLIC_SITE_URL: "http://localhost:3000",
      NEXT_PUBLIC_SUPABASE_URL: "https://invalid-domain.net",
      DOWNLOAD_TOKEN_SECRET: "too-short",
    });

    expect(result.ready).toBe(false);
    expect(result.checks).toEqual(
      expect.arrayContaining([
        { name: "NEXT_PUBLIC_SITE_URL", status: "invalid" },
        { name: "NEXT_PUBLIC_SUPABASE_URL", status: "invalid" },
        { name: "DOWNLOAD_TOKEN_SECRET", status: "invalid" },
      ]),
    );
  });
});
