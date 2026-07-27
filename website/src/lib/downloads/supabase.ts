import { createSupabaseAdminClient } from "@/lib/supabase/server";
import type { DownloadRepository, ReleaseSigner } from "./service";

export function createSupabaseDownloadRepository(): DownloadRepository {
  const supabase = createSupabaseAdminClient();

  return {
    async createGrant(input) {
      const { error } = await supabase.from("download_grants").insert({
        waitlist_entry_id: input.waitlistEntryId,
        release_id: input.releaseId,
        token_hash: input.tokenHash,
        expires_at: input.expiresAt,
      });
      if (error) {
        throw new Error("Unable to create download grant", { cause: error });
      }
    },

    async findGrantByTokenHash(tokenHash) {
      const { data, error } = await supabase
        .from("download_grants")
        .select(
          "id, expires_at, revoked_at, releases!inner(id, status, storage_path)",
        )
        .eq("token_hash", tokenHash)
        .maybeSingle();
      if (error) {
        throw new Error("Unable to read download grant", { cause: error });
      }
      if (!data) {
        return null;
      }

      const release = Array.isArray(data.releases)
        ? data.releases[0]
        : data.releases;
      if (!release) {
        return null;
      }

      return {
        id: data.id,
        expiresAt: data.expires_at,
        revokedAt: data.revoked_at,
        release: {
          id: release.id,
          status: release.status,
          storagePath: release.storage_path,
        },
      };
    },

    async recordEvent(grantId, result) {
      const { error } = await supabase.from("download_events").insert({
        download_grant_id: grantId,
        result,
      });
      if (error) {
        throw new Error("Unable to record download event", { cause: error });
      }
    },
  };
}

export function createSupabaseReleaseSigner(): ReleaseSigner {
  const supabase = createSupabaseAdminClient();

  return {
    async sign(storagePath, expiresInSeconds) {
      const { data, error } = await supabase.storage
        .from("releases")
        .createSignedUrl(storagePath, expiresInSeconds, { download: true });
      if (error) {
        throw new Error("Unable to sign release download", { cause: error });
      }
      return data.signedUrl;
    },
  };
}
