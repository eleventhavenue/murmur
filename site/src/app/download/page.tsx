import Link from "next/link";

export default function DownloadPage() {
  return (
    <section className="min-h-screen flex flex-col justify-center items-center px-10 pt-32 pb-20 text-center">
      <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] mb-3">
        Download
      </span>
      <h1 className="font-display text-[clamp(40px,7vw,72px)] leading-[0.95] text-[var(--color-ink)] mb-4">
        Get Murmur.
      </h1>
      <p className="text-base text-[var(--color-ink2)] max-w-[440px] leading-relaxed mb-12">
        Free, open source, runs entirely on your device. No account needed.
      </p>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-[800px] w-full mb-16">
        {/* Windows */}
        <div className="border border-[var(--color-ink3)] rounded-xl p-8 flex flex-col items-center">
          <span className="text-4xl mb-4">🪟</span>
          <h3 className="text-[15px] font-bold mb-2">Windows</h3>
          <p className="text-[13px] text-[var(--color-ink2)] mb-6">Windows 10+ (64-bit)</p>
          <Link
            href="https://github.com/eleventhavenue/murmur/releases/latest"
            className="w-full block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide bg-[var(--color-surface)] text-[var(--color-surface-text)] no-underline hover:opacity-90 transition-opacity"
          >
            Download .exe
          </Link>
        </div>
        {/* macOS */}
        <div className="border border-[var(--color-ink3)] rounded-xl p-8 flex flex-col items-center opacity-60">
          <span className="text-4xl mb-4">🍎</span>
          <h3 className="text-[15px] font-bold mb-2">macOS</h3>
          <p className="text-[13px] text-[var(--color-ink2)] mb-6">Apple Silicon + Intel</p>
          <span className="w-full block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide border border-[var(--color-ink3)] text-[var(--color-ink)] cursor-default">
            Coming Soon
          </span>
        </div>
        {/* Linux */}
        <div className="border border-[var(--color-ink3)] rounded-xl p-8 flex flex-col items-center opacity-60">
          <span className="text-4xl mb-4">🐧</span>
          <h3 className="text-[15px] font-bold mb-2">Linux</h3>
          <p className="text-[13px] text-[var(--color-ink2)] mb-6">AppImage / .deb</p>
          <span className="w-full block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide border border-[var(--color-ink3)] text-[var(--color-ink)] cursor-default">
            Coming Soon
          </span>
        </div>
      </div>

      <div className="max-w-[600px] text-left">
        <h2 className="font-display text-2xl text-[var(--color-ink)] mb-4">Quick Start</h2>
        <ol className="space-y-4 text-[13px] text-[var(--color-ink2)] leading-relaxed list-decimal list-inside">
          <li>Download and run the installer</li>
          <li>Look for the Murmur icon in your system tray</li>
          <li>Highlight any text in any app</li>
          <li>Press <strong className="text-[var(--color-ink)]">Ctrl+Alt+M</strong> to hear it read aloud</li>
        </ol>
      </div>
    </section>
  );
}
