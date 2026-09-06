"use client";

import { useState } from "react";

export function ManageBillingButton({ className }: { className: string }) {
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  async function open() {
    setBusy(true);
    setNotice(null);
    try {
      const res = await fetch("/api/stripe/portal", { method: "POST" });
      const data = await res.json();
      if (res.ok && data.url) {
        window.location.href = data.url;
        return;
      }
      setNotice(
        data.error === "no_customer"
          ? "No billing record yet — upgrade first."
          : "Billing portal isn't available right now.",
      );
    } catch {
      setNotice("Couldn't reach the server.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <button onClick={open} disabled={busy} className={`${className} cursor-pointer`}>
        {busy ? "Opening…" : "Manage billing"}
      </button>
      {notice && <p className="text-[11px] text-[var(--color-ink2)] mt-2">{notice}</p>}
    </div>
  );
}
