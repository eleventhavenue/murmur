import { createClient } from "@supabase/supabase-js";
import { supabaseServiceKey, supabaseUrl } from "./config";

/**
 * Service-role client. Bypasses RLS, so it must only ever be constructed inside
 * route handlers and never imported into a client component.
 */
export function createAdminClient() {
  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error(
      "Supabase admin client requires NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY",
    );
  }
  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
