import { createAndroidDownloadHandler } from "./route";

describe("Android direct download route", () => {
  it("redirects directly to a short-lived signed APK URL", async () => {
    const response = await createAndroidDownloadHandler({
      async findActiveAndroidRelease() {
        return { storagePath: "android/1.0.0/phototend.apk" };
      },
      async sign(storagePath, expiresInSeconds) {
        expect(storagePath).toBe("android/1.0.0/phototend.apk");
        expect(expiresInSeconds).toBe(300);
        return "https://storage.example/signed-phototend.apk";
      },
    })(
      new Request(
        "https://phototend.onemorejack.top/api/download/android?locale=zh-CN",
      ),
    );

    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe(
      "https://storage.example/signed-phototend.apk",
    );
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("shows a localized recovery page when no verified Android release exists", async () => {
    const response = await createAndroidDownloadHandler({
      async findActiveAndroidRelease() {
        return null;
      },
      async sign() {
        throw new Error("should not sign");
      },
    })(
      new Request(
        "https://phototend.onemorejack.top/api/download/android?locale=en",
      ),
    );

    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe(
      "https://phototend.onemorejack.top/en/download-error?reason=unavailable",
    );
  });
});
