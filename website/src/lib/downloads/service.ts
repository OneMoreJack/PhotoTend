import { createDownloadToken, hashDownloadToken } from "./token";

type ReleaseStatus = "draft" | "active" | "retired";

type DownloadGrant = {
  id: string;
  expiresAt: string;
  revokedAt: string | null;
  release: {
    id: string;
    status: ReleaseStatus;
    storagePath: string;
  };
};

export type DownloadRepository = {
  createGrant(input: {
    waitlistEntryId: string;
    releaseId: string;
    tokenHash: string;
    expiresAt: string;
  }): Promise<void>;
  findGrantByTokenHash(tokenHash: string): Promise<DownloadGrant | null>;
  recordEvent(
    grantId: string | null,
    result: "redirected" | "expired" | "revoked" | "invalid" | "missing_file",
  ): Promise<void>;
};

export type ReleaseSigner = {
  sign(storagePath: string, expiresInSeconds: number): Promise<string>;
};

type DownloadServiceOptions = {
  repository: DownloadRepository;
  signer: ReleaseSigner;
  tokenSecret: string;
  now?: () => Date;
};

export function createDownloadService({
  repository,
  signer,
  tokenSecret,
  now = () => new Date(),
}: DownloadServiceOptions) {
  return {
    async createGrant(input: {
      waitlistEntryId: string;
      releaseId: string;
    }) {
      const token = createDownloadToken();
      const expiresAt = new Date(
        now().getTime() + 7 * 24 * 60 * 60 * 1000,
      ).toISOString();

      await repository.createGrant({
        ...input,
        tokenHash: hashDownloadToken(token, tokenSecret),
        expiresAt,
      });

      return { token, expiresAt };
    },

    async authorize(token: string): Promise<
      | { kind: "redirect"; url: string }
      | {
          kind: "error";
          reason: "invalid" | "expired" | "revoked" | "unavailable";
        }
    > {
      const grant = await repository.findGrantByTokenHash(
        hashDownloadToken(token, tokenSecret),
      );
      if (!grant) {
        await repository.recordEvent(null, "invalid");
        return { kind: "error", reason: "invalid" };
      }
      if (grant.revokedAt) {
        await repository.recordEvent(grant.id, "revoked");
        return { kind: "error", reason: "revoked" };
      }
      if (new Date(grant.expiresAt).getTime() <= now().getTime()) {
        await repository.recordEvent(grant.id, "expired");
        return { kind: "error", reason: "expired" };
      }
      if (grant.release.status !== "active") {
        await repository.recordEvent(grant.id, "invalid");
        return { kind: "error", reason: "unavailable" };
      }

      try {
        const url = await signer.sign(grant.release.storagePath, 300);
        await repository.recordEvent(grant.id, "redirected");
        return { kind: "redirect", url };
      } catch {
        await repository.recordEvent(grant.id, "missing_file");
        return { kind: "error", reason: "unavailable" };
      }
    },
  };
}
