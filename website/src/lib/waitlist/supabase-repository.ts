import { createSupabaseAdminClient } from "@/lib/supabase/server";
import type { WaitlistRepository } from "./service";

export function createSupabaseWaitlistRepository(): WaitlistRepository {
  const supabase = createSupabaseAdminClient();

  return {
    async saveEntry(input) {
      const now = new Date().toISOString();
      const { data, error } = await supabase
        .from("waitlist_entries")
        .upsert(
          {
            email: input.email,
            platform: input.platform,
            locale: input.locale,
            source: input.source,
            status: "active",
            consent_at: now,
            updated_at: now,
          },
          { onConflict: "email" },
        )
        .select("id")
        .single();

      if (error) {
        throw new Error("Unable to save waitlist entry", { cause: error });
      }

      return data;
    },

    async findActiveRelease(platform) {
      const { data, error } = await supabase
        .from("releases")
        .select("id, platform, version, storage_path")
        .eq("platform", platform)
        .eq("status", "active")
        .maybeSingle();

      if (error) {
        throw new Error("Unable to read active release", { cause: error });
      }

      return data
        ? {
            id: data.id,
            platform: data.platform,
            version: data.version,
            storagePath: data.storage_path,
          }
        : null;
    },
  };
}
