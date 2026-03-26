"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase-browser";
import type { User } from "@supabase/supabase-js";

interface Subscription {
  plan: string;
  status: string;
  current_period_end: string | null;
}

interface LicenseKey {
  key: string;
  plan: string;
  is_active: boolean;
}

export default function AccountPage() {
  const supabase = createClient();
  const [user, setUser] = useState<User | null>(null);
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [licenseKeys, setLicenseKeys] = useState<LicenseKey[]>([]);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    async function load() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      setUser(user);

      const { data: subs } = await supabase
        .from("subscriptions")
        .select("plan, status, current_period_end")
        .eq("user_id", user.id)
        .limit(1);
      if (subs?.length) setSubscription(subs[0]);

      const { data: keys } = await supabase
        .from("license_keys")
        .select("key, plan, is_active")
        .eq("user_id", user.id);
      if (keys) setLicenseKeys(keys);
    }
    load();
  }, []);

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    window.location.href = "/";
  };

  const copyKey = (key: string) => {
    navigator.clipboard.writeText(key);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const planLabel = (plan: string) => {
    switch (plan) {
      case "pro":
        return "Pro";
      case "pro_plus":
        return "Pro+";
      default:
        return "Free";
    }
  };

  if (!user) {
    return (
      <section className="min-h-screen flex items-center justify-center">
        <p className="text-[var(--color-ink2)]">Loading...</p>
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

      {/* Profile */}
      <div className="border border-[var(--color-ink3)] rounded-xl p-6 mb-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-bold text-[var(--color-ink)]">
              {user.email}
            </p>
            <p className="text-xs text-[var(--color-ink2)] mt-1">
              Signed in via{" "}
              {user.app_metadata.provider === "google" ? "Google" : "Email"}
            </p>
          </div>
          <button
            onClick={handleSignOut}
            className="text-xs font-semibold uppercase tracking-wide text-[var(--color-ink2)] hover:text-[var(--color-ink)] transition-colors cursor-pointer"
          >
            Sign Out
          </button>
        </div>
      </div>

      {/* Subscription */}
      <div className="border border-[var(--color-ink3)] rounded-xl p-6 mb-6">
        <h2 className="text-xs font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-4">
          Subscription
        </h2>
        <div className="flex items-center justify-between">
          <div>
            <span className="text-2xl font-bold text-[var(--color-ink)]">
              {planLabel(subscription?.plan || "free")}
            </span>
            <span
              className={`ml-3 text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded ${
                subscription?.status === "active"
                  ? "bg-green-100 text-green-700"
                  : "bg-yellow-100 text-yellow-700"
              }`}
            >
              {subscription?.status || "active"}
            </span>
          </div>
          {subscription?.plan === "free" && (
            <span className="text-xs font-bold uppercase tracking-wide text-[var(--color-ink2)] cursor-default opacity-60">
              Upgrade Coming Soon
            </span>
          )}
        </div>
        {subscription?.current_period_end && (
          <p className="text-xs text-[var(--color-ink2)] mt-2">
            Renews{" "}
            {new Date(subscription.current_period_end).toLocaleDateString()}
          </p>
        )}
      </div>

      {/* License Keys */}
      {licenseKeys.length > 0 && (
        <div className="border border-[var(--color-ink3)] rounded-xl p-6 mb-6">
          <h2 className="text-xs font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-4">
            License Key
          </h2>
          <p className="text-xs text-[var(--color-ink2)] mb-3">
            Enter this key in the Murmur desktop app to unlock cloud voices.
          </p>
          {licenseKeys
            .filter((k) => k.is_active)
            .map((k) => (
              <div
                key={k.key}
                className="flex items-center gap-3 bg-[rgba(31,58,51,0.04)] rounded-lg p-3"
              >
                <code className="flex-1 text-sm font-mono text-[var(--color-ink)] tracking-wider">
                  {k.key}
                </code>
                <button
                  onClick={() => copyKey(k.key)}
                  className="text-xs font-bold uppercase tracking-wide text-[var(--color-accent)] hover:opacity-70 transition-opacity cursor-pointer"
                >
                  {copied ? "Copied!" : "Copy"}
                </button>
              </div>
            ))}
        </div>
      )}

      {/* Download */}
      <div className="border border-[var(--color-ink3)] rounded-xl p-6">
        <h2 className="text-xs font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-4">
          Download
        </h2>
        <a
          href="https://github.com/eleventhavenue/murmur/releases/latest"
          className="block text-center py-3 rounded-lg text-xs font-bold uppercase tracking-wide bg-[var(--color-surface)] text-[var(--color-surface-text)] no-underline hover:opacity-90 transition-opacity"
        >
          Download Murmur for Windows
        </a>
      </div>
    </section>
  );
}
