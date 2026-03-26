"use client";

import { useEffect, useRef } from "react";

export function HeroViz() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    const numBars = 100;
    const vw = 1000,
      vh = 200;
    const bw = vw / numBars;
    const gap = 1.5;

    let rects = "";
    for (let i = 0; i < numBars; i++) {
      const x = i * bw;
      const nx = i / numBars;
      const slow = Math.sin(nx * Math.PI * 2);
      const fast = Math.sin(nx * Math.PI * 6) * 0.5;
      const combined = (slow + fast) / 1.5;
      const del = nx * -4;
      const dur = 3.2 + Math.random() * 0.8;
      const smin = 0.1 + Math.abs(fast) * 0.2;
      const smax = 0.4 + Math.abs(combined) * 0.6;
      const isAccent = i % 5 === 0;
      rects += `<rect class="${isAccent ? "fill-[var(--color-accent)]" : "fill-[var(--color-ink)]"}" x="${x}" y="0" width="${bw - gap}" height="100%" style="transform-box:fill-box;transform-origin:center;animation:heroWave ${dur}s cubic-bezier(0.4,0,0.2,1) infinite alternate;animation-delay:${del}s;--smin:${smin};--smax:${smax}"/>`;
    }

    ref.current.innerHTML = `
      <style>
        @keyframes heroWave {
          0% { transform: scaleY(var(--smin, 0.15)); }
          100% { transform: scaleY(var(--smax, 1)); }
        }
      </style>
      <svg viewBox="0 0 ${vw} ${vh}" preserveAspectRatio="xMidYMid meet" class="w-full h-full">${rects}</svg>
    `;
  }, []);

  return (
    <div
      ref={ref}
      className="w-full max-w-[800px] h-[200px] overflow-hidden mb-12"
    />
  );
}
