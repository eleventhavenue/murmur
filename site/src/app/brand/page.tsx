"use client";

import Image from "next/image";
import { useEffect, useRef } from "react";

const colors = [
  { name: "Ink", hex: "#1f3a33", text: "#f3f2ec", desc: "Primary — text, surfaces, icons" },
  { name: "Bone", hex: "#f3f2ec", text: "#1f3a33", desc: "Background" },
  { name: "Yellow", hex: "#dcd444", text: "#1f3a33", desc: "Accent — highlights, CTAs" },
  { name: "Sand", hex: "#aba697", text: "#f3f2ec", desc: "Muted — secondary text, borders" },
];

function BrandMark() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    const numBars = 120;
    const vw = 1000, vh = 240;
    const bw = vw / numBars;
    const gap = 1.5;

    let rects = "";
    for (let i = 0; i < numBars; i++) {
      const x = i * bw;
      const nx = i / numBars;
      const slow = Math.sin(nx * Math.PI * 2);
      const fast = Math.sin(nx * Math.PI * 6) * 0.5;
      const combined = (slow + fast) / 1.5;
      const del = nx * -6;
      const dur = 5.5 + Math.random() * 1.5;
      const smin = 0.1 + Math.abs(fast) * 0.2;
      const smax = 0.4 + Math.abs(combined) * 0.6;
      const isAccent = i % 5 === 0;
      const fill = isAccent ? "#dcd444" : "#1f3a33";
      rects += `<rect fill="${fill}" x="${x}" y="0" width="${bw - gap}" height="100%" style="transform-box:fill-box;transform-origin:center;animation:brandWave ${dur}s cubic-bezier(0.4,0,0.2,1) infinite alternate;animation-delay:${del}s;--smin:${smin};--smax:${smax}"/>`;
    }

    ref.current.innerHTML = `
      <style>
        @keyframes brandWave {
          0% { transform: scaleY(var(--smin, 0.15)); }
          100% { transform: scaleY(var(--smax, 1)); }
        }
      </style>
      <svg viewBox="0 0 ${vw} ${vh}" preserveAspectRatio="xMidYMid meet" class="w-full h-full">
        <defs>
          <clipPath id="brandMask">
            <text x="50%" y="70%" text-anchor="middle" font-family="'Instrument Serif', serif" font-weight="400" font-size="220px" letter-spacing="-0.02em">murmur.</text>
          </clipPath>
        </defs>
        <g clip-path="url(#brandMask)">${rects}</g>
      </svg>
    `;
  }, []);

  return <div ref={ref} className="w-full max-w-[800px] h-[200px] overflow-hidden" />;
}

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
        One cohesive identity. Download assets, reference colors, follow the guidelines.
      </p>

      {/* The Mark */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">The Mark</h2>
        <p className="text-[13px] text-[var(--color-ink2)] mb-6">
          An animated waveform flowing inside an Instrument Serif wordmark. The bars and the letters are one.
        </p>
        <div className="border border-[var(--color-ink3)] rounded-xl p-12 flex items-center justify-center bg-[var(--color-bg)]">
          <BrandMark />
        </div>
      </div>

      {/* Icon */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-2">Icon</h2>
        <p className="text-[13px] text-[var(--color-ink2)] mb-6">
          A compressed single-letter mark for favicons, app icons, social avatars. The same bars-inside-type concept, scaled down.
        </p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
          {[512, 256, 128, 64].map((size) => (
            <div key={size} className="rounded-xl overflow-hidden border border-[var(--color-ink3)]">
              <div className="p-8 flex items-center justify-center bg-[var(--color-bg)]">
                <Image src={`/brand/murmur-icon-${size}.png`} alt={`Icon ${size}px`} width={size} height={size} className="object-contain" style={{ maxWidth: "100%", maxHeight: 120 }} unoptimized />
              </div>
              <div className="p-3 bg-white flex justify-between items-center">
                <span className="text-[11px] text-[var(--color-ink2)]">{size}×{size}</span>
                <a href={`/brand/murmur-icon-${size}.png`} download className="text-[10px] font-bold uppercase tracking-wide text-[var(--color-accent)] no-underline hover:opacity-70">PNG</a>
              </div>
            </div>
          ))}
        </div>
        <div className="text-[12px] text-[var(--color-ink2)]">
          Also available:{" "}
          <a href="/brand/murmur-icon-1024.png" download className="text-[var(--color-ink)] underline">1024px master</a>,{" "}
          <a href="/brand/murmur-icon-32.png" download className="text-[var(--color-ink)] underline">32px favicon</a>,{" "}
          <a href="/brand/murmur-icon-16.png" download className="text-[var(--color-ink)] underline">16px</a>.{" "}
          Transparent background:{" "}
          <a href="/brand/murmur-icon-256-transparent.png" download className="text-[var(--color-ink)] underline">256px</a>,{" "}
          <a href="/brand/murmur-icon-512-transparent.png" download className="text-[var(--color-ink)] underline">512px</a>.
        </div>
      </div>

      {/* Brand Personality */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-4">Personality</h2>
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
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {colors.map((c) => (
            <div key={c.name} className="rounded-xl overflow-hidden border border-[var(--color-ink3)]">
              <div className="h-28 flex items-end p-4" style={{ backgroundColor: c.hex }}>
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
              Letter spacing: -0.02em<br />
              Always lowercase, period at end
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
        <p className="text-[13px] text-[var(--color-ink2)] mb-6">
          Always lowercase. Always with a period. Never capitalize, never bold.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="rounded-xl overflow-hidden border border-[var(--color-ink3)]">
            <div className="p-12 flex items-center justify-center" style={{ backgroundColor: "#f3f2ec" }}>
              <span className="font-display text-6xl" style={{ color: "#1f3a33" }}>murmur.</span>
            </div>
            <div className="p-3 bg-white text-xs text-[var(--color-ink2)]">Light</div>
          </div>
          <div className="rounded-xl overflow-hidden border border-[var(--color-ink3)]">
            <div className="p-12 flex items-center justify-center" style={{ backgroundColor: "#1f3a33" }}>
              <span className="font-display text-6xl" style={{ color: "#f3f2ec" }}>murmur.</span>
            </div>
            <div className="p-3 bg-white text-xs text-[var(--color-ink2)]">Dark</div>
          </div>
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
              <li>→ Pair bone background with ink text, or ink background with bone text</li>
              <li>→ Use yellow only as an accent (max 20% of composition)</li>
              <li>→ Use Instrument Serif for display, Inter for body</li>
              <li>→ Maintain clear space around the wordmark (min: character height)</li>
            </ul>
          </div>
          <div>
            <h3 className="text-sm font-bold text-[var(--color-ink)] mb-3">Don&apos;t</h3>
            <ul className="space-y-2 text-[13px] text-[var(--color-ink2)]">
              <li>→ Don&apos;t capitalize: <s>Murmur</s>, <s>MURMUR</s></li>
              <li>→ Don&apos;t remove the period: <s>murmur</s></li>
              <li>→ Don&apos;t add effects (shadows, glows, gradients)</li>
              <li>→ Don&apos;t stretch, rotate, or skew the wordmark</li>
              <li>→ Don&apos;t use yellow as a background or primary color</li>
            </ul>
          </div>
        </div>
      </div>

      {/* Voice */}
      <div className="mb-20">
        <h2 className="text-lg font-bold text-[var(--color-ink)] mb-4">Voice</h2>
        <div className="border border-[var(--color-ink3)] rounded-xl p-8">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 text-[13px]">
            <div>
              <p className="font-semibold text-[var(--color-ink)] mb-2">Conversational, not corporate</p>
              <p className="text-[var(--color-ink2)]">Talk like a friend who happens to know a lot. Not like a product manager.</p>
            </div>
            <div>
              <p className="font-semibold text-[var(--color-ink)] mb-2">Confident, not boastful</p>
              <p className="text-[var(--color-ink2)]">Say what we do. Don&apos;t oversell. The product speaks for itself.</p>
            </div>
            <div>
              <p className="font-semibold text-[var(--color-ink)] mb-2">Clear, not clever</p>
              <p className="text-[var(--color-ink2)]">Plain language beats clever copy. If a sentence needs a second read, rewrite it.</p>
            </div>
            <div>
              <p className="font-semibold text-[var(--color-ink)] mb-2">Warm, not cold</p>
              <p className="text-[var(--color-ink2)]">Murmur is intimate. Small. Quiet. Never shout. Never exclaim. Never use all caps.</p>
            </div>
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
