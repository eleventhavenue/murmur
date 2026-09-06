"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase-browser";

// Inlined at build time. Without it the site still builds and runs, it just
// cannot sign anyone in, so the nav points at the account page instead.
const configured = Boolean(
  process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
);

export function AuthButton() {
  const [email, setEmail] = useState<string | null>(null);
  const [loading, setLoading] = useState(configured);

  useEffect(() => {
    if (!configured) return;
    createClient()
      .auth.getUser()
      .then(({ data: { user } }) => {
        setEmail(user?.email ?? null);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  const handleSignIn = async () => {
    await createClient().auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });
  };

  if (loading) return null;

  if (!configured) {
    return (
      <Link
        href="/account"
        className="text-xs font-semibold uppercase tracking-widest text-[var(--color-ink2)] hover:text-[var(--color-ink)] transition-colors no-underline"
      >
        Account
      </Link>
    );
  }

  if (email) {
    return (
      <Link
        href="/account"
        className="text-xs font-semibold uppercase tracking-widest text-[var(--color-ink2)] hover:text-[var(--color-ink)] transition-colors no-underline"
      >
        Account
      </Link>
    );
  }

  return (
    <button
      onClick={handleSignIn}
      className="text-xs font-semibold uppercase tracking-widest text-[var(--color-ink2)] hover:text-[var(--color-ink)] transition-colors cursor-pointer bg-transparent border-none"
    >
      Sign In
    </button>
  );
}
