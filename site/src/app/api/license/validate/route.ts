import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase-admin";
import { isSupabaseAdminConfigured } from "@/lib/config";
import { getPlan, isPlanId } from "@/lib/plans";
import { isLicenseKey, normalizeLicenseKey } from "@/lib/license";

/**
 * The endpoint the desktop apps call to turn a license key into a set of
 * entitlements. Both Murmur builds stay fully functional offline; this only
 * decides whether the cloud voices light up.
 *
 * Demo key: MURMUR-DEMO-DEMO-DEMO-DEMO always validates as Pro so the desktop
 * apps can be developed against a real endpoint before Supabase is connected.
 */

const DEMO_KEY = "MURMUR-DEMO-DEMO-DEMO-DEMO";

interface Entitlements {
  valid: boolean;
  plan: string;
  cloudVoices: boolean;
  status?: string;
  expiresAt?: string | null;
  demo?: boolean;
  reason?: string;
}

function deny(reason: string): NextResponse {
  return NextResponse.json<Entitlements>(
    { valid: false, plan: "free", cloudVoices: false, reason },
    { status: 200 },
  );
}

export async function POST(req: Request) {
  let key: string;
  try {
    const body = await req.json();
    key = normalizeLicenseKey(String(body.key ?? ""));
  } catch {
    return NextResponse.json({ error: "invalid_body" }, { status: 400 });
  }

  if (!key) return deny("missing_key");

  if (key === DEMO_KEY) {
    return NextResponse.json<Entitlements>({
      valid: true,
      plan: "pro",
      cloudVoices: true,
      status: "active",
      expiresAt: null,
      demo: true,
    });
  }

  if (!isLicenseKey(key)) return deny("malformed_key");

  if (!isSupabaseAdminConfigured) {
    return NextResponse.json<Entitlements>(
      { valid: false, plan: "free", cloudVoices: false, reason: "licensing_not_configured" },
      { status: 503 },
    );
  }

  const admin = createAdminClient();

  const { data: license } = await admin
    .from("license_keys")
    .select("user_id, plan, is_active")
    .eq("key", key)
    .maybeSingle();

  if (!license) return deny("unknown_key");
  if (!license.is_active) return deny("inactive_key");

  // The subscription, not the key, is the source of truth for what's paid for.
  const { data: subscription } = await admin
    .from("subscriptions")
    .select("plan, status, current_period_end")
    .eq("user_id", license.user_id)
    .maybeSingle();

  const planId = subscription?.plan && isPlanId(subscription.plan) ? subscription.plan : "free";
  const status = subscription?.status ?? "active";
  const active = status === "active" || status === "trialing";

  // Record the check so an abandoned key can be spotted later.
  await admin
    .from("license_keys")
    .update({ last_seen_at: new Date().toISOString() })
    .eq("key", key);

  return NextResponse.json<Entitlements>({
    valid: active,
    plan: planId,
    cloudVoices: active && getPlan(planId).cloudVoices,
    status,
    expiresAt: subscription?.current_period_end ?? null,
  });
}
