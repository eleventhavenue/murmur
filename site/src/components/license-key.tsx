"use client";

import { useState } from "react";

/** Shows the key masked until revealed, with copy-to-clipboard. */
export function LicenseKey({ value }: { value: string }) {
  const [revealed, setRevealed] = useState(false);
  const [copied, setCopied] = useState(false);

  const masked = value.replace(/[0-9A-Z]{4}(?=-|$)/g, (m, offset: number) =>
    offset < 7 ? m : "••••",
  );

  async function copy() {
    await navigator.clipboard.writeText(value);
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  }

  return (
    <div className="flex flex-wrap items-center gap-3">
      <code className="font-mono text-[13px] text-[var(--color-ink)] bg-[var(--color-ink3)] px-3 py-2 rounded-lg tracking-wider">
        {revealed ? value : masked}
      </code>
      <button
        onClick={() => setRevealed((r) => !r)}
        className="text-[11px] uppercase tracking-widest text-[var(--color-ink2)] hover:text-[var(--color-ink)] bg-transparent border-none cursor-pointer"
      >
        {revealed ? "Hide" : "Reveal"}
      </button>
      <button
        onClick={copy}
        className="text-[11px] uppercase tracking-widest text-[var(--color-ink2)] hover:text-[var(--color-ink)] bg-transparent border-none cursor-pointer"
      >
        {copied ? "Copied" : "Copy"}
      </button>
    </div>
  );
}
