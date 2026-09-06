/**
 * Plan definitions. The pricing page, the account page, the checkout route and
 * the license validation endpoint all read from here, so a copy change or a new
 * tier happens in exactly one file.
 */

import { stripeProPlusPriceId, stripeProPriceId } from "./config";

export type PlanId = "free" | "pro" | "pro_plus";

export interface Plan {
  id: PlanId;
  name: string;
  price: number;
  cadence: string;
  tagline: string;
  features: string[];
  featured?: boolean;
  /** Cloud voices unlock when the desktop app sees one of these plans. */
  cloudVoices: boolean;
}

export const PLANS: Plan[] = [
  {
    id: "free",
    name: "Free",
    price: 0,
    cadence: "forever — no account needed",
    tagline: "Everything you need to read text aloud, on your own machine.",
    cloudVoices: false,
    features: [
      "27 high-quality local voices",
      "Unlimited text-to-speech",
      "100% offline — text never leaves your device",
      "Speed control (0.75x – 3x)",
      "Global hotkey",
      "Auto updates",
      "Open source (Apache 2.0)",
    ],
  },
  {
    id: "pro",
    name: "Pro",
    price: 8,
    cadence: "per month",
    tagline: "Cloud voices when you want them, local when you don't.",
    featured: true,
    cloudVoices: true,
    features: [
      "Everything in Free",
      "Premium cloud voices (Cartesia, Fish Audio)",
      "80+ languages with auto-detection",
      "Voice cloning from 30s of audio",
      "Emotion & prosody control",
      "Priority synthesis queue",
      "Email support",
    ],
  },
  {
    id: "pro_plus",
    name: "Pro+",
    price: 16,
    cadence: "per month",
    tagline: "The highest-fidelity synthesis available, plus API access.",
    cloudVoices: true,
    features: [
      "Everything in Pro",
      "ElevenLabs ultra-realistic voices",
      "Highest quality synthesis available",
      "Unlimited cloud usage",
      "API access for automation",
      "Custom voice training",
      "Priority support",
    ],
  },
];

export function getPlan(id: PlanId): Plan {
  return PLANS.find((p) => p.id === id) ?? PLANS[0];
}

/** Maps a plan to its Stripe price id. Returns undefined for free or unset. */
export function priceIdForPlan(id: PlanId): string | undefined {
  if (id === "pro") return stripeProPriceId;
  if (id === "pro_plus") return stripeProPlusPriceId;
  return undefined;
}

/** Maps a Stripe price id back to a plan. */
export function planForPriceId(priceId: string | undefined): PlanId {
  if (priceId && priceId === stripeProPlusPriceId) return "pro_plus";
  if (priceId && priceId === stripeProPriceId) return "pro";
  return "pro";
}

export function isPlanId(value: string): value is PlanId {
  return value === "free" || value === "pro" || value === "pro_plus";
}
