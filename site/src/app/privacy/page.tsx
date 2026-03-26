export default function PrivacyPage() {
  return (
    <section className="max-w-[700px] mx-auto px-10 pt-32 pb-20">
      <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-ink2)] block mb-3">
        Legal
      </span>
      <h1 className="font-display text-[clamp(32px,5vw,56px)] leading-none text-[var(--color-ink)] mb-12">
        Privacy Policy.
      </h1>

      <div className="space-y-8 text-[14px] leading-relaxed text-[var(--color-ink2)]">
        <p className="text-[var(--color-ink)]"><strong>Last updated: March 2026</strong></p>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Summary</h2>
          <p>Murmur is designed to be private by default. The free tier processes all text locally on your device. We do not collect, store, or transmit your text.</p>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Data We Collect</h2>
          <p className="mb-2"><strong className="text-[var(--color-ink)]">Free tier:</strong> We collect no data. Zero. The application runs entirely offline.</p>
          <p><strong className="text-[var(--color-ink)]">Pro tier:</strong> When using cloud voices, your text is sent to our servers for synthesis. Text is processed in real-time and not stored after synthesis is complete. We collect:</p>
          <ul className="list-disc list-inside mt-2 space-y-1">
            <li>Account email address</li>
            <li>Subscription status</li>
            <li>Usage metrics (character count per month, for billing)</li>
          </ul>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Auto-Updater</h2>
          <p>Murmur checks for updates by requesting a JSON file from GitHub Releases. This request contains no personal information — only the current app version.</p>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Third-Party Services</h2>
          <p>Pro tier cloud synthesis may use third-party TTS providers (OpenAI, Fish Audio, ElevenLabs). Your text is sent to these providers only when you explicitly use cloud voices. Each provider has their own privacy policy.</p>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Contact</h2>
          <p>Questions? Open an issue on <a href="https://github.com/eleventhavenue/murmur" className="text-[var(--color-ink)] underline" target="_blank">GitHub</a>.</p>
        </div>
      </div>
    </section>
  );
}
