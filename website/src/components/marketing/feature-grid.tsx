import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export function FeatureGrid({ locale }: { locale: Locale }) {
  const { features } = getMessages(locale);

  return (
    <section className="section feature-section">
      <p className="eyebrow">{features.kicker}</p>
      <div className="feature-list">
        {features.items.map((item) => (
          <article key={item.marker}>
            <span>{item.marker}</span>
            <h3>{item.title}</h3>
            <p>{item.body}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
