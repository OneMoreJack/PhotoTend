import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const migrationPath = resolve(
  process.cwd(),
  "supabase/migrations/202607260001_marketing_site.sql",
);

describe("marketing database migration", () => {
  it("protects waitlist identity and constrains public input", () => {
    const sql = readFileSync(migrationPath, "utf8").toLowerCase();

    expect(sql).toContain("email text not null unique");
    expect(sql).toContain("email = lower(btrim(email))");
    expect(sql).toContain("platform in ('android', 'macos', 'ios')");
    expect(sql).toContain(
      "status in ('active', 'unsubscribed', 'blocked')",
    );
  });

  it("allows only one active release per platform", () => {
    const sql = readFileSync(migrationPath, "utf8").toLowerCase();

    expect(sql).toContain("create unique index releases_one_active_platform");
    expect(sql).toContain("where status = 'active'");
  });

  it("makes tokens and provider events idempotent", () => {
    const sql = readFileSync(migrationPath, "utf8").toLowerCase();

    expect(sql).toContain("token_hash text not null unique");
    expect(sql).toContain("provider_event_id text not null unique");
  });

  it("enables RLS without granting anonymous table access", () => {
    const sql = readFileSync(migrationPath, "utf8").toLowerCase();

    for (const table of [
      "waitlist_entries",
      "releases",
      "download_grants",
      "download_events",
      "email_events",
    ]) {
      expect(sql).toContain(`alter table public.${table} enable row level security`);
    }
    expect(sql).not.toMatch(/create policy[\s\S]+?\bto anon\b/);
  });

  it("creates a private release bucket", () => {
    const sql = readFileSync(migrationPath, "utf8").toLowerCase();

    expect(sql).toContain("'releases', 'releases', false");
  });
});
