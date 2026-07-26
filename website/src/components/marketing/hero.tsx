import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import Link from "next/link";

export function Hero({ locale }: { locale: Locale }) {
  const { hero } = getMessages(locale);

  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="hero__copy">
        <p className="eyebrow">{hero.eyebrow}</p>
        <h1 id="hero-title">{hero.title}</h1>
        <p className="hero__lead">{hero.body}</p>
        <div className="hero__actions">
          <Link className="button" href={`/${locale}#waitlist`}>
            {hero.cta}
            <span aria-hidden="true"> ↗</span>
          </Link>
          <p>{hero.note}</p>
        </div>
      </div>
      <div className="hero-visual" aria-label={locale === "zh-CN" ? "PhotoTend 整理照片界面示意" : "PhotoTend organizing interface illustration"}>
        <div className="photo-stack photo-stack--back" aria-hidden="true" />
        <div className="photo-stack photo-stack--middle" aria-hidden="true" />
        <div className="phone-shell">
          <div className="phone-shell__top">
            <span>9:41</span>
            <span aria-hidden="true">● ●●</span>
          </div>
          <div className="memory-card">
            <div className="memory-card__sky" />
            <div className="memory-card__sun" />
            <div className="memory-card__land memory-card__land--far" />
            <div className="memory-card__land memory-card__land--near" />
            <p>杭州 · 2026.04.18</p>
          </div>
          <div className="phone-shell__gesture" aria-hidden="true">
            <span>←</span><span>↑</span><span>→</span>
          </div>
          <div className="phone-shell__rail" aria-hidden="true">
            <i /><i /><i /><i />
          </div>
        </div>
        <div className="hero-note hero-note--keep" aria-hidden="true">留下</div>
        <div className="hero-note hero-note--undo" aria-hidden="true">可撤销</div>
      </div>
    </section>
  );
}
