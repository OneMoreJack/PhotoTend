export type RateLimitInput = {
  emailHash: string;
  sourceHash: string;
};

export type RateLimitResult = {
  allowed: boolean;
};

export type RateLimiter = {
  check(input: RateLimitInput): Promise<RateLimitResult>;
};

type MemoryRateLimiterOptions = {
  emailLimit: number;
  sourceLimit: number;
  windowMs: number;
  now?: () => number;
};

export function createMemoryRateLimiter({
  emailLimit,
  sourceLimit,
  windowMs,
  now = Date.now,
}: MemoryRateLimiterOptions): RateLimiter {
  const attempts: Array<RateLimitInput & { occurredAt: number }> = [];

  return {
    async check(input) {
      const cutoff = now() - windowMs;
      while (attempts[0] && attempts[0].occurredAt <= cutoff) {
        attempts.shift();
      }

      const emailCount = attempts.filter(
        (attempt) => attempt.emailHash === input.emailHash,
      ).length;
      const sourceCount = attempts.filter(
        (attempt) => attempt.sourceHash === input.sourceHash,
      ).length;

      if (emailCount >= emailLimit || sourceCount >= sourceLimit) {
        return { allowed: false };
      }

      attempts.push({ ...input, occurredAt: now() });
      return { allowed: true };
    },
  };
}
