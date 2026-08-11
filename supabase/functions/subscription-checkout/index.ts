// SaaS subscription checkout: creates/updates a Razorpay subscription for the
// signed-in user and returns the hosted payment-page URL (UPI/cards/autopay).
//
// Pricing: base INR 799/mo (includes 1st meter) + INR 99/mo per extra meter.
//
// Deploy: supabase functions deploy subscription-checkout --no-verify-jwt
// Env secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET (set via `supabase secrets set`)
//
// Test: curl -H "Authorization: Bearer <access-token>" -H "Content-Type: application/json" \
//         -d '{"extra_meters": 1}' \
//         https://onfovsadlqeebguuswzg.functions.supabase.co/subscription-checkout
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
const BASE_AMOUNT = 799; // INR / month
const METER_RATE = 99; // INR / month per extra meter
const TOTAL_COUNT = 24; // rolling 2-year mandate

const rzp = (path: string, init?: RequestInit) =>
  fetch(`https://api.razorpay.com/v1${path}`, {
    ...init,
    headers: {
      Authorization: "Basic " + btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`),
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });

async function getOrCreateBasePlan(): Promise<string> {
  const res = await rzp("/plans?count=100");
  const { items } = await res.json();
  const existing = items?.find(
    (p: { item?: { name?: string }; amount?: number }) =>
      p.item?.name === "PowerEMS Base" && p.amount === BASE_AMOUNT * 100,
  );
  if (existing) return existing.id;
  const created = await rzp("/plans", {
    method: "POST",
    body: JSON.stringify({
      period: "monthly",
      interval: 1,
      item: { name: "PowerEMS Base", amount: BASE_AMOUNT * 100, currency: "INR" },
    }),
  });
  const body = await created.json();
  if (!body.id) throw new Error(`plan create failed: ${JSON.stringify(body)}`);
  return body.id;
}

async function cancelOpenSubscription(subscriptionId: string) {
  try {
    await rzp(`/subscriptions/${subscriptionId}/cancel`, { method: "POST" });
  } catch {
    // already cancelled / completed — ignore
  }
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response("unauthorized", { status: 401 });
  if (user.email === "demo@example.com") {
    return new Response(JSON.stringify({ error: "demo account is free" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  let extraMeters = 0;
  try {
    const body = await req.json();
    extraMeters = Math.max(0, Math.min(50, Number(body.extra_meters) || 0));
  } catch {
    // default 0 extra meters
  }

  const planId = await getOrCreateBasePlan();

  const { data: existing } = await supabase
    .from("subscriptions")
    .select("razorpay_subscription_id")
    .eq("user_id", user.id)
    .single();

  const openStatuses = ["created", "authenticated"];
  if (
    existing?.razorpay_subscription_id &&
    openStatuses.includes(existing.status ?? "")
  ) {
    await cancelOpenSubscription(existing.razorpay_subscription_id);
  }

  const addons = extraMeters > 0
    ? [{
        item: {
          name: `Extra meter${extraMeters > 1 ? "s" : ""} (x${extraMeters})`,
          amount: METER_RATE * 100,
          currency: "INR",
        },
        quantity: extraMeters,
      }]
    : [];

  const created = await rzp("/subscriptions", {
    method: "POST",
    body: JSON.stringify({
      plan_id: planId,
      total_count: TOTAL_COUNT,
      customer_notify: 1,
      notes: { user_id: user.id, email: user.email },
      addons,
    }),
  });
  const sub = await created.json();
  if (!sub.id) {
    return new Response(JSON.stringify({ error: `razorpay: ${JSON.stringify(sub)}` }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error: upsertError } = await supabase.from("subscriptions").upsert({
    user_id: user.id,
    razorpay_subscription_id: sub.id,
    status: sub.status ?? "created",
    extra_meters: extraMeters,
    base_amount: BASE_AMOUNT,
    meter_rate: METER_RATE,
  });

  if (upsertError) {
    return new Response(JSON.stringify({ error: upsertError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      subscription_id: sub.id,
      short_url: sub.short_url,
      status: sub.status,
      extra_meters: extraMeters,
      base_amount: BASE_AMOUNT,
      meter_rate: METER_RATE,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
