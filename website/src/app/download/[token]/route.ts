type DownloadAuthorizer = {
  authorize(
    token: string,
  ): Promise<
    | { kind: "redirect"; url: string }
    | { kind: "error"; reason: string }
  >;
};

type RouteContext = {
  params: Promise<{ token: string }>;
};

export function createDownloadHandler(downloads: DownloadAuthorizer) {
  return async function handleDownload(
    request: Request,
    context: RouteContext,
  ) {
    const { token } = await context.params;
    const result = await downloads.authorize(token);

    if (result.kind === "redirect") {
      return new Response(null, {
        status: 307,
        headers: {
          location: result.url,
          "cache-control": "no-store",
          "referrer-policy": "no-referrer",
        },
      });
    }

    const requestUrl = new URL(request.url);
    const locale = requestUrl.searchParams.get("locale") === "en" ? "en" : "zh-CN";
    const recoveryUrl = new URL(`/${locale}/download-error`, request.url);
    recoveryUrl.searchParams.set("reason", result.reason);
    return new Response(null, {
      status: 307,
      headers: {
        location: recoveryUrl.toString(),
        "cache-control": "no-store",
        "referrer-policy": "no-referrer",
      },
    });
  };
}

export async function GET(request: Request, context: RouteContext) {
  const [{ createDownloadService }, supabaseDownloads] = await Promise.all([
    import("@/lib/downloads/service"),
    import("@/lib/downloads/supabase"),
  ]);
  const secret = process.env.DOWNLOAD_TOKEN_SECRET;
  if (!secret) {
    return new Response("Service unavailable", { status: 503 });
  }
  return createDownloadHandler(
    createDownloadService({
      repository: supabaseDownloads.createSupabaseDownloadRepository(),
      signer: supabaseDownloads.createSupabaseReleaseSigner(),
      tokenSecret: secret,
    }),
  )(request, context);
}
