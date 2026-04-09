import Image from "next/image";

const colors = [
  { name: "Ink", hex: "#1f3a33", text: "white", desc: "Primary text, headings, controls" },
  { name: "Bone", hex: "#f3f2ec", text: "#1f3a33", desc: "Background" },
  { name: "Yellow", hex: "#dcd444", text: "#1f3a33", desc: "Accent, CTAs, highlights" },
  { name: "Sand", hex: "#aba697", text: "white", desc: "Secondary text, muted elements" },
  { name: "Surface", hex: "#1a1a1a", text: "white", desc: "Dark UI surfaces, buttons" },
  { name: "Lilac", hex: "#9B8EC4", text: "white", desc: "Alternative accent (Lilac theme)" },
];

const logos = [
  { name: "The Ripple", file: "concept1-icon-ripple", desc: "Sound waves from a point — the visual shape of a whisper spreading" },
  { name: "The Breath", file: "concept2-icon-breath", desc: "Flowing 'm' letterform — like a breath rising" },
  { name: "The Quote Wave", file: "concept3-icon-quotewave", desc: "Quotation marks dissolving into sound waves" },
  { name: "The Waveform M", file: "concept4-icon-waveform-m", desc: "M as audio waveform — distinctive, scales well" },
  { name: "The Pulse", file: "concept5-icon-pulse", desc: "Audio heartbeat — ultra-minimal, technical" },
];

const combined = [
  { name: "Combined — Ripple", file: "combined-ripple" },
  { name: "Combined — Pulse", file: "combined-pulse" },
];

const wordmarks = [
  { name: "Wordmark (Light)", file: "wordmark-light", bg: "#1a1a1a" },
  { name: "Wordmark (Gold)", file: "wordmark-gold", bg: "#1a1a1a" },
];

export default function BrandPage() {
  return (
    <section className="max-w-[1000px] mx-auto px-10 pt-32 pb-20">
      <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] block mb-3">
        Brand Kit
      </span>
      <h1 className="font-display text-[clamp(32px,5vw,56px)] leading-none text-[var(--color-ink)] mb-4">
        Murmur Brand.
      </h1>
      <p className="text-base text-[var(--color-ink2)] max-w-[500px] leading-relaxed mb-16">
        Everything you need to represent Murmur. Download assets, reference colors, and follow our guidelines.
      </p>

      {/* Brand Personality */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-4">Brand Personality</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {["Quiet", "Intimate", "Elegant", "Premium"].map((word) => (
            <div key={word} className="border border-[var(--color-ink3)] rounded-lg p-6 text-center">
              <span className="font-display text-2xl text-[var(--color-ink)]">{word}</span>
            </div>
          ))}
        </div>
        <p className="text-[13px] text-[var(--color-ink2)] mt-4 italic">
          Like a whisper made visible.
        </p>
      </div>

      {/* Color Palette */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-6">Color Palette</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
          {colors.map((c) => (
            <div key={c.name} className="rounded-xl overflow-hidden border border-[var(--color-ink3)]">
              <div className="h-24 flex items-end p-4" style={{ backgroundColor: c.hex }}>
                <span className="text-sm font-bold" style={{ color: c.text }}>{c.name}</span>
              </div>
              <div className="p-4 bg-white">
                <code className="text-xs font-mono text-[var(--color-ink)]">{c.hex}</code>
                <p className="text-[11px] text-[var(--color-ink2)] mt-1">{c.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Typography */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-6">Typography</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="border border-[var(--color-ink3)] rounded-xl p-8">
            <span className="text-[10px] font-bold uppercase tracking-widest text-[var(--color-ink2)] block mb-4">Display</span>
            <p className="font-display text-5xl text-[var(--color-ink)]">murmur.</p>
            <p className="text-[13px] text-[var(--color-ink2)] mt-4">
              Instrument Serif, 400 weight<br />
              Letter spacing: -0.03em<br />
              All lowercase, period at end
            </p>
          </div>
          <div className="border border-[var(--color-ink3)] rounded-xl p-8">
            <span className="text-[10px] font-bold uppercase tracking-widest text-[var(--color-ink2)] block mb-4">Body</span>
            <p className="text-lg text-[var(--color-ink)]">The quick brown fox jumps over the lazy dog.</p>
            <p className="text-[13px] text-[var(--color-ink2)] mt-4">
              Inter, 400/500/600/700 weights<br />
              Letter spacing: normal<br />
              Used for all body text and UI
            </p>
          </div>
        </div>
      </div>

      {/* Wordmark */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Wordmark</h2>
        <p className="text-[13px] text-[var(--color-ink2)] mb-6">Always lowercase. Always with a period. Never capitalize, never bold.</p>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {wordmarks.map((w) => (
            <div key={w.name} className="rounded-xl overflow-hidden border border-[var(--color-ink3)]">
              <div className="p-8 flex items-center justify-center" style={{ backgroundColor: w.bg }}>
                <Image src={`/brand/${w.file}.png`} alt={w.name} width={400} height={80} className="object-contain h-12" unoptimized />
              </div>
              <div className="p-4 bg-white flex justify-between items-center">
                <span className="text-xs text-[var(--color-ink2)]">{w.name}</span>
                <a href={`/brand/${w.file}.svg`} download className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-accent)] no-underline hover:opacity-70">
                  SVG
                </a>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Logo Concepts */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Logo Concepts</h2>
        <p className="text-[13px] text-[var(--color-ink2)] mb-6">Five icon mark concepts. Click SVG to download.</p>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
          {logos.map((l) => (
            <div key={l.name} className="border border-[var(--color-ink3)] rounded-xl overflow-hidden">
              <div className="p-4 flex items-center justify-center bg-[#0a0a0a]">
                <Image src={`/brand/${l.file}.png`} alt={l.name} width={120} height={120} className="object-contain w-20 h-20" unoptimized />
              </div>
              <div className="p-3">
                <p className="text-xs font-bold text-[var(--color-ink)]">{l.name}</p>
                <p className="text-[10px] text-[var(--color-ink2)] mt-1 leading-snug">{l.desc}</p>
                <div className="flex gap-2 mt-2">
                  <a href={`/brand/${l.file}.svg`} download className="text-[9px] font-bold uppercase tracking-wide text-[var(--color-accent)] no-underline hover:opacity-70">SVG</a>
                  <a href={`/brand/${l.file}.png`} download className="text-[9px] font-bold uppercase tracking-wide text-[var(--color-ink2)] no-underline hover:opacity-70">PNG</a>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Combined Marks */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-6">Combined Marks</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {combined.map((c) => (
            <div key={c.name} className="border border-[var(--color-ink3)] rounded-xl overflow-hidden">
              <div className="p-8 flex items-center justify-center bg-[#0a0a0a]">
                <Image src={`/brand/${c.file}.png`} alt={c.name} width={500} height={120} className="object-contain h-14" unoptimized />
              </div>
              <div className="p-4 bg-white flex justify-between items-center">
                <span className="text-xs text-[var(--color-ink2)]">{c.name}</span>
                <div className="flex gap-3">
                  <a href={`/brand/${c.file}.svg`} download className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-accent)] no-underline hover:opacity-70">SVG</a>
                  <a href={`/brand/${c.file}.png`} download className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-ink2)] no-underline hover:opacity-70">PNG</a>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Usage Guidelines */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-6">Usage Guidelines</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div>
            <h3 className="text-sm font-bold text-[var(--color-ink)] mb-3">Do</h3>
            <ul className="space-y-2 text-[13px] text-[var(--color-ink2)]">
              <li>→ Use the wordmark in lowercase with period: <strong className="text-[var(--color-ink)]">murmur.</strong></li>
              <li>→ Maintain clear space around the logo (min: logo height)</li>
              <li>→ Use on light backgrounds (bone, white) or dark backgrounds (surface, black)</li>
              <li>→ Use Instrument Serif for display, Inter for body</li>
            </ul>
          </div>
          <div>
            <h3 className="text-sm font-bold text-[var(--color-ink)] mb-3">Don&apos;t</h3>
            <ul className="space-y-2 text-[13px] text-[var(--color-ink2)]">
              <li>→ Don&apos;t capitalize: <s>Murmur</s>, <s>MURMUR</s></li>
              <li>→ Don&apos;t remove the period: <s>murmur</s></li>
              <li>→ Don&apos;t add effects (shadows, glows, gradients)</li>
              <li>→ Don&apos;t stretch, rotate, or skew the logo</li>
            </ul>
          </div>
        </div>
      </div>

      {/* Taglines */}
      <div>
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-4">Taglines</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {[
            "Your text, read beautifully.",
            "Listen to anything.",
            "Hear your words.",
            "Text to speech, done right.",
          ].map((t) => (
            <div key={t} className="border border-[var(--color-ink3)] rounded-lg p-6">
              <p className="font-display text-xl text-[var(--color-ink)] italic">{t}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
