import { createHmac, randomBytes } from "node:crypto";

export function createDownloadToken() {
  return randomBytes(32).toString("base64url");
}

export function hashDownloadToken(token: string, secret: string) {
  return createHmac("sha256", secret).update(token).digest("hex");
}
