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
const PAYMENT_DONE_URL =
  "https://Vickskamble.github.io/Energy-Management-System/payment-done.html";

// Browser (GitHub Pages web build) calls this edge function directly, so it
// must answer CORS preflights and attach the permissive CORS header on every
// response — otherwise the browser blocks the fetch and checkout fails.
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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

async function createExtraMeterLink(user: { id: string; email: string }, delta: number) {
  const res = await rzp("/payment_links", {
    method: "POST",
    body: JSON.stringify({
      amount: delta * METER_RATE * 100,
      currency: "INR",
      accept_partial: false,
      description: `PowerEMS extra meter${delta > 1 ? "s" : ""} (x${delta}) add-on`,
      customer: { email: user.email },
      notes: {
        user_id: user.id,
        delta_meters: delta,
        action: "extra_meter_addon",
      },
      callback_url: PAYMENT_DONE_URL,
      callback_method: "get",
      reminder_enable: false,
    }),
  });
  const link = await res.json();
  if (!link.id) throw new Error(`payment link create failed: ${JSON.stringify(link)}`);
  return link;
}

async function getSubscriptionShortUrl(subscriptionId: string): Promise<string> {
  try {
    const res = await rzp(`/subscriptions/${subscriptionId}`);
    const sub = await res.json();
    return (sub.short_url as string) ?? "";
  } catch {
    return "";
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return new Response("method not allowed", {
      status: 405,
      headers: CORS_HEADERS,
    });
  }
  const json = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);
  if (user.email === "demo@powerems.com") {
    return json({ error: "demo account is free" }, 400);
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
    .select("razorpay_subscription_id, status, extra_meters")
    .eq("user_id", user.id)
    .single();

  const existingStatus = existing?.status ?? "none";
  const isPaidBase = ["authenticated", "active"].includes(existingStatus);

  // Base plan active: never re-charge ₹799 — extra meters are a one-time
  // ₹99/meter top-up payment link; the webhook applies the delta on payment.
  if (isPaidBase) {
    const currentExtras = existing?.extra_meters ?? 0;
    const delta = extraMeters - currentExtras;
    if (delta <= 0) {
      // Backward-compatible noop: include the existing subscription's hosted
      // page URL so older app versions still open a payment page.
      const shortUrl = existing?.razorpay_subscription_id
        ? await getSubscriptionShortUrl(existing.razorpay_subscription_id)
        : "";
      return json({
        mode: "noop",
        subscription_id: existing?.razorpay_subscription_id ?? "",
        short_url: shortUrl,
        payment_url: shortUrl,
        extra_meters: currentExtras,
        status: existingStatus,
      });
    }
    const link = await createExtraMeterLink(user, delta);
    return json({
      mode: "addon",
      payment_link_id: link.id,
      payment_url: link.short_url,
      short_url: link.short_url,
      subscription_id: "",
      delta_meters: delta,
      amount: delta * METER_RATE,
      extra_meters: currentExtras + delta,
      status: existingStatus,
    });
  }

  // No active base plan: full checkout (₹799 base + ₹99 × extra meters).
  if (
    existing?.razorpay_subscription_id &&
    existingStatus === "created"
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
    return json({ error: `razorpay: ${JSON.stringify(sub)}` }, 502);
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
    return json({ error: upsertError.message }, 500);
  }

  return json({
    mode: "full",
    subscription_id: sub.id,
    short_url: sub.short_url,
    status: sub.status,
    extra_meters: extraMeters,
    base_amount: BASE_AMOUNT,
    meter_rate: METER_RATE,
  });
});
