import Link from "next/link";
import { PLANS } from "@/lib/plans";
import { isBillingLive } from "@/lib/config";
import { UpgradeButton } from "@/components/upgrade-button";

export const metadata = {
  title: "Pricing — Murmur",
  description:
    "Murmur is free and open source forever. Upgrade for premium cloud voices, voice cloning and 80+ languages.",
};

const solidButton =
  "block text-center py-3.5 rounded-lg text-xs font-bold uppercase tracking-wide bg-[var(--color-surface)] text-[var(--color-surface-text)] no-underline hover:opacity-90 transition-opacity border-none";
const outlineButton =
  "block text-center py-3.5 rounded-lg text-xs font-bold uppercase tracking-wide border border-[var(--color-ink3)] text-[var(--color-ink)] hover:bg-[var(--color-ink)] hover:text-[var(--color-bg)] transition-all no-underline bg-transparent";

export default function PricingPage() {
  return (
    <section className="max-w-[1000px] mx-auto px-10 pt-32 pb-20">
      <div className="text-center mb-16">
        <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-[var(--color-accent)] block mb-3">
          Pricing
        </span>
        <h1 className="font-display text-[clamp(40px,7vw,72px)] leading-[0.95] text-[var(--color-ink)] mb-4">
          Free forever.
          <br />
          Pro when you want it.
        </h1>
        <p className="text-base text-[var(--color-ink2)] max-w-[440px] mx-auto leading-relaxed">
          Start with 27 local voices at no cost. Upgrade for premium cloud
          voices, voice cloning, and 80+ languages.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-20">
        {PLANS.map((plan) => (
          <div
            key={plan.id}
            className={
              plan.featured
                ? "border-2 border-[var(--color-accent)] rounded-xl p-9 flex flex-col bg-[rgba(31,58,51,0.03)] relative"
                : "border border-[var(--color-ink3)] rounded-xl p-9 flex flex-col"
            }
          >
            {plan.featured && (
              <span className="absolute -top-3 left-7 bg-[var(--color-accent)] text-[var(--color-bg)] text-[9px] font-extrabold uppercase tracking-widest px-3 py-1 rounded">
                Most Popular
              </span>
            )}

            <span className="text-[13px] font-bold uppercase tracking-widest text-[var(--color-ink2)] mb-2">
              {plan.name}
            </span>
            <span className="font-display text-6xl text-[var(--color-ink)] mb-1">
              ${plan.price}
            </span>
            <span className="text-xs text-[var(--color-ink2)] mb-8">{plan.cadence}</span>

            <ul className="flex-1 mb-8 list-none p-0">
              {plan.features.map((feature) => (
                <li
                  key={feature}
                  className="text-[13px] text-[var(--color-ink2)] py-2.5 border-b border-[var(--color-ink3)]"
                >
                  <span className="text-[var(--color-accent)]">→ </span>
                  {feature}
                </li>
              ))}
            </ul>

            {plan.id === "free" ? (
              <Link href="/download" className={outlineButton}>
                Download Free
              </Link>
            ) : (
              <UpgradeButton
                plan={plan.id}
                label={`Upgrade to ${plan.name}`}
                billingLive={isBillingLive}
                className={plan.featured ? solidButton : outlineButton}
              />
            )}
          </div>
        ))}
      </div>

      <div className="text-center text-[13px] text-[var(--color-ink2)]">
        <p>All plans include auto-updates and the full open-source desktop app.</p>
        <p className="mt-1">
          Cancel any time from your{" "}
          <Link href="/account" className="text-[var(--color-ink)] underline">
            account
          </Link>
          . Questions?{" "}
          <a
            href="https://github.com/eleventhavenue/murmur/issues"
            className="text-[var(--color-ink)] underline"
            target="_blank"
          >
            Ask on GitHub
          </a>
          .
        </p>
      </div>
    </section>
  );
}
