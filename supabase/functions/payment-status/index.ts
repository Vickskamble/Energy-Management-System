// Payment verification edge function: queries Razorpay DIRECTLY so the app
// can confirm a payment the moment it completes — the plan updates instantly
// without waiting for the webhook round-trip (the webhook still syncs the DB
// for server-side enforcement).
//
// Deploy: supabase functions deploy payment-status --no-verify-jwt
// Env secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET (set via `supabase secrets set`)
//
// Body: { "subscription_id": "sub_..." } for full checkouts
//   or: { "payment_link_id": "plink_..." } for extra-meter add-on links
// Response: { "paid": boolean, "razorpay_status": string }
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const rzp = (path: string) =>
  fetch(`https://api.razorpay.com/v1${path}`, {
    headers: {
      Authorization: "Basic " + btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`),
      "Content-Type": "application/json",
    },
  });

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405, headers: CORS_HEADERS });
  }
  const json = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });

  // Signed-in user only — keeps this from being used as an open API.
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);

  let body: { subscription_id?: unknown; payment_link_id?: unknown } = {};
  try {
    body = await req.json();
  } catch {
    // body stays empty
  }

  const subscriptionId =
    typeof body.subscription_id === "string" ? body.subscription_id.trim() : "";
  const paymentLinkId =
    typeof body.payment_link_id === "string" ? body.payment_link_id.trim() : "";
  if (!subscriptionId && !paymentLinkId) {
    return json({ error: "missing id" }, 400);
  }

  try {
    if (subscriptionId) {
      const res = await rzp(`/subscriptions/${encodeURIComponent(subscriptionId)}`);
      const sub = await res.json();
      if (!res.ok) {
        return json({ error: `razorpay: ${sub?.error?.description ?? "unknown"}` }, 502);
      }
      const paidCount = Number(sub?.paid_count) || 0;
      const paid = sub?.status === "active" && paidCount >= 1;
      return json({ paid, razorpay_status: sub?.status, paid_count: paidCount });
    }
    const res = await rzp(`/payment_links/${encodeURIComponent(paymentLinkId)}`);
    const link = await res.json();
    if (!res.ok) {
      return json({ error: `razorpay: ${link?.error?.description ?? "unknown"}` }, 502);
    }
    const amount = Number(link?.amount) || 0;
    const amountPaid = Number(link?.amount_paid) || 0;
    const paid = link?.status === "paid" && amount > 0 && amountPaid >= amount;
    return json({ paid, razorpay_status: link?.status, amount_paid: amountPaid });
  } catch (e) {
    return json({ error: String(e) }, 502);
  }
});