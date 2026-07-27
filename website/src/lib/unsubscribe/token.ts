import { createHmac, randomBytes } from "node:crypto";

export function createUnsubscribeToken() {
  return randomBytes(32).toString("base64url");
}

export function hashUnsubscribeToken(token: string, secret: string) {
  return createHmac("sha256", secret).update(token).digest("hex");
}
