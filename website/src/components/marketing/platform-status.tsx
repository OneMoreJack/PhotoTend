import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export function PlatformStatus({ locale }: { locale: Locale }) {
  const { platforms } = getMessages(locale);
  return (
    <section className="section platform-section" id="platforms">
      <div className="section-heading">
        <p className="eyebrow">{platforms.kicker}</p>
        <h2>{platforms.title}</h2>
      </div>
      <ul className="platform-list">
        {platforms.items.map((item) => (
          <li key={item.name}>
            <span className={`status-dot status-dot--${item.tone}`} />
            <strong>{item.name}</strong>
            <span>{item.status}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
