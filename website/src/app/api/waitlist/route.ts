import type { WaitlistResult } from "@/lib/waitlist/service";

type WaitlistJoiner = {
  join(input: unknown): Promise<WaitlistResult>;
};

function json(body: unknown, status = 200) {
  return Response.json(body, {
    status,
    headers: {
      "cache-control": "no-store",
    },
  });
}

function isAllowedOrigin(request: Request) {
  const origin = request.headers.get("origin");
  const configuredSite = process.env.NEXT_PUBLIC_SITE_URL;
  const allowed = new Set([
    "https://phototend.onemorejack.top",
    "http://127.0.0.1:3000",
    "http://localhost:3000",
  ]);
  if (configuredSite) {
    allowed.add(configuredSite);
  }
  return origin !== null && allowed.has(origin);
}

export function createWaitlistHandler(waitlist: WaitlistJoiner) {
  return async function handleWaitlist(request: Request): Promise<Response> {
    if (!isAllowedOrigin(request)) {
      return json({ result: "forbidden" }, 403);
    }

    if (!request.headers.get("content-type")?.startsWith("application/json")) {
      return json({ result: "unsupported-content" }, 415);
    }

    let input: unknown;
    try {
      input = await request.json();
    } catch {
      return json({ result: "invalid-input" }, 400);
    }

    try {
      const result = await waitlist.join(input);
      return json({
        result:
          result.kind === "download-ready" ? "download-ready" : "waiting",
      });
    } catch (error) {
      if (
        error instanceof Error &&
        (error.name === "WaitlistValidationError" ||
          error.name === "WaitlistAbuseError")
      ) {
        return json({ result: "invalid-input" }, 400);
      }
      return json({ result: "try-again" }, 503);
    }
  };
}

export async function POST(request: Request) {
  const [{ createWaitlistService }, { createSupabaseWaitlistRepository }] =
    await Promise.all([
      import("@/lib/waitlist/service"),
      import("@/lib/waitlist/supabase-repository"),
    ]);
  return createWaitlistHandler(
    createWaitlistService(createSupabaseWaitlistRepository()),
  )(request);
}
