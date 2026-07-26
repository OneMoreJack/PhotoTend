import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export function ImportStory({ locale }: { locale: Locale }) {
  const { imports } = getMessages(locale);

  return (
    <section className="section import-story" id="why">
      <div className="import-flow" aria-hidden="true">
        <div className="import-flow__source"><span>SD</span></div>
        <span className="import-flow__line" />
        <div className="import-flow__book">
          <i /><i /><i />
        </div>
      </div>
      <div className="import-story__copy">
        <p className="eyebrow">{imports.kicker}</p>
        <h2>{imports.title}</h2>
        <p>{imports.body}</p>
        <ul className="source-list" aria-label={imports.ariaLabel}>
          {imports.sources.map((source) => <li key={source}>{source}</li>)}
        </ul>
      </div>
    </section>
  );
}
