// G12: Server-side session revocation (hard enforcement).
// Deploy: supabase functions deploy session-gate
// Test: curl -H "Authorization: Bearer <access-token>" -H "x-device-token: <token>" \
//         https://onfovsadlqeebguuswzg.functions.supabase.co/session-gate
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response("unauthorized", { status: 401 });

  const token = req.headers.get("x-device-token") ?? "";
  if (!token) {
    return new Response("missing x-device-token", { status: 400 });
  }
  const { data: ok } = await supabase.rpc("is_session_owner", { p_token: token });
  if (ok !== true) {
    return new Response("session revoked - another device took over", { status: 403 });
  }
  return new Response("ok");
});
