import { createHmac } from "node:crypto";

const sourcePattern = /^[0-9a-fA-F:.]{2,64}$/;

export function createRequestFingerprint(source: string, secret: string) {
  return createHmac("sha256", secret).update(source).digest("hex");
}

export function getRequestSource(headers: Headers) {
  const raw =
    headers.get("x-vercel-forwarded-for") ??
    headers.get("x-forwarded-for") ??
    "";
  const source = raw.split(",")[0]?.trim() ?? "";

  return sourcePattern.test(source) ? source : "unknown";
}
