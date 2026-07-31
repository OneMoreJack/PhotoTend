import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import Link from "next/link";
import { androidDownloadUrl } from "@/lib/links";
import { HeroDemo } from "./hero-demo";

export function Hero({ locale }: { locale: Locale }) {
  const { hero } = getMessages(locale);

  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="hero__copy">
        <p className="eyebrow">{hero.eyebrow}</p>
        <h1 id="hero-title">{hero.title}</h1>
        <p className="hero__lead">{hero.body}</p>
        <div className="hero__actions">
          <Link className="button" href={androidDownloadUrl}>
            {hero.cta}
            <span aria-hidden="true"> ↗</span>
          </Link>
          <p>{hero.note}</p>
        </div>
      </div>
      <HeroDemo locale={locale} />
    </section>
  );
}
