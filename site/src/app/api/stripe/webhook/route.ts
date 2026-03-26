import { NextResponse } from "next/server";
import Stripe from "stripe";
import { createClient } from "@supabase/supabase-js";

function getStripe() {
  return new Stripe(process.env.STRIPE_SECRET_KEY!);
}

function getSupabaseAdmin() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
}

export async function POST(req: Request) {
  const stripe = getStripe();
  const supabase = getSupabaseAdmin();
  const body = await req.text();
  const sig = req.headers.get("stripe-signature")!;

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET!,
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return NextResponse.json({ error: "Invalid signature" }, { status: 400 });
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      const customerId = session.customer as string;
      const subscriptionId = session.subscription as string;
      const email = session.customer_email || session.customer_details?.email;

      if (!email) break;

      // Find user by email
      const { data: profiles } = await supabase
        .from("profiles")
        .select("id")
        .eq("email", email)
        .limit(1);

      if (!profiles?.length) break;

      const userId = profiles[0].id;

      // Get subscription details
      const subResponse = await stripe.subscriptions.retrieve(subscriptionId);
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const sub = subResponse as any;
      const priceId = sub.items?.data?.[0]?.price?.id;
      const plan =
        priceId === process.env.STRIPE_PRO_PLUS_PRICE_ID
          ? "pro_plus"
          : "pro";

      // Update subscription
      await supabase
        .from("subscriptions")
        .update({
          stripe_customer_id: customerId,
          stripe_subscription_id: subscriptionId,
          plan,
          status: "active",
          current_period_start: sub.current_period_start
            ? new Date(sub.current_period_start * 1000).toISOString()
            : null,
          current_period_end: sub.current_period_end
            ? new Date(sub.current_period_end * 1000).toISOString()
            : null,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", userId);

      // Generate license key
      await supabase.from("license_keys").insert({
        user_id: userId,
        plan,
        is_active: true,
        activated_at: new Date().toISOString(),
      });

      break;
    }

    case "customer.subscription.updated": {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const subUpdated = event.data.object as any;
      const status = subUpdated.status === "active" ? "active" : subUpdated.status === "past_due" ? "past_due" : "canceled";

      await supabase
        .from("subscriptions")
        .update({
          status,
          current_period_start: subUpdated.current_period_start
            ? new Date(subUpdated.current_period_start * 1000).toISOString()
            : null,
          current_period_end: subUpdated.current_period_end
            ? new Date(subUpdated.current_period_end * 1000).toISOString()
            : null,
          updated_at: new Date().toISOString(),
        })
        .eq("stripe_subscription_id", subUpdated.id);

      break;
    }

    case "customer.subscription.deleted": {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const subscription = event.data.object as any;

      // Downgrade to free
      await supabase
        .from("subscriptions")
        .update({
          plan: "free",
          status: "canceled",
          updated_at: new Date().toISOString(),
        })
        .eq("stripe_subscription_id", subscription.id);

      // Deactivate license keys
      const { data: sub } = await supabase
        .from("subscriptions")
        .select("user_id")
        .eq("stripe_subscription_id", subscription.id)
        .limit(1);

      if (sub?.length) {
        await supabase
          .from("license_keys")
          .update({ is_active: false })
          .eq("user_id", sub[0].user_id);
      }

      break;
    }
  }

  return NextResponse.json({ received: true });
}
