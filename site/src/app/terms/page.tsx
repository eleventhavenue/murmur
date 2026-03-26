export default function TermsPage() {
  return (
    <section className="max-w-[700px] mx-auto px-10 pt-32 pb-20">
      <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-ink2)] block mb-3">
        Legal
      </span>
      <h1 className="font-display text-[clamp(32px,5vw,56px)] leading-none text-[var(--color-ink)] mb-12">
        Terms of Service.
      </h1>

      <div className="space-y-8 text-[14px] leading-relaxed text-[var(--color-ink2)]">
        <p className="text-[var(--color-ink)]"><strong>Last updated: March 2026</strong></p>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Free Tier</h2>
          <p>The free version of Murmur is provided as-is under the Apache 2.0 open source license. You may use it for any purpose — personal, educational, or commercial.</p>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Pro Subscription</h2>
          <p className="mb-2">Pro and Pro+ subscriptions are billed monthly through Stripe. You may cancel at any time — your access continues until the end of the billing period.</p>
          <p>Refunds are available within 7 days of your first payment if you are not satisfied.</p>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Acceptable Use</h2>
          <p>You agree not to use Murmur&apos;s cloud services to:</p>
          <ul className="list-disc list-inside mt-2 space-y-1">
            <li>Generate content that impersonates real individuals without consent</li>
            <li>Produce content that is illegal in your jurisdiction</li>
            <li>Attempt to reverse-engineer or extract cloud voice models</li>
            <li>Exceed reasonable usage limits (automated bulk synthesis)</li>
          </ul>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Limitation of Liability</h2>
          <p>Murmur is provided as-is without warranty. We are not liable for any damages arising from the use of the software or services.</p>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Changes</h2>
          <p>We may update these terms. Continued use after changes constitutes acceptance.</p>
        </div>
      </div>
    </section>
  );
}
