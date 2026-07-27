import {
  waitlistInputSchema,
  type ValidWaitlistInput,
  type WaitlistInput,
} from "./schema";

export type ActiveRelease = {
  id: string;
  platform: ValidWaitlistInput["platform"];
  version: string;
  storagePath: string;
};

export type WaitlistRepository = {
  saveEntry(input: ValidWaitlistInput): Promise<{ id: string }>;
  findActiveRelease(
    platform: ValidWaitlistInput["platform"],
  ): Promise<ActiveRelease | null>;
};

export type WaitlistResult =
  | { kind: "waiting"; entryId: string }
  | {
      kind: "download-ready";
      entryId: string;
      release: ActiveRelease;
    };

export class WaitlistValidationError extends Error {
  override name = "WaitlistValidationError";
}

export class WaitlistAbuseError extends Error {
  override name = "WaitlistAbuseError";
}

export function createWaitlistService(repository: WaitlistRepository) {
  return {
    async join(input: unknown): Promise<WaitlistResult> {
      const parsed = waitlistInputSchema.safeParse(input);
      if (!parsed.success) {
        const rawInput = input as Partial<WaitlistInput> | null;
        if (
          rawInput &&
          typeof rawInput.website === "string" &&
          rawInput.website.length > 0
        ) {
          throw new WaitlistAbuseError("Automated submission rejected");
        }
        throw new WaitlistValidationError("Waitlist input is invalid");
      }

      const entry = await repository.saveEntry(parsed.data);
      const release = await repository.findActiveRelease(parsed.data.platform);

      if (!release) {
        return { kind: "waiting", entryId: entry.id };
      }

      return {
        kind: "download-ready",
        entryId: entry.id,
        release,
      };
    },
  };
}
