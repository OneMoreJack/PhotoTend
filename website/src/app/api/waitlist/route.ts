import type { WaitlistResult } from "@/lib/waitlist/service";
import {
  createRequestFingerprint,
  getRequestSource,
} from "@/lib/security/request-fingerprint";
import type { RateLimitResult } from "@/lib/security/rate-limit";

type WaitlistJoiner = {
  join(input: unknown): Promise<WaitlistResult>;
  checkRateLimit?: (input: {
    emailHash: string;
    sourceHash: string;
  }) => Promise<RateLimitResult>;
  fingerprintSecret?: string;
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
      if (waitlist.checkRateLimit) {
        const rawEmail =
          typeof input === "object" &&
          input !== null &&
          "email" in input &&
          typeof input.email === "string"
            ? input.email.trim().toLowerCase()
            : "invalid";
        const secret = waitlist.fingerprintSecret;
        if (!secret) {
          return json({ result: "try-again" }, 503);
        }
        const limit = await waitlist.checkRateLimit({
          emailHash: createRequestFingerprint(`email:${rawEmail}`, secret),
          sourceHash: createRequestFingerprint(
            `source:${getRequestSource(request.headers)}`,
            secret,
          ),
        });
        if (!limit.allowed) {
          return json({ result: "try-later" }, 429);
        }
      }

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
  const fingerprintSecret = process.env.REQUEST_FINGERPRINT_SECRET;
  const downloadSecret = process.env.DOWNLOAD_TOKEN_SECRET;
  const unsubscribeSecret = process.env.UNSUBSCRIBE_TOKEN_SECRET;
  const resendApiKey = process.env.RESEND_API_KEY;
  const resendFrom = process.env.RESEND_FROM;
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL;
  if (
    !fingerprintSecret ||
    !downloadSecret ||
    !unsubscribeSecret ||
    !resendApiKey ||
    !resendFrom ||
    !siteUrl
  ) {
    return json({ result: "try-again" }, 503);
  }

  const [
    { createWaitlistService },
    { createSupabaseWaitlistRepository },
    { createSupabaseRateLimiter },
    { createWaitlistDeliveryService },
    { createDownloadService },
    supabaseDownloads,
    { createEmailService },
    { createResendEmailSender },
    { createUnsubscribeService },
    { createSupabaseUnsubscribeRepository },
  ] =
    await Promise.all([
      import("@/lib/waitlist/service"),
      import("@/lib/waitlist/supabase-repository"),
      import("@/lib/security/supabase-rate-limit"),
      import("@/lib/waitlist/delivery"),
      import("@/lib/downloads/service"),
      import("@/lib/downloads/supabase"),
      import("@/lib/email/service"),
      import("@/lib/email/client"),
      import("@/lib/unsubscribe/service"),
      import("@/lib/unsubscribe/supabase"),
    ]);
  const rateLimiter = createSupabaseRateLimiter();
  const downloads = createDownloadService({
    repository: supabaseDownloads.createSupabaseDownloadRepository(),
    signer: supabaseDownloads.createSupabaseReleaseSigner(),
    tokenSecret: downloadSecret,
  });
  const unsubscribe = createUnsubscribeService({
    repository: createSupabaseUnsubscribeRepository(),
    tokenSecret: unsubscribeSecret,
  });
  const email = createEmailService({
    sender: createResendEmailSender(resendApiKey),
    grants: downloads,
    siteUrl,
    from: resendFrom,
  });
  const delivery = createWaitlistDeliveryService({
    waitlist: createWaitlistService(createSupabaseWaitlistRepository()),
    unsubscribe,
    email,
  });
  return createWaitlistHandler({
    ...delivery,
    checkRateLimit: rateLimiter.check,
    fingerprintSecret,
  })(request);
}
