import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export function Philosophy({ locale }: { locale: Locale }) {
  const { philosophy } = getMessages(locale);
  return (
    <section className="philosophy">
      <span className="philosophy__quote" aria-hidden="true">“</span>
      <div>
        <h2>{philosophy.title}</h2>
        <p>{philosophy.body}</p>
      </div>
    </section>
  );
}
