"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { User } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase-browser";
import { LicenseKey } from "@/components/license-key";
import { ManageBillingButton } from "@/components/manage-billing-button";

interface Subscription {
  plan: string;
  status: string;
  current_period_end: string | null;
  cancel_at_period_end?: boolean;
}

// NEXT_PUBLIC_ values are inlined at build time, so this is safe on the client.
const configured = Boolean(
  process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
);

const DEMO_SUBSCRIPTION: Subscription = {
  plan: "pro",
  status: "active",
  current_period_end: new Date(Date.now() + 21 * 86_400_000).toISOString(),
};

const solidButton =
  "block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide bg-[var(--color-surface)] text-[var(--color-surface-text)] no-underline hover:opacity-90 transition-opacity border-none";
const outlineButton =
  "inline-block text-center py-2.5 px-5 rounded-lg text-xs font-bold uppercase tracking-wide border border-[var(--color-ink3)] text-[var(--color-ink)] hover:bg-[var(--color-ink)] hover:text-[var(--color-bg)] transition-all no-underline bg-transparent";

function planLabel(plan: string) {
  if (plan === "pro") return "Pro";
  if (plan === "pro_plus") return "Pro+";
  return "Free";
}

export default function AccountPage() {
  const [user, setUser] = useState<User | null>(null);
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [licenseKey, setLicenseKey] = useState<string | null>(null);
  // Starts false when Supabase is absent: there is nothing to wait for, and
  // setting state synchronously inside the effect would cause a second render.
  const [loading, setLoading] = useState(configured);

  useEffect(() => {
    if (!configured) return;
    let cancelled = false;

    (async () => {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (cancelled) return;
      if (!user) {
        setLoading(false);
        return;
      }
      setUser(user);

      const [{ data: sub }, { data: key }] = await Promise.all([
        // Selects every column rather than naming them: the live database
        // predates supabase/migrations, so a column named here that has not
        // been added yet would fail the whole query and show the user as Free.
        supabase
          .from("subscriptions")
          .select("*")
          .eq("user_id", user.id)
          .maybeSingle(),
        supabase
          .from("license_keys")
          .select("key")
          .eq("user_id", user.id)
          .eq("is_active", true)
          .maybeSingle(),
      ]);

      if (cancelled) return;
      if (sub) setSubscription(sub);
      if (key) setLicenseKey(key.key);
      setLoading(false);
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  async function signIn() {
    const supabase = createClient();
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}/auth/callback?next=/account` },
    });
  }

  async function signOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    window.location.href = "/";
  }

  if (loading) {
    return (
      <section className="min-h-[60vh] flex items-center justify-center">
        <p className="text-[var(--color-ink2)] text-sm">Loading…</p>
      </section>
    );
  }

  // Demo mode: no Supabase keys, so render the real layout with sample data
  // rather than a broken page. Connecting keys is the only remaining step.
  const demo = !configured;
  const activeSubscription = demo ? DEMO_SUBSCRIPTION : subscription;
  const activeKey = demo ? "MURMUR-DEMO-DEMO-DEMO-DEMO" : licenseKey;

  if (!demo && !user) {
    return (
      <section className="max-w-[600px] mx-auto px-10 pt-32 pb-20 text-center">
        <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] block mb-3">
          Account
        </span>
        <h1 className="font-display text-[clamp(32px,5vw,48px)] leading-none text-[var(--color-ink)] mb-4">
          Sign in.
        </h1>
        <p className="text-sm text-[var(--color-ink2)] mb-8 leading-relaxed">
          You only need an account for cloud voices. The desktop app works
          without one, forever.
        </p>
        <button onClick={signIn} className={`${solidButton} w-full cursor-pointer`}>
          Continue with Google
        </button>
      </section>
    );
  }

  return (
    <section className="max-w-[600px] mx-auto px-10 pt-32 pb-20">
      <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] block mb-3">
        Account
      </span>
      <h1 className="font-display text-[clamp(32px,5vw,48px)] leading-none text-[var(--color-ink)] mb-12">
        Welcome back.
      </h1>

      {demo && (
        <div className="border border-[var(--color-accent)] bg-[rgba(220,212,68,0.12)] rounded-xl p-4 mb-6">
          <p className="text-[12px] text-[var(--color-ink)] font-semibold mb-1">
            Demo data
          </p>
          <p className="text-[12px] text-[var(--color-ink2)] leading-relaxed">
            Supabase isn&apos;t connected in this environment, so this page is
            showing a sample account. Add the environment variables from{" "}
            <code className="text-[11px]">.env.example</code> to make it live.
          </p>
        </div>
      )}

      <div className="border border-[var(--color-ink3)] rounded-xl p-6 mb-6">
        <div className="flex items-center justify-between gap-4">
          <div className="min-w-0">
            <p className="text-sm font-bold text-[var(--color-ink)] truncate">
              {demo ? "you@example.com" : user?.email}
            </p>
            <p className="text-xs text-[var(--color-ink2)] mt-1">
              Signed in via {demo ? "Google" : user?.app_metadata?.provider === "google" ? "Google" : "Email"}
            </p>
          </div>
          {!demo && (
            <button
              onClick={signOut}
              className="text-xs font-semibold uppercase tracking-wide text-[var(--color-ink2)] hover:text-[var(--color-ink)] transition-colors cursor-pointer bg-transparent border-none shrink-0"
            >
              Sign Out
            </button>
          )}
        </div>
      </div>

      <div className="border border-[var(--color-ink3)] rounded-xl p-6 mb-6">
        <h2 className="text-xs font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-4">
          Subscription
        </h2>
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <div>
            <span className="text-2xl font-bold text-[var(--color-ink)]">
              {planLabel(activeSubscription?.plan ?? "free")}
            </span>
            <span
              className={`ml-3 text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded ${
                (activeSubscription?.status ?? "active") === "active"
                  ? "bg-[rgba(31,58,51,0.1)] text-[var(--color-ink)]"
                  : "bg-[rgba(220,212,68,0.3)] text-[var(--color-ink)]"
              }`}
            >
              {activeSubscription?.status ?? "active"}
            </span>
          </div>

          {(activeSubscription?.plan ?? "free") === "free" ? (
            <Link href="/pricing" className={outlineButton}>
              Upgrade
            </Link>
          ) : (
            <ManageBillingButton className={outlineButton} />
          )}
        </div>

        {activeSubscription?.current_period_end && (
          <p className="text-xs text-[var(--color-ink2)] mt-3">
            {activeSubscription.cancel_at_period_end ? "Ends " : "Renews "}
            {new Date(activeSubscription.current_period_end).toLocaleDateString()}
          </p>
        )}
      </div>

      {activeKey && (
        <div className="border border-[var(--color-ink3)] rounded-xl p-6 mb-6">
          <h2 className="text-xs font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-4">
            License Key
          </h2>
          <p className="text-xs text-[var(--color-ink2)] mb-4 leading-relaxed">
            Paste this into Murmur&apos;s settings to unlock cloud voices. Local
            voices never need a key.
          </p>
          <LicenseKey value={activeKey} />
        </div>
      )}

      <div className="border border-[var(--color-ink3)] rounded-xl p-6">
        <h2 className="text-xs font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-4">
          Download
        </h2>
        <Link href="/download" className={solidButton}>
          Get Murmur
        </Link>
      </div>
    </section>
  );
}
