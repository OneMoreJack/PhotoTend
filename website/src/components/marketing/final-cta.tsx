import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import { WaitlistForm } from "@/components/waitlist/waitlist-form";

export function FinalCta({ locale }: { locale: Locale }) {
  const { finalCta } = getMessages(locale);
  return (
    <section className="final-cta" id="waitlist">
      <div>
        <h2>{finalCta.title}</h2>
        <p>{finalCta.body}</p>
      </div>
      <div className="final-cta__action">
        <WaitlistForm locale={locale} source="footer" />
        <small>{finalCta.privacy}</small>
      </div>
    </section>
  );
}
