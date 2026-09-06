/**
 * One place that answers "is this integration actually connected?".
 *
 * The site is meant to run and be reviewable with no keys at all, so every
 * integration is optional. When something is missing we render a complete UI
 * backed by demo data and say so plainly, rather than crashing or, worse,
 * pretending a payment succeeded.
 */

function env(name: string): string | undefined {
  const value = process.env[name];
  return value && value.length > 0 ? value : undefined;
}

export const supabaseUrl = env("NEXT_PUBLIC_SUPABASE_URL");
export const supabaseAnonKey = env("NEXT_PUBLIC_SUPABASE_ANON_KEY");
export const supabaseServiceKey = env("SUPABASE_SERVICE_ROLE_KEY");

export const stripeSecretKey = env("STRIPE_SECRET_KEY");
export const stripeWebhookSecret = env("STRIPE_WEBHOOK_SECRET");
export const stripeProPriceId = env("STRIPE_PRO_PRICE_ID");
export const stripeProPlusPriceId = env("STRIPE_PRO_PLUS_PRICE_ID");

/** Server-side TTS key. Lets Pro subscribers use cloud voices without their own. */
export const cartesiaApiKey = env("CARTESIA_API_KEY");
export const isCloudTtsConfigured = Boolean(cartesiaApiKey);

/** Auth and the account page work. */
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

/** Webhooks and license issuance can write to the database. */
export const isSupabaseAdminConfigured = Boolean(supabaseUrl && supabaseServiceKey);

/** Checkout can actually be started. */
export const isStripeConfigured = Boolean(
  stripeSecretKey && (stripeProPriceId || stripeProPlusPriceId),
);

/** True when the whole paid flow is live end to end. */
export const isBillingLive = isStripeConfigured && isSupabaseAdminConfigured && Boolean(stripeWebhookSecret);

/** Names of the variables still missing, for display in setup notices. */
export function missingBillingEnv(): string[] {
  const missing: string[] = [];
  if (!supabaseUrl) missing.push("NEXT_PUBLIC_SUPABASE_URL");
  if (!supabaseAnonKey) missing.push("NEXT_PUBLIC_SUPABASE_ANON_KEY");
  if (!supabaseServiceKey) missing.push("SUPABASE_SERVICE_ROLE_KEY");
  if (!stripeSecretKey) missing.push("STRIPE_SECRET_KEY");
  if (!stripeWebhookSecret) missing.push("STRIPE_WEBHOOK_SECRET");
  if (!stripeProPriceId) missing.push("STRIPE_PRO_PRICE_ID");
  if (!stripeProPlusPriceId) missing.push("STRIPE_PRO_PLUS_PRICE_ID");
  return missing;
}

export const siteUrl =
  env("NEXT_PUBLIC_SITE_URL") ??
  (env("VERCEL_PROJECT_PRODUCTION_URL") ? `https://${env("VERCEL_PROJECT_PRODUCTION_URL")}` : undefined) ??
  "http://localhost:3000";

export const githubRepo = env("NEXT_PUBLIC_GITHUB_REPO") ?? "eleventhavenue/murmur";
