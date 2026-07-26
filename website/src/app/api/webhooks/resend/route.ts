type WebhookProcessor = {
  process(input: {
    rawBody: string;
    eventId: string;
    timestamp: string;
    signature: string;
  }): Promise<unknown>;
};

export function createResendWebhookHandler(processor: WebhookProcessor) {
  return async function handleResendWebhook(request: Request) {
    const eventId = request.headers.get("svix-id");
    const timestamp = request.headers.get("svix-timestamp");
    const signature = request.headers.get("svix-signature");
    if (!eventId || !timestamp || !signature) {
      return Response.json({ received: false }, { status: 400 });
    }

    const rawBody = await request.text();
    try {
      await processor.process({
        rawBody,
        eventId,
        timestamp,
        signature,
      });
      return Response.json({ received: true });
    } catch {
      return Response.json({ received: false }, { status: 400 });
    }
  };
}

export async function POST(request: Request) {
  const secret = process.env.RESEND_WEBHOOK_SECRET;
  if (!secret) {
    return Response.json({ received: false }, { status: 503 });
  }
  const [{ createEmailWebhookProcessor }, resendWebhook] = await Promise.all([
    import("@/lib/email/webhook"),
    import("@/lib/email/resend-webhook"),
  ]);
  return createResendWebhookHandler(
    createEmailWebhookProcessor({
      verifier: resendWebhook.createResendWebhookVerifier(secret),
      repository: resendWebhook.createSupabaseEmailEventRepository(),
    }),
  )(request);
}
