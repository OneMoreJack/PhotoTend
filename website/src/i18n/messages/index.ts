import type { Locale } from "../config";
import { en } from "./en";
import { zhCN } from "./zh-CN";

const messages = {
  "zh-CN": zhCN,
  en,
} as const;

export function getMessages(locale: Locale) {
  return messages[locale];
}
