import { describe, expect, it, vi } from "vitest";
import { createResendWebhookHandler } from "./route";

function request(headers: HeadersInit = {}) {
  return new Request(
    "https://phototend.onemorejack.top/api/webhooks/resend",
    {
      method: "POST",
      headers: {
        "svix-id": "event-1",
        "svix-timestamp": "123",
        "svix-signature": "signature",
        ...headers,
      },
      body: '{"type":"email.delivered"}',
    },
  );
}

describe("Resend webhook route", () => {
  it("passes the untouched body and signature headers to the processor", async () => {
    const process = vi.fn().mockResolvedValue({ kind: "processed" });
    const response = await createResendWebhookHandler({ process })(request());

    expect(response.status).toBe(200);
    expect(process).toHaveBeenCalledWith({
      rawBody: '{"type":"email.delivered"}',
      eventId: "event-1",
      timestamp: "123",
      signature: "signature",
    });
  });

  it("rejects missing signature headers before processing", async () => {
    const process = vi.fn();
    const response = await createResendWebhookHandler({ process })(
      request({ "svix-signature": "" }),
    );

    expect(response.status).toBe(400);
    expect(process).not.toHaveBeenCalled();
  });

  it("rejects an invalid signature without revealing details", async () => {
    const response = await createResendWebhookHandler({
      process: vi.fn().mockRejectedValue(new Error("invalid signature")),
    })(request());

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ received: false });
  });
});
