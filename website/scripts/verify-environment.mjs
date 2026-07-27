import { pathToFileURL } from "node:url";

const requiredVariables = [
  "NEXT_PUBLIC_SITE_URL",
  "NEXT_PUBLIC_SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "DOWNLOAD_TOKEN_SECRET",
  "UNSUBSCRIBE_TOKEN_SECRET",
  "REQUEST_FINGERPRINT_SECRET",
  "RESEND_API_KEY",
  "RESEND_WEBHOOK_SECRET",
  "RESEND_FROM",
  "SUPPORT_EMAIL",
];

const placeholderPattern =
  /replace|project[_-]?ref|example\.com|your[_-]|change[_-]?me/i;

function isHttpsUrl(value) {
  try {
    return new URL(value).protocol === "https:";
  } catch {
    return false;
  }
}

function isValid(name, value) {
  switch (name) {
    case "NEXT_PUBLIC_SITE_URL":
      return (
        isHttpsUrl(value) &&
        new URL(value).hostname === "phototend.onemorejack.top"
      );
    case "NEXT_PUBLIC_SUPABASE_URL":
      return (
        isHttpsUrl(value) &&
        /^[a-z0-9]{20}\.supabase\.co$/.test(new URL(value).hostname)
      );
    case "SUPABASE_SERVICE_ROLE_KEY":
      return value.length >= 40;
    case "DOWNLOAD_TOKEN_SECRET":
    case "UNSUBSCRIBE_TOKEN_SECRET":
    case "REQUEST_FINGERPRINT_SECRET":
      return value.length >= 32;
    case "RESEND_API_KEY":
      return /^re_[A-Za-z0-9_-]{24,}$/.test(value);
    case "RESEND_WEBHOOK_SECRET":
      return /^whsec_[A-Za-z0-9_-]{24,}$/.test(value);
    case "RESEND_FROM":
      return /^PhotoTend <[^@\s]+@phototend\.onemorejack\.top>$/.test(value);
    case "SUPPORT_EMAIL":
      return /^[^@\s]+@phototend\.onemorejack\.top$/.test(value);
    default:
      return false;
  }
}

export function verifyEnvironment(environment) {
  const checks = requiredVariables.map((name) => {
    const value = environment[name]?.trim();

    if (!value) {
      return { name, status: "missing" };
    }

    if (placeholderPattern.test(value)) {
      return { name, status: "placeholder" };
    }

    return {
      name,
      status: isValid(name, value) ? "ready" : "invalid",
    };
  });

  return {
    ready: checks.every(({ status }) => status === "ready"),
    checks,
  };
}

function printResult(result) {
  for (const check of result.checks) {
    console.log(`${check.name}: ${check.status}`);
  }

  console.log(result.ready ? "Environment: ready" : "Environment: not ready");
}

const invokedPath = process.argv[1] ? pathToFileURL(process.argv[1]).href : "";

if (import.meta.url === invokedPath) {
  const result = verifyEnvironment(process.env);
  printResult(result);
  process.exitCode = result.ready ? 0 : 1;
}
