import Link from "next/link";

export default function DownloadPage() {
  return (
    <section className="max-w-[900px] mx-auto px-10 pt-32 pb-20">
      <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] block mb-3 text-center">
        Download
      </span>
      <h1 className="font-display text-[clamp(40px,7vw,72px)] leading-[0.95] text-[var(--color-ink)] mb-4 text-center">
        Get Murmur.
      </h1>
      <p className="text-base text-[var(--color-ink2)] max-w-[500px] leading-relaxed mb-12 mx-auto text-center">
        Free, open source, runs entirely on your device. No account needed. Around 400MB download (includes the TTS engine).
      </p>

      {/* Platform cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-20">
        <div className="border border-[var(--color-ink3)] rounded-xl p-8 flex flex-col items-center">
          <span className="text-4xl mb-4">🪟</span>
          <h3 className="text-[15px] font-bold mb-1">Windows</h3>
          <p className="text-[12px] text-[var(--color-ink2)] mb-6">Windows 10 or later · 64-bit</p>
          <Link
            href="https://github.com/eleventhavenue/murmur/releases/latest/download/Murmur_0.2.0_x64-setup.exe"
            className="w-full block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide bg-[var(--color-surface)] text-[var(--color-surface-text)] no-underline hover:opacity-90 transition-opacity"
          >
            Download .exe
          </Link>
          <Link
            href="https://github.com/eleventhavenue/murmur/releases/latest"
            className="text-[10px] text-[var(--color-ink2)] mt-2 hover:text-[var(--color-ink)] no-underline"
          >
            or .msi / other versions →
          </Link>
        </div>
        <div className="border border-[var(--color-ink3)] rounded-xl p-8 flex flex-col items-center opacity-50">
          <span className="text-4xl mb-4">🍎</span>
          <h3 className="text-[15px] font-bold mb-1">macOS</h3>
          <p className="text-[12px] text-[var(--color-ink2)] mb-6">Apple Silicon + Intel</p>
          <span className="w-full block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide border border-[var(--color-ink3)] text-[var(--color-ink)] cursor-default">
            Coming Soon
          </span>
        </div>
        <div className="border border-[var(--color-ink3)] rounded-xl p-8 flex flex-col items-center opacity-50">
          <span className="text-4xl mb-4">🐧</span>
          <h3 className="text-[15px] font-bold mb-1">Linux</h3>
          <p className="text-[12px] text-[var(--color-ink2)] mb-6">AppImage / .deb</p>
          <span className="w-full block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide border border-[var(--color-ink3)] text-[var(--color-ink)] cursor-default">
            Coming Soon
          </span>
        </div>
      </div>

      {/* Install Instructions */}
      <div className="mb-20">
        <h2 className="font-display text-3xl text-[var(--color-ink)] mb-3">How to install.</h2>
        <p className="text-[13px] text-[var(--color-ink2)] mb-8">A few steps, then you&apos;re done.</p>

        <ol className="space-y-8 list-none p-0">
          <li className="flex gap-6">
            <span className="font-display text-3xl text-[var(--color-accent)] shrink-0 w-10">1</span>
            <div>
              <h3 className="text-[14px] font-bold text-[var(--color-ink)] mb-1">Download the installer</h3>
              <p className="text-[13px] text-[var(--color-ink2)] leading-relaxed">
                Click the Windows button above. The installer is around 400MB — it includes the full TTS engine, so it may take a minute to download.
              </p>
            </div>
          </li>

          <li className="flex gap-6">
            <span className="font-display text-3xl text-[var(--color-accent)] shrink-0 w-10">2</span>
            <div>
              <h3 className="text-[14px] font-bold text-[var(--color-ink)] mb-1">Run the installer</h3>
              <p className="text-[13px] text-[var(--color-ink2)] leading-relaxed mb-2">
                Double-click <code className="bg-[var(--color-ink3)] px-1.5 py-0.5 rounded text-[12px]">Murmur_0.2.0_x64-setup.exe</code>.
              </p>
              <div className="bg-[rgba(220,212,68,0.12)] border-l-2 border-[var(--color-accent)] p-4 rounded-r">
                <p className="text-[12px] text-[var(--color-ink)] font-semibold mb-1">Windows Defender warning?</p>
                <p className="text-[12px] text-[var(--color-ink2)] leading-relaxed">
                  Windows will show a blue &quot;Windows protected your PC&quot; screen because we haven&apos;t paid for code signing yet. This is normal for new open-source apps.
                </p>
                <p className="text-[12px] text-[var(--color-ink2)] mt-2 leading-relaxed">
                  Click <strong className="text-[var(--color-ink)]">More info</strong>, then <strong className="text-[var(--color-ink)]">Run anyway</strong>.
                </p>
              </div>
            </div>
          </li>

          <li className="flex gap-6">
            <span className="font-display text-3xl text-[var(--color-accent)] shrink-0 w-10">3</span>
            <div>
              <h3 className="text-[14px] font-bold text-[var(--color-ink)] mb-1">Look for the icon in your system tray</h3>
              <p className="text-[13px] text-[var(--color-ink2)] leading-relaxed">
                After install, Murmur runs in the background. Find the green <strong>m</strong> icon in your system tray (bottom-right of your taskbar, may be behind the &quot;^&quot; arrow).
              </p>
            </div>
          </li>

          <li className="flex gap-6">
            <span className="font-display text-3xl text-[var(--color-accent)] shrink-0 w-10">4</span>
            <div>
              <h3 className="text-[14px] font-bold text-[var(--color-ink)] mb-1">Try it</h3>
              <p className="text-[13px] text-[var(--color-ink2)] leading-relaxed mb-2">
                Highlight any text anywhere — a webpage, a PDF, an email. Press{" "}
                <kbd className="bg-[var(--color-ink)] text-[var(--color-bg)] px-2 py-0.5 rounded text-[11px] font-mono">Ctrl+Alt+M</kbd>.
              </p>
              <p className="text-[13px] text-[var(--color-ink2)] leading-relaxed">
                A small bar will appear and audio will start playing. The first time takes 5–10 seconds while the engine warms up. After that, it&apos;s instant.
              </p>
            </div>
          </li>
        </ol>
      </div>

      {/* Quick Reference */}
      <div className="mb-20">
        <h2 className="font-display text-3xl text-[var(--color-ink)] mb-6">Quick reference.</h2>
        <div className="border border-[var(--color-ink3)] rounded-xl overflow-hidden">
          <table className="w-full text-[13px]">
            <tbody>
              {[
                ["Read highlighted text", "Ctrl+Alt+M"],
                ["Play / Pause", "Space"],
                ["Skip back 15s", "←"],
                ["Skip forward 15s", "→"],
                ["Stop and close", "Escape"],
                ["Change voice", "Right-click tray → Voice"],
                ["Change design", "Right-click tray → Design"],
                ["Quit Murmur", "Right-click tray → Quit"],
              ].map(([action, shortcut], i) => (
                <tr key={action} className={i !== 7 ? "border-b border-[var(--color-ink3)]" : ""}>
                  <td className="py-3 px-4 text-[var(--color-ink2)]">{action}</td>
                  <td className="py-3 px-4 font-mono text-[var(--color-ink)] text-right">{shortcut}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Troubleshooting */}
      <div className="mb-20">
        <h2 className="font-display text-3xl text-[var(--color-ink)] mb-6">Troubleshooting.</h2>
        <div className="space-y-6 text-[13px]">
          <div>
            <h3 className="font-bold text-[var(--color-ink)] mb-1">Nothing happens when I press Ctrl+Alt+M</h3>
            <p className="text-[var(--color-ink2)] leading-relaxed">
              Make sure you actually highlighted some text first. Also check that no other app (like Macrium Reflect or Google Meet) is using the same shortcut — you&apos;ll need to close that app or change its hotkey.
            </p>
          </div>
          <div>
            <h3 className="font-bold text-[var(--color-ink)] mb-1">It says &quot;Sidecar is dead&quot;</h3>
            <p className="text-[var(--color-ink2)] leading-relaxed">
              Quit Murmur from the tray menu and relaunch it from the Start menu. The TTS engine crashed — usually a one-time fluke. If it keeps happening, <a href="https://github.com/eleventhavenue/murmur/issues" className="text-[var(--color-ink)] underline">open an issue on GitHub</a>.
            </p>
          </div>
          <div>
            <h3 className="font-bold text-[var(--color-ink)] mb-1">The first read takes forever</h3>
            <p className="text-[var(--color-ink2)] leading-relaxed">
              The first press of Ctrl+Alt+M loads a 300MB AI model into memory. This takes 5–10 seconds on most machines. All subsequent reads are near-instant because the model stays loaded.
            </p>
          </div>
          <div>
            <h3 className="font-bold text-[var(--color-ink)] mb-1">I want to uninstall</h3>
            <p className="text-[var(--color-ink2)] leading-relaxed">
              Windows Settings → Apps → Installed Apps → search &quot;Murmur&quot; → Uninstall. No data or telemetry stays behind.
            </p>
          </div>
        </div>
      </div>

      {/* Footer links */}
      <div className="text-center text-[12px] text-[var(--color-ink2)]">
        <p>Open source under Apache 2.0 · <Link href="https://github.com/eleventhavenue/murmur" className="text-[var(--color-ink)] underline" target="_blank">View on GitHub</Link></p>
      </div>
    </section>
  );
}
