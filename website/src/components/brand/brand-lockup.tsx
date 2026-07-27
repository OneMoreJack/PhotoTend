import Image from "next/image";
import Link from "next/link";

type Locale = "zh-CN" | "en";

const brandNames: Record<Locale, string> = {
  "zh-CN": "理好相册 PhotoTend",
  en: "PhotoTend",
};

export function BrandLockup({ locale }: { locale: Locale }) {
  const brandName = brandNames[locale];

  return (
    <Link
      className="brand-lockup"
      href={`/${locale}`}
      aria-label={brandName}
    >
      <Image
        src="/brand/phototend-mark.svg"
        width={36}
        height={36}
        alt=""
      />
      <span aria-hidden="true">{brandName}</span>
    </Link>
  );
}
