type AndroidDownloadSource = {
  findActiveAndroidRelease(): Promise<{ storagePath: string } | null>;
  sign(storagePath: string, expiresInSeconds: number): Promise<string>;
};

function redirect(location: string, cacheControl = "no-store") {
  return new Response(null, {
    status: 307,
    headers: {
      location,
      "cache-control": cacheControl,
    },
  });
}

export function createAndroidDownloadHandler(source: AndroidDownloadSource) {
  return async function GET(request: Request) {
    const requestUrl = new URL(request.url);
    const locale = requestUrl.searchParams.get("locale") === "en" ? "en" : "zh-CN";
    const recoveryUrl = new URL(
      `/${locale}/download-error?reason=unavailable`,
      requestUrl,
    );

    try {
      const release = await source.findActiveAndroidRelease();
      if (!release) {
        return redirect(recoveryUrl.toString());
      }

      const signedUrl = await source.sign(release.storagePath, 300);
      return redirect(signedUrl);
    } catch {
      return redirect(recoveryUrl.toString());
    }
  };
}

async function createProductionSource(): Promise<AndroidDownloadSource> {
  const [{ createSupabaseAdminClient }, { createSupabaseReleaseSigner }] =
    await Promise.all([
      import("@/lib/supabase/server"),
      import("@/lib/downloads/supabase"),
    ]);
  const supabase = createSupabaseAdminClient();
  const signer = createSupabaseReleaseSigner();

  return {
    async findActiveAndroidRelease() {
      const { data, error } = await supabase
        .from("releases")
        .select("storage_path")
        .eq("platform", "android")
        .eq("status", "active")
        .maybeSingle();

      if (error) {
        throw new Error("Unable to read active Android release", {
          cause: error,
        });
      }

      return data ? { storagePath: data.storage_path } : null;
    },
    sign: signer.sign,
  };
}

export async function GET(request: Request) {
  const source = await createProductionSource();
  return createAndroidDownloadHandler(source)(request);
}
