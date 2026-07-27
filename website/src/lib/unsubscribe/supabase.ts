import { createSupabaseAdminClient } from "@/lib/supabase/server";
import type { UnsubscribeRepository } from "./service";

export function createSupabaseUnsubscribeRepository(): UnsubscribeRepository {
  const supabase = createSupabaseAdminClient();

  return {
    async setTokenHash(entryId, tokenHash) {
      const { error } = await supabase
        .from("waitlist_entries")
        .update({
          unsubscribe_token_hash: tokenHash,
          updated_at: new Date().toISOString(),
        })
        .eq("id", entryId);
      if (error) {
        throw new Error("Unable to save unsubscribe token", { cause: error });
      }
    },

    async unsubscribeByTokenHash(tokenHash) {
      const { data, error } = await supabase
        .from("waitlist_entries")
        .update({
          status: "unsubscribed",
          updated_at: new Date().toISOString(),
        })
        .eq("unsubscribe_token_hash", tokenHash)
        .select("id")
        .maybeSingle();
      if (error) {
        throw new Error("Unable to unsubscribe waitlist entry", {
          cause: error,
        });
      }
      return data !== null;
    },
  };
}
