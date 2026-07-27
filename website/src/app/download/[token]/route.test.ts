import { describe, expect, it, vi } from "vitest";
import { createDownloadHandler } from "./route";

describe("download route", () => {
  it("redirects an authorized token without exposing it in response data", async () => {
    const authorize = vi.fn().mockResolvedValue({
      kind: "redirect",
      url: "https://signed.example/file.apk",
    });
    const response = await createDownloadHandler({ authorize })(
      new Request("https://phototend.onemorejack.top/download/private-token"),
      { params: Promise.resolve({ token: "private-token" }) },
    );

    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe(
      "https://signed.example/file.apk",
    );
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
  });

  it("sends invalid or expired grants to the localized recovery page", async () => {
    const authorize = vi.fn().mockResolvedValue({
      kind: "error",
      reason: "expired",
    });
    const response = await createDownloadHandler({ authorize })(
      new Request(
        "https://phototend.onemorejack.top/download/private-token?locale=en",
      ),
      { params: Promise.resolve({ token: "private-token" }) },
    );

    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe(
      "https://phototend.onemorejack.top/en/download-error?reason=expired",
    );
  });
});
