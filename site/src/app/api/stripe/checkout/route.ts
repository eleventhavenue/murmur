import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase-server";
import { createAdminClient } from "@/lib/supabase-admin";
import { createStripe } from "@/lib/stripe";
import { isPlanId, priceIdForPlan } from "@/lib/plans";
import {
  isStripeConfigured,
  isSupabaseConfigured,
  missingBillingEnv,
  siteUrl,
} from "@/lib/config";

/**
 * Starts a Stripe Checkout session for the signed-in user.
 *
 * Deliberately refuses rather than pretending when Stripe is not connected:
 * a fake "success" here would be worse than a clear error, because the caller
 * would believe money changed hands.
 */
export async function POST(req: Request) {
  if (!isStripeConfigured || !isSupabaseConfigured) {
    return NextResponse.json(
      {
        error: "billing_not_configured",
        message: "Billing is not connected yet.",
        missing: missingBillingEnv(),
      },
      { status: 503 },
    );
  }

  let plan: string;
  try {
    const body = await req.json();
    plan = String(body.plan ?? "");
  } catch {
    return NextResponse.json({ error: "invalid_body" }, { status: 400 });
  }

  if (!isPlanId(plan) || plan === "free") {
    return NextResponse.json({ error: "invalid_plan" }, { status: 400 });
  }

  const priceId = priceIdForPlan(plan);
  if (!priceId) {
    return NextResponse.json(
      { error: "price_not_configured", plan },
      { status: 503 },
    );
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) {
    return NextResponse.json({ error: "not_signed_in" }, { status: 401 });
  }

  const stripe = createStripe();
  const admin = createAdminClient();

  // Reuse the Stripe customer if this user already has one, so upgrades and
  // downgrades stay on a single customer record rather than fragmenting.
  const { data: existing } = await admin
    .from("subscriptions")
    .select("stripe_customer_id")
    .eq("user_id", user.id)
    .maybeSingle();

  let customerId = existing?.stripe_customer_id ?? undefined;

  if (!customerId) {
    const customer = await stripe.customers.create({
      email: user.email,
      metadata: { supabase_user_id: user.id },
    });
    customerId = customer.id;
    await admin
      .from("subscriptions")
      .update({ stripe_customer_id: customerId })
      .eq("user_id", user.id);
  }

  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    customer: customerId,
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${siteUrl}/account?checkout=success`,
    cancel_url: `${siteUrl}/pricing?checkout=cancelled`,
    allow_promotion_codes: true,
    subscription_data: { metadata: { supabase_user_id: user.id, plan } },
    metadata: { supabase_user_id: user.id, plan },
  });

  return NextResponse.json({ url: session.url });
}
