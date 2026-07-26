export type Platform = "android" | "macos" | "ios";
export type WaitlistStatus = "active" | "unsubscribed" | "blocked";
export type ReleaseStatus = "draft" | "active" | "retired";

export type Database = {
  public: {
    Tables: {
      waitlist_entries: {
        Row: {
          id: string;
          email: string;
          platform: Platform;
          locale: "zh-CN" | "en";
          source: string;
          status: WaitlistStatus;
          consent_at: string;
          last_email_sent_at: string | null;
          unsubscribe_token_hash: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          email: string;
          platform: Platform;
          locale: "zh-CN" | "en";
          source: string;
          consent_at: string;
          status?: WaitlistStatus;
          updated_at?: string;
        };
        Update: {
          platform?: Platform;
          locale?: "zh-CN" | "en";
          source?: string;
          status?: WaitlistStatus;
          updated_at?: string;
          last_email_sent_at?: string | null;
          unsubscribe_token_hash?: string | null;
        };
        Relationships: [];
      };
      releases: {
        Row: {
          id: string;
          platform: Platform;
          version: string;
          storage_path: string;
          checksum_sha256: string | null;
          status: ReleaseStatus;
          published_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
      download_grants: {
        Row: {
          id: string;
          waitlist_entry_id: string;
          release_id: string;
          token_hash: string;
          expires_at: string;
          revoked_at: string | null;
          created_at: string;
        };
        Insert: {
          waitlist_entry_id: string;
          release_id: string;
          token_hash: string;
          expires_at: string;
          revoked_at?: string | null;
        };
        Update: {
          revoked_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "download_grants_release_id_fkey";
            columns: ["release_id"];
            isOneToOne: false;
            referencedRelation: "releases";
            referencedColumns: ["id"];
          },
        ];
      };
      download_events: {
        Row: {
          id: string;
          download_grant_id: string | null;
          result: string;
          request_fingerprint: string | null;
          occurred_at: string;
        };
        Insert: {
          download_grant_id?: string | null;
          result: "redirected" | "expired" | "revoked" | "invalid" | "missing_file";
          request_fingerprint?: string | null;
        };
        Update: never;
        Relationships: [];
      };
      email_events: {
        Row: {
          id: string;
          waitlist_entry_id: string | null;
          provider_message_id: string | null;
          provider_event_id: string;
          event_type: string;
          occurred_at: string;
          created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      check_waitlist_rate_limit: {
        Args: {
          input_email_hash: string;
          input_source_hash: string;
          window_seconds?: number;
          email_limit?: number;
          source_limit?: number;
        };
        Returns: boolean;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
