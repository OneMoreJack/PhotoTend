import { z } from "zod";

export const waitlistInputSchema = z.object({
  email: z
    .string()
    .trim()
    .min(3)
    .max(320)
    .email()
    .transform((value) => value.toLowerCase()),
  platform: z.enum(["android", "macos", "ios"]),
  locale: z.enum(["zh-CN", "en"]),
  source: z.string().trim().min(1).max(64),
  consent: z.literal(true),
  website: z.string().max(0),
});

export type WaitlistInput = z.input<typeof waitlistInputSchema>;
export type ValidWaitlistInput = z.output<typeof waitlistInputSchema>;
