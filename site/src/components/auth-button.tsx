"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase-browser";

export function AuthButton() {
  const supabase = createClient();
  const [email, setEmail] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      setEmail(user?.email ?? null);
      setLoading(false);
    });
  }, []);

  const handleSignIn = async () => {
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });
  };

  if (loading) return null;

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
