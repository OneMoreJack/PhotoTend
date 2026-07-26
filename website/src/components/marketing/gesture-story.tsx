import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export function GestureStory({ locale }: { locale: Locale }) {
  const { gesture } = getMessages(locale);

  return (
    <section className="section gesture-story" id="workflow">
      <div className="section-heading">
        <p className="eyebrow">{gesture.kicker}</p>
        <h2>{gesture.title}</h2>
        <p>{gesture.body}</p>
      </div>
      <ol className="gesture-list" aria-label={gesture.ariaLabel}>
        {gesture.items.map((item) => (
          <li key={item.action}>
            <span className="gesture-list__arrow" aria-hidden="true">{item.arrow}</span>
            <div>
              <strong>{item.action}</strong>
              <span>{item.detail}</span>
            </div>
          </li>
        ))}
      </ol>
    </section>
  );
}
