import Link from "next/link";
import { AuthButton } from "./auth-button";

export function Nav() {
  return (
    <nav className="fixed top-0 left-0 right-0 z-50 flex justify-between items-center px-10 py-5 backdrop-blur-xl bg-[var(--color-bg)]/80">
      <Link href="/" className="font-display text-xl text-[var(--color-ink)] no-underline">
        murmur.
      </Link>
      <div className="flex gap-8 items-center">
        <Link
          href="/docs"
          className="text-xs font-semibold uppercase tracking-widest text-[var(--color-ink2)] hover:text-[var(--color-ink)] transition-colors no-underline"
        >
          Docs
        </Link>
        <Link
          href="/pricing"
          className="text-xs font-semibold uppercase tracking-widest text-[var(--color-ink2)] hover:text-[var(--color-ink)] transition-colors no-underline"
        >
          Pricing
        </Link>
        <Link
          href="https://github.com/eleventhavenue/murmur"
          target="_blank"
          className="text-xs font-semibold uppercase tracking-widest text-[var(--color-ink2)] hover:text-[var(--color-ink)] transition-colors no-underline"
        >
          GitHub
        </Link>
        <AuthButton />
        <Link
          href="/download"
          className="text-xs font-bold uppercase tracking-wide bg-[var(--color-surface)] text-[var(--color-surface-text)] px-5 py-2 rounded-lg no-underline hover:opacity-90 transition-opacity"
        >
          Download
        </Link>
      </div>
    </nav>
  );
}
