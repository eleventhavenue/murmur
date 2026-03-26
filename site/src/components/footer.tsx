import Link from "next/link";

export function Footer() {
  return (
    <footer className="px-10 py-10 border-t border-[var(--color-ink3)] flex justify-between items-center text-xs text-[var(--color-ink2)]">
      <span>&copy; 2026 Murmur. Open source under Apache 2.0.</span>
      <div className="flex gap-6">
        <Link href="https://github.com/eleventhavenue/murmur" target="_blank" className="text-[var(--color-ink2)] hover:text-[var(--color-ink)] no-underline">
          GitHub
        </Link>
        <Link href="/privacy" className="text-[var(--color-ink2)] hover:text-[var(--color-ink)] no-underline">
          Privacy
        </Link>
        <Link href="/terms" className="text-[var(--color-ink2)] hover:text-[var(--color-ink)] no-underline">
          Terms
        </Link>
      </div>
    </footer>
  );
}
