export default function DocsPage() {
  return (
    <section className="max-w-[700px] mx-auto px-10 pt-32 pb-20">
      <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] block mb-3">
        Documentation
      </span>
      <h1 className="font-display text-[clamp(32px,5vw,56px)] leading-none text-[var(--color-ink)] mb-12">
        Getting started.
      </h1>

      <div className="space-y-12 text-[14px] leading-relaxed text-[var(--color-ink2)]">
        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-3">Installation</h2>
          <p className="mb-2">Download the installer from the <a href="/download" className="text-[var(--color-ink)] underline">download page</a> and run it. Murmur installs in seconds and starts automatically.</p>
          <p>Look for the Murmur icon in your system tray (bottom-right of your taskbar).</p>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-3">Usage</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>Highlight any text in any application</li>
            <li>Press <strong className="text-[var(--color-ink)]">Ctrl+Alt+M</strong></li>
            <li>A floating bar appears and audio starts playing</li>
          </ol>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-3">Controls</h2>
          <table className="w-full text-[13px]">
            <tbody>
              <tr className="border-b border-[var(--color-ink3)]">
                <td className="py-2 font-bold text-[var(--color-ink)]">Ctrl+Alt+M</td>
                <td className="py-2">Read highlighted text aloud</td>
              </tr>
              <tr className="border-b border-[var(--color-ink3)]">
                <td className="py-2 font-bold text-[var(--color-ink)]">Play/Pause button</td>
                <td className="py-2">Toggle playback</td>
              </tr>
              <tr className="border-b border-[var(--color-ink3)]">
                <td className="py-2 font-bold text-[var(--color-ink)]">Speed badge</td>
                <td className="py-2">Cycle: 0.75x → 1x → 1.25x → 1.5x → 2x → 2.5x → 3x</td>
              </tr>
              <tr className="border-b border-[var(--color-ink3)]">
                <td className="py-2 font-bold text-[var(--color-ink)]">Escape / X button</td>
                <td className="py-2">Stop and close the bar</td>
              </tr>
              <tr className="border-b border-[var(--color-ink3)]">
                <td className="py-2 font-bold text-[var(--color-ink)]">Tray → Quit</td>
                <td className="py-2">Exit Murmur completely</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-3">Voices</h2>
          <p className="mb-3">Murmur ships with 27 voices across 4 groups:</p>
          <div className="grid grid-cols-2 gap-4 text-[13px]">
            <div>
              <h3 className="font-bold text-[var(--color-ink)] mb-1">American Female (11)</h3>
              <p>Alloy, Aoede, Bella, Heart, Jessica, Kore, Nicole, Nova, River, Sarah, Sky</p>
            </div>
            <div>
              <h3 className="font-bold text-[var(--color-ink)] mb-1">American Male (8)</h3>
              <p>Adam, Echo, Eric, Fenrir, Liam, Michael, Onyx, Puck</p>
            </div>
            <div>
              <h3 className="font-bold text-[var(--color-ink)] mb-1">British Female (4)</h3>
              <p>Alice, Emma, Isabella, Lily</p>
            </div>
            <div>
              <h3 className="font-bold text-[var(--color-ink)] mb-1">British Male (4)</h3>
              <p>Daniel, Fable, George, Lewis</p>
            </div>
          </div>
        </div>

        <div>
          <h2 className="text-lg font-bold text-[var(--color-ink)] mb-3">FAQ</h2>
          <div className="space-y-4">
            <div>
              <h3 className="font-bold text-[var(--color-ink)]">Does it need the internet?</h3>
              <p>No. The free tier runs 100% offline using the kokoro TTS engine on your device.</p>
            </div>
            <div>
              <h3 className="font-bold text-[var(--color-ink)]">Is my text sent anywhere?</h3>
              <p>No. Your text never leaves your machine. Everything is processed locally.</p>
            </div>
            <div>
              <h3 className="font-bold text-[var(--color-ink)]">What are the system requirements?</h3>
              <p>Windows 10+ (64-bit), 4GB RAM minimum. Works best with a modern CPU (4+ cores). GPU is optional but helps performance.</p>
            </div>
            <div>
              <h3 className="font-bold text-[var(--color-ink)]">Is it open source?</h3>
              <p>Yes. Murmur is open source on <a href="https://github.com/eleventhavenue/murmur" className="text-[var(--color-ink)] underline" target="_blank">GitHub</a>.</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
