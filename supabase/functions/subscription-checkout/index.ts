// SaaS subscription checkout: creates/updates a Razorpay subscription for the
// signed-in user and returns the hosted payment-page URL (UPI/cards/autopay).
//
// Pricing: base INR 2500/mo (includes 5 meters) + INR 499/mo per extra meter.
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
const BASE_AMOUNT = 2500; // INR / month (covers 5 meters)
const METER_RATE = 499; // INR / month per extra meter (monthly plan)
const YEARLY_AMOUNT = 25500; // INR / year (covers 5 meters)
const YEARLY_METER_RATE = 499; // INR / month per extra meter (yearly plan)
const TOTAL_COUNT = 24; // rolling 2-year mandate
const PAYMENT_DONE_URL =
  "https://app.brilliants.in/payment-done.html";

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

async function getOrCreateYearlyPlan(): Promise<string> {
  const res = await rzp("/plans?count=100");
  const { items } = await res.json();
  const existing = items?.find(
    (p: { item?: { name?: string }; amount?: number }) =>
      p.item?.name === "PowerEMS Yearly" && p.amount === YEARLY_AMOUNT * 100,
  );
  if (existing) return existing.id;
  const created = await rzp("/plans", {
    method: "POST",
    body: JSON.stringify({
      period: "yearly",
      interval: 1,
      item: { name: "PowerEMS Yearly", amount: YEARLY_AMOUNT * 100, currency: "INR" },
    }),
  });
  const body = await created.json();
  if (!body.id) throw new Error(`yearly plan create failed: ${JSON.stringify(body)}`);
  return body.id;
}

async function cancelOpenSubscription(subscriptionId: string) {
  try {
    await rzp(`/subscriptions/${subscriptionId}/cancel`, { method: "POST" });
  } catch {
    // already cancelled / completed — ignore
  }
}

async function createExtraMeterLink(
  user: { id: string; email: string },
  delta: number,
  planTerm: string,
) {
  const ratePerMonth = planTerm === "yearly" ? YEARLY_METER_RATE : METER_RATE;
  const amount = delta * ratePerMonth * (planTerm === "yearly" ? 12 : 1) * 100;
  const res = await rzp("/payment_links", {
    method: "POST",
    body: JSON.stringify({
      amount,
      currency: "INR",
      accept_partial: false,
      description:
        `PowerEMS extra meter${delta > 1 ? "s" : ""} (x${delta}) add-on (${planTerm})`,
      customer: { email: user.email },
      notes: {
        user_id: user.id,
        delta_meters: delta,
        plan_term: planTerm,
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
  let planTerm = "monthly";
  try {
    const body = await req.json();
    extraMeters = Math.max(0, Math.min(50, Number(body.extra_meters) || 0));
    if (body.plan_term === "yearly") planTerm = "yearly";
  } catch {
    // default 0 extra meters, monthly plan
  }

  const planId = planTerm === "yearly"
    ? await getOrCreateYearlyPlan()
    : await getOrCreateBasePlan();

  const { data: existing } = await supabase
    .from("subscriptions")
    .select("razorpay_subscription_id, status, extra_meters")
    .eq("user_id", user.id)
    .single();

  const existingStatus = existing?.status ?? "none";
  const isPaidBase = ["authenticated", "active"].includes(existingStatus);

  // Base plan active: extra meters are a one-time top-up payment link;
  // the webhook applies the delta on payment. Never re-charge the base plan.
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
    const link = await createExtraMeterLink(user, delta, planTerm);
    // Persist the link id on the subscription row BEFORE handing it to the
    // user: it is the idempotency key for applying the paid add-on (webhook
    // and/or payment-status fallback), since Razorpay delivery can be flaky.
    // paid_at is RESET to null here so a NEW add-on purchase is never
    // mistaken for an already-applied one (paid_at is the applied-flag).
    try {
      await supabase.from("subscriptions").update({
        payment_link_id: link.id,
        paid_at: null,
        updated_at: new Date().toISOString(),
      }).eq("user_id", user.id);
    } catch (e) {
      console.error("addon link persist failed:", String(e));
    }
    const ratePerMonth = planTerm === "yearly" ? YEARLY_METER_RATE : METER_RATE;
    return json({
      mode: "addon",
      payment_link_id: link.id,
      payment_url: link.short_url,
      short_url: link.short_url,
      subscription_id: "",
      delta_meters: delta,
      amount: delta * ratePerMonth * (planTerm === "yearly" ? 12 : 1),
      extra_meters: currentExtras + delta,
      status: existingStatus,
    });
  }

  // No active base plan: full checkout for the selected plan term.
  if (
    existing?.razorpay_subscription_id &&
    existingStatus === "created"
  ) {
    await cancelOpenSubscription(existing.razorpay_subscription_id);
  }

  const baseAmount = planTerm === "yearly" ? YEARLY_AMOUNT : BASE_AMOUNT;
  const meterRate = planTerm === "yearly" ? YEARLY_METER_RATE : METER_RATE;
  const addonUnit = meterRate * (planTerm === "yearly" ? 12 : 1) * 100;

  const addons = extraMeters > 0
    ? [{
        item: {
          name: `Extra meter${extraMeters > 1 ? "s" : ""} (x${extraMeters})`,
          amount: addonUnit,
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
      notes: { user_id: user.id, email: user.email, plan_term: planTerm },
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
    base_amount: baseAmount,
    meter_rate: meterRate,
    plan_term: planTerm,
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
    base_amount: baseAmount,
    meter_rate: meterRate,
    plan_term: planTerm,
  });
});
