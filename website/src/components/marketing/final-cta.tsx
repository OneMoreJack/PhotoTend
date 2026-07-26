import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import Link from "next/link";

export function FinalCta({ locale }: { locale: Locale }) {
  const { finalCta } = getMessages(locale);
  return (
    <section className="final-cta" id="waitlist">
      <div>
        <h2>{finalCta.title}</h2>
        <p>{finalCta.body}</p>
      </div>
      <div className="final-cta__action">
        <Link className="button button--light" href={`/${locale}#waitlist-form`}>
          {finalCta.cta}
          <span aria-hidden="true"> ↗</span>
        </Link>
        <small>{finalCta.privacy}</small>
      </div>
    </section>
  );
}
