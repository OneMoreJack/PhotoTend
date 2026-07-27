import type { Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";
import { androidDownloadUrl, githubRepositoryUrl } from "@/lib/links";

export function FinalCta({ locale }: { locale: Locale }) {
  const { finalCta } = getMessages(locale);
  return (
    <section className="final-cta" id="open-source">
      <div>
        <h2>{finalCta.title}</h2>
        <p>{finalCta.body}</p>
      </div>
      <div className="final-cta__action">
        <div className="final-cta__buttons">
          <a className="button button--light" href={androidDownloadUrl}>
            {finalCta.download}
          </a>
          <a
            className="button button--outline-light"
            href={githubRepositoryUrl}
          >
            {finalCta.github}
          </a>
        </div>
        <small>{finalCta.license}</small>
      </div>
    </section>
  );
}
