import Link from "next/link";
import { HeroViz } from "@/components/hero-viz";
import { PillWave } from "@/components/pill-wave";

const features = [
  { icon: "⌨️", title: "Global Hotkey", desc: "Ctrl+Alt+M from anywhere. Highlight text in any app — browser, PDF, IDE — and hear it instantly." },
  { icon: "🔒", title: "100% Local", desc: "Your text never leaves your machine. Runs entirely offline with the kokoro engine. No cloud, no tracking." },
  { icon: "🎙️", title: "27 Voices", desc: "American, British, male, female. From warm and intimate to clear and professional. Pick your narrator." },
  { icon: "⚡", title: "Speed Control", desc: "0.75x to 3x playback. Cycle through speeds with one click. Read faster without losing comprehension." },
  { icon: "🪶", title: "Tiny Footprint", desc: "12MB installer. No Electron bloat. Built with Tauri and Rust — fast startup, low memory, native performance." },
  { icon: "🔄", title: "Auto Updates", desc: "New versions delivered silently. One-click update when a new release drops. Always running the latest." },
];

const steps = [
  { title: "Highlight text", desc: "Select any text in any application. A webpage, a PDF, an email, your code editor — anywhere." },
  { title: "Press the hotkey", desc: "Ctrl+Alt+M grabs the selection and sends it to the local TTS engine. No copy-paste needed." },
  { title: "Listen", desc: "Audio streams through your speakers in real time. Pause, speed up, or close with the floating bar." },
];

export default function Home() {
  return (
    <>
      {/* Hero */}
      <section className="min-h-screen flex flex-col justify-center items-center px-10 pt-32 pb-20 text-center">
        <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] mb-3">
          Open-source TTS Engine
        </span>
        <h1 className="font-display text-[clamp(64px,12vw,140px)] leading-[0.9] text-[var(--color-ink)] mb-6">
          murmur.
        </h1>
        <p className="text-base text-[var(--color-ink2)] max-w-[440px] leading-relaxed mb-12">
          Highlight any text. Press a hotkey. Hear it read beautifully — right
          on your device, no internet needed.
        </p>

        <HeroViz />

        {/* Floating pill */}
        <div className="inline-flex items-center gap-4 bg-[var(--color-surface)] rounded-[14px] px-5 py-3.5 shadow-[0_20px_40px_rgba(0,0,0,0.12)] hover:-translate-y-0.5 transition-transform cursor-pointer">
          <svg className="w-4 h-4 fill-white" viewBox="0 0 24 24">
            <path d="M6 4h4v16H6zm8 0h4v16h-4z" />
          </svg>
          <PillWave />
          <span className="text-[10px] font-semibold text-white/40 tabular-nums">1.2x</span>
          <span className="text-xs font-semibold text-white tracking-wide">Playing</span>
          <span className="text-[10px] font-bold text-white/25 bg-white/8 px-2 py-1 rounded">
            Ctrl+Alt+M
          </span>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="px-10 py-28">
        <div className="max-w-[1000px] mx-auto">
          <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] block mb-3">
            Features
          </span>
          <h2 className="font-display text-[clamp(32px,5vw,56px)] leading-none text-[var(--color-ink)] mb-12">
            Everything you need.
            <br />
            Nothing you don&apos;t.
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {features.map((f) => (
              <div
                key={f.title}
                className="p-8 border border-[var(--color-ink3)] rounded-xl hover:border-[var(--color-accent)] hover:bg-[rgba(31,58,51,0.03)] transition-all"
              >
                <div className="w-10 h-10 rounded-[10px] bg-[rgba(31,58,51,0.06)] flex items-center justify-center mb-5 text-lg">
                  {f.icon}
                </div>
                <h3 className="text-[15px] font-bold mb-2">{f.title}</h3>
                <p className="text-[13px] leading-relaxed text-[var(--color-ink2)]">
                  {f.desc}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How it works */}
      <section className="px-10 py-28">
        <div className="max-w-[1000px] mx-auto">
          <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] block mb-3">
            How it works
          </span>
          <h2 className="font-display text-[clamp(32px,5vw,56px)] leading-none text-[var(--color-ink)] mb-12">
            Three seconds
            <br />
            to audio.
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-12">
            {steps.map((s, i) => (
              <div key={s.title}>
                <span className="text-5xl font-black text-[var(--color-ink3)] block mb-4">
                  {String(i + 1).padStart(2, "0")}
                </span>
                <h3 className="text-[15px] font-bold mb-2">{s.title}</h3>
                <p className="text-[13px] leading-relaxed text-[var(--color-ink2)]">
                  {s.desc}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Pricing preview */}
      <section id="pricing" className="px-10 py-28">
        <div className="max-w-[1000px] mx-auto">
          <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] block mb-3">
            Pricing
          </span>
          <h2 className="font-display text-[clamp(32px,5vw,56px)] leading-none text-[var(--color-ink)] mb-12">
            Free forever.
            <br />
            Pro when you want it.
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Free */}
            <div className="border border-[var(--color-ink3)] rounded-xl p-9 flex flex-col">
              <span className="text-[13px] font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-2">Free</span>
              <span className="font-display text-5xl text-[var(--color-ink)] mb-1">$0</span>
              <span className="text-xs text-[var(--color-ink2)] mb-6">forever</span>
              <ul className="flex-1 mb-8 list-none p-0">
                {["27 local voices", "Unlimited usage", "100% offline", "Open source", "Auto updates"].map((f) => (
                  <li key={f} className="text-[13px] text-[var(--color-ink2)] py-2 border-b border-[var(--color-ink3)]">
                    <span className="text-[var(--color-accent)]">→ </span>{f}
                  </li>
                ))}
              </ul>
              <Link href="/download" className="block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide border border-[var(--color-ink3)] text-[var(--color-ink)] hover:bg-[var(--color-ink)] hover:text-[var(--color-bg)] transition-all no-underline">
                Download Free
              </Link>
            </div>
            {/* Pro */}
            <div className="border border-[var(--color-accent)] rounded-xl p-9 flex flex-col bg-[rgba(31,58,51,0.03)] relative">
              <span className="absolute -top-2.5 left-7 bg-[var(--color-accent)] text-[var(--color-bg)] text-[9px] font-extrabold uppercase tracking-widest px-2.5 py-1 rounded">Most Popular</span>
              <span className="text-[13px] font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-2">Pro</span>
              <span className="font-display text-5xl text-[var(--color-ink)] mb-1">$8</span>
              <span className="text-xs text-[var(--color-ink2)] mb-6">per month</span>
              <ul className="flex-1 mb-8 list-none p-0">
                {["Everything in Free", "Premium cloud voices", "80+ languages", "Voice cloning", "Emotion control"].map((f) => (
                  <li key={f} className="text-[13px] text-[var(--color-ink2)] py-2 border-b border-[var(--color-ink3)]">
                    <span className="text-[var(--color-accent)]">→ </span>{f}
                  </li>
                ))}
              </ul>
              <span className="block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide bg-[var(--color-surface)] text-[var(--color-surface-text)] cursor-default opacity-60">
                Coming Soon
              </span>
            </div>
            {/* Pro+ */}
            <div className="border border-[var(--color-ink3)] rounded-xl p-9 flex flex-col">
              <span className="text-[13px] font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-2">Pro+</span>
              <span className="font-display text-5xl text-[var(--color-ink)] mb-1">$16</span>
              <span className="text-xs text-[var(--color-ink2)] mb-6">per month</span>
              <ul className="flex-1 mb-8 list-none p-0">
                {["Everything in Pro", "ElevenLabs voices", "Ultra-realistic quality", "Priority synthesis", "API access"].map((f) => (
                  <li key={f} className="text-[13px] text-[var(--color-ink2)] py-2 border-b border-[var(--color-ink3)]">
                    <span className="text-[var(--color-accent)]">→ </span>{f}
                  </li>
                ))}
              </ul>
              <span className="block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide border border-[var(--color-ink3)] text-[var(--color-ink)] cursor-default opacity-60">
                Coming Soon
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section id="download" className="text-center py-40 px-10">
        <h2 className="font-display text-[clamp(40px,7vw,80px)] leading-[0.95] text-[var(--color-ink)] mb-6">
          Hear your
          <br />
          words.
        </h2>
        <p className="text-sm text-[var(--color-ink2)] mb-10">
          Free, open source, and runs entirely on your device.
        </p>
        <Link
          href="https://github.com/eleventhavenue/murmur/releases/latest"
          className="inline-flex items-center gap-2.5 bg-[var(--color-surface)] text-[var(--color-surface-text)] px-8 py-4 rounded-xl text-sm font-bold shadow-[0_10px_30px_rgba(0,0,0,0.15)] hover:-translate-y-0.5 transition-transform no-underline"
        >
          <svg className="w-[18px] h-[18px] fill-current" viewBox="0 0 24 24">
            <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z" />
          </svg>
          Download for Windows
        </Link>
        <p className="text-[11px] text-[var(--color-ink2)] mt-3">
          macOS and Linux coming soon
        </p>
      </section>
    </>
  );
}
