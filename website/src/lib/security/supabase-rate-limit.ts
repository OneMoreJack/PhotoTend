import { createSupabaseAdminClient } from "@/lib/supabase/server";
import type { RateLimiter } from "./rate-limit";

export function createSupabaseRateLimiter(): RateLimiter {
  const supabase = createSupabaseAdminClient();

  return {
    async check({ emailHash, sourceHash }) {
      const { data, error } = await supabase.rpc("check_waitlist_rate_limit", {
        input_email_hash: emailHash,
        input_source_hash: sourceHash,
        window_seconds: 3600,
        email_limit: 3,
        source_limit: 20,
      });

      if (error) {
        throw new Error("Unable to check waitlist rate limit", {
          cause: error,
        });
      }

      return { allowed: data === true };
    },
  };
}
