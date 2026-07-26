type Unsubscriber = {
  unsubscribe(token: string): Promise<boolean>;
};

export function createUnsubscribeHandler(unsubscriber: Unsubscriber) {
  return async function handleUnsubscribe(request: Request) {
    if (!request.headers.get("content-type")?.startsWith("application/json")) {
      return Response.json({ result: "invalid" }, { status: 415 });
    }
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return Response.json({ result: "invalid" }, { status: 400 });
    }
    const token =
      typeof body === "object" &&
      body !== null &&
      "token" in body &&
      typeof body.token === "string"
        ? body.token
        : "";
    if (token.length < 32 || token.length > 256) {
      return Response.json({ result: "invalid" }, { status: 400 });
    }

    await unsubscriber.unsubscribe(token);
    return Response.json(
      { result: "unsubscribed" },
      { headers: { "cache-control": "no-store" } },
    );
  };
}

export async function POST(request: Request) {
  const secret = process.env.UNSUBSCRIBE_TOKEN_SECRET;
  if (!secret) {
    return Response.json({ result: "unavailable" }, { status: 503 });
  }
  const [{ createUnsubscribeService }, { createSupabaseUnsubscribeRepository }] =
    await Promise.all([
      import("@/lib/unsubscribe/service"),
      import("@/lib/unsubscribe/supabase"),
    ]);
  return createUnsubscribeHandler(
    createUnsubscribeService({
      repository: createSupabaseUnsubscribeRepository(),
      tokenSecret: secret,
    }),
  )(request);
}
