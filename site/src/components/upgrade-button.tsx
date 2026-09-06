"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase-browser";
import type { PlanId } from "@/lib/plans";

interface Props {
  plan: PlanId;
  label: string;
  className: string;
  /** False when the server knows Stripe keys are absent. */
  billingLive: boolean;
}

export function UpgradeButton({ plan, label, className, billingLive }: Props) {
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  async function start() {
    setBusy(true);
    setNotice(null);

    try {
      const res = await fetch("/api/stripe/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ plan }),
      });

      if (res.status === 401) {
        // Send them through Google, then straight back to finish the upgrade.
        const supabase = createClient();
        await supabase.auth.signInWithOAuth({
          provider: "google",
          options: {
            redirectTo: `${window.location.origin}/auth/callback?next=/pricing`,
          },
        });
        return;
      }

      const data = await res.json();

      if (res.ok && data.url) {
        window.location.href = data.url;
        return;
      }

      if (data.error === "billing_not_configured" || data.error === "price_not_configured") {
        setNotice("Checkout isn't connected yet. Email us and we'll set you up.");
      } else {
        setNotice("Something went wrong starting checkout. Try again in a moment.");
      }
    } catch {
      setNotice("Couldn't reach the server. Check your connection and try again.");
    } finally {
      setBusy(false);
    }
  }

  // With no Stripe keys the honest thing is a contact link, not a dead button.
  if (!billingLive) {
    return (
      <a
        href={`mailto:tunde@nashlabs.ca?subject=Murmur%20${encodeURIComponent(label)}`}
        className={className}
      >
        Get in Touch
      </a>
    );
  }

  return (
    <div>
      <button onClick={start} disabled={busy} className={`${className} w-full cursor-pointer`}>
        {busy ? "Starting…" : label}
      </button>
      {notice && (
        <p className="text-[11px] text-[var(--color-ink2)] mt-2 leading-relaxed text-center">
          {notice}
        </p>
      )}
    </div>
  );
}
