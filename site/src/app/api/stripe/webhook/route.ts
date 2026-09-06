import { NextResponse } from "next/server";
import type Stripe from "stripe";
import { createStripe } from "@/lib/stripe";
import { createAdminClient } from "@/lib/supabase-admin";
import {
  isStripeConfigured,
  isSupabaseAdminConfigured,
  stripeWebhookSecret,
} from "@/lib/config";
import { planForPriceId } from "@/lib/plans";
import { generateLicenseKey } from "@/lib/license";

/**
 * Stripe subscription lifecycle → Supabase.
 *
 * Every handler is idempotent: Stripe retries failed deliveries, and without
 * the webhook_events guard a retry would issue a second license key for the
 * same purchase.
 */

export async function POST(req: Request) {
  if (!isStripeConfigured || !isSupabaseAdminConfigured || !stripeWebhookSecret) {
    return NextResponse.json({ error: "billing_not_configured" }, { status: 503 });
  }

  const stripe = createStripe();
  const supabase = createAdminClient();
  const body = await req.text();
  const signature = req.headers.get("stripe-signature");

  if (!signature) {
    return NextResponse.json({ error: "missing_signature" }, { status: 400 });
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, stripeWebhookSecret);
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return NextResponse.json({ error: "invalid_signature" }, { status: 400 });
  }

  // Idempotency: claim the event id first. A unique violation means we already
  // processed this delivery, so acknowledge and do nothing.
  //
  // Any other failure — most likely webhook_events not existing yet, because
  // supabase/migrations has not been applied — must NOT be treated as a
  // duplicate. Swallowing it would silently drop a real payment. Log it and
  // process the event anyway; at worst a Stripe retry repeats the work, which
  // the handlers below are written to tolerate.
  const { error: claimError } = await supabase
    .from("webhook_events")
    .insert({ id: event.id, type: event.type });

  const alreadyProcessed = claimError?.code === "23505";
  if (alreadyProcessed) {
    return NextResponse.json({ received: true, duplicate: true });
  }
  if (claimError) {
    console.error(
      `webhook_events unavailable (${claimError.code}): ${claimError.message}. ` +
        "Processing without an idempotency guard — apply supabase/migrations.",
    );
  }

  try {
    await handleEvent(event, stripe, supabase);
  } catch (err) {
    console.error(`Failed handling ${event.type} (${event.id}):`, err);
    // Release the claim so Stripe's retry gets a real second attempt.
    if (!claimError) {
      await supabase.from("webhook_events").delete().eq("id", event.id);
    }
    return NextResponse.json({ error: "handler_failed" }, { status: 500 });
  }

  return NextResponse.json({ received: true });
}

type Admin = ReturnType<typeof createAdminClient>;

async function handleEvent(event: Stripe.Event, stripe: Stripe, supabase: Admin) {
  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      if (!session.subscription) break;

      const userId = await resolveUserId(session, supabase);
      if (!userId) {
        console.error("checkout.session.completed with no resolvable user", session.id);
        break;
      }

      const subscription = await stripe.subscriptions.retrieve(
        session.subscription as string,
      );
      await applySubscription(userId, subscription, supabase);
      break;
    }

    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const subscription = event.data.object as Stripe.Subscription;
      const userId = await userIdForCustomerOrMetadata(subscription, supabase);
      if (!userId) break;
      await applySubscription(userId, subscription, supabase);
      break;
    }

    case "customer.subscription.deleted": {
      const subscription = event.data.object as Stripe.Subscription;

      await supabase
        .from("subscriptions")
        .update({
          plan: "free",
          status: "canceled",
          cancel_at_period_end: false,
          updated_at: new Date().toISOString(),
        })
        .eq("stripe_subscription_id", subscription.id);

      const { data: row } = await supabase
        .from("subscriptions")
        .select("user_id")
        .eq("stripe_subscription_id", subscription.id)
        .maybeSingle();

      if (row?.user_id) {
        // Keep the key row so the user keeps the same key if they resubscribe,
        // but drop it back to the free tier.
        await supabase
          .from("license_keys")
          .update({ plan: "free" })
          .eq("user_id", row.user_id);
      }
      break;
    }

    case "invoice.payment_failed": {
      const invoice = event.data.object as Stripe.Invoice & { subscription?: string };
      if (!invoice.subscription) break;
      await supabase
        .from("subscriptions")
        .update({ status: "past_due", updated_at: new Date().toISOString() })
        .eq("stripe_subscription_id", invoice.subscription);
      break;
    }
  }
}

/** Finds our user from the checkout session, preferring metadata over email. */
async function resolveUserId(
  session: Stripe.Checkout.Session,
  supabase: Admin,
): Promise<string | null> {
  const fromMetadata = session.metadata?.supabase_user_id;
  if (fromMetadata) return fromMetadata;

  if (session.customer) {
    const { data } = await supabase
      .from("subscriptions")
      .select("user_id")
      .eq("stripe_customer_id", session.customer as string)
      .maybeSingle();
    if (data?.user_id) return data.user_id;
  }

  const email = session.customer_email ?? session.customer_details?.email;
  if (!email) return null;

  const { data } = await supabase
    .from("profiles")
    .select("id")
    .eq("email", email)
    .maybeSingle();

  return data?.id ?? null;
}

async function userIdForCustomerOrMetadata(
  subscription: Stripe.Subscription,
  supabase: Admin,
): Promise<string | null> {
  const fromMetadata = subscription.metadata?.supabase_user_id;
  if (fromMetadata) return fromMetadata;

  const { data } = await supabase
    .from("subscriptions")
    .select("user_id")
    .eq("stripe_customer_id", subscription.customer as string)
    .maybeSingle();

  return data?.user_id ?? null;
}

/** Writes subscription state and makes sure the user has an active key. */
async function applySubscription(
  userId: string,
  subscription: Stripe.Subscription,
  supabase: Admin,
) {
  const item = subscription.items?.data?.[0];
  const plan = planForPriceId(item?.price?.id);

  const status =
    subscription.status === "active" || subscription.status === "trialing"
      ? subscription.status
      : subscription.status === "past_due"
        ? "past_due"
        : "canceled";

  // Period bounds live on the subscription item in current API versions and on
  // the subscription itself in older ones.
  const periodStart = item?.current_period_start ?? null;
  const periodEnd = item?.current_period_end ?? null;
  const toIso = (seconds: number | null) =>
    seconds ? new Date(seconds * 1000).toISOString() : null;

  await supabase
    .from("subscriptions")
    .update({
      stripe_customer_id: subscription.customer as string,
      stripe_subscription_id: subscription.id,
      plan: status === "canceled" ? "free" : plan,
      status,
      current_period_start: toIso(periodStart),
      current_period_end: toIso(periodEnd),
      cancel_at_period_end: subscription.cancel_at_period_end ?? false,
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userId);

  // One key per user, created at signup. Upgrade it rather than issuing another.
  const { data: existing } = await supabase
    .from("license_keys")
    .select("id")
    .eq("user_id", userId)
    .maybeSingle();

  if (existing) {
    await supabase
      .from("license_keys")
      .update({
        plan: status === "canceled" ? "free" : plan,
        is_active: true,
        activated_at: new Date().toISOString(),
      })
      .eq("id", existing.id);
  } else {
    await supabase.from("license_keys").insert({
      user_id: userId,
      key: generateLicenseKey(),
      plan: status === "canceled" ? "free" : plan,
      is_active: true,
      activated_at: new Date().toISOString(),
    });
  }
}
