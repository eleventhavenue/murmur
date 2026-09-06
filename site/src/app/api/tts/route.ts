import { createAdminClient } from "@/lib/supabase-admin";
import {
  cartesiaApiKey,
  isCloudTtsConfigured,
  isSupabaseAdminConfigured,
} from "@/lib/config";
import { getPlan, isPlanId } from "@/lib/plans";
import { isLicenseKey, normalizeLicenseKey } from "@/lib/license";

/**
 * Cloud voice synthesis for Pro subscribers.
 *
 * This is what people are actually paying for: premium voices without having to
 * sign up for Cartesia themselves and paste an API key into a desktop app. The
 * upstream key lives here and never reaches the client.
 *
 * Anyone who would rather bring their own key can still do that directly in the
 * desktop app, for free, forever. That path does not touch this endpoint.
 */

const DEMO_KEY = "MURMUR-DEMO-DEMO-DEMO-DEMO";
const SAMPLE_RATE = 24_000;

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Confirms the caller is entitled to cloud voices. */
async function authorize(key: string): Promise<{ ok: boolean; reason?: string }> {
  if (!key) return { ok: false, reason: "missing_license" };
  if (key === DEMO_KEY) return { ok: true };
  if (!isLicenseKey(key)) return { ok: false, reason: "malformed_license" };
  if (!isSupabaseAdminConfigured) return { ok: false, reason: "licensing_not_configured" };

  const admin = createAdminClient();

  const { data: license } = await admin
    .from("license_keys")
    .select("user_id, is_active")
    .eq("key", key)
    .maybeSingle();

  if (!license?.is_active) return { ok: false, reason: "invalid_license" };

  const { data: subscription } = await admin
    .from("subscriptions")
    .select("plan, status")
    .eq("user_id", license.user_id)
    .maybeSingle();

  const plan = subscription?.plan && isPlanId(subscription.plan) ? subscription.plan : "free";
  const active = subscription?.status === "active" || subscription?.status === "trialing";

  if (!active || !getPlan(plan).cloudVoices) {
    return { ok: false, reason: "plan_does_not_include_cloud_voices" };
  }

  return { ok: true };
}

export async function POST(req: Request) {
  const key = normalizeLicenseKey(req.headers.get("x-murmur-license") ?? "");

  const auth = await authorize(key);
  if (!auth.ok) {
    return json({ error: auth.reason }, auth.reason === "missing_license" ? 401 : 403);
  }

  if (!isCloudTtsConfigured) {
    return json(
      {
        error: "cloud_tts_not_configured",
        message: "Set CARTESIA_API_KEY to enable Murmur Cloud voices.",
      },
      503,
    );
  }

  let text: string;
  let voice: string;
  try {
    const body = await req.json();
    text = String(body.text ?? "").slice(0, 5000);
    voice = String(body.voice ?? "");
  } catch {
    return json({ error: "invalid_body" }, 400);
  }

  if (!text.trim()) return json({ error: "empty_text" }, 400);

  const upstream = await fetch("https://api.cartesia.ai/tts/bytes", {
    method: "POST",
    headers: {
      "X-API-Key": cartesiaApiKey!,
      "Cartesia-Version": "2025-04-16",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model_id: "sonic-3",
      transcript: text,
      voice: { mode: "id", id: voice || "694f9389-aac1-45b6-b726-9d9369183238" },
      output_format: {
        container: "raw",
        encoding: "pcm_f32le",
        sample_rate: SAMPLE_RATE,
      },
      language: "en",
    }),
  });

  if (!upstream.ok || !upstream.body) {
    const detail = await upstream.text().catch(() => "");
    console.error("Cartesia upstream failed:", upstream.status, detail.slice(0, 300));
    return json({ error: "upstream_failed", status: upstream.status }, 502);
  }

  // Stream straight through so the desktop app starts playing on first bytes.
  return new Response(upstream.body, {
    headers: {
      "Content-Type": "application/octet-stream",
      "X-Murmur-Sample-Rate": String(SAMPLE_RATE),
      "Cache-Control": "no-store",
    },
  });
}
