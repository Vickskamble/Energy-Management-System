// SaaS subscription checkout: creates/updates a Razorpay subscription for the
// signed-in user and returns the hosted payment-page URL (UPI/cards/autopay).
//
// 3-tier pricing: Starter ₹999 | Growth ₹2500 | Pro ₹5000 (monthly)
//   + quarterly and yearly variants + extra data points.
//
// Deploy: supabase functions deploy subscription-checkout --no-verify-jwt
// Env secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET (set via `supabase secrets set`)
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const RAZORPAY_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
const RAZORPAY_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
const PAYMENT_DONE_URL = "https://app.brilliants.in/payment-done.html";

// 3-tier pricing (must match subscription_config.dart exactly)
const PLANS: Record<
  string,
  {
    monthly: number;
    quarterly: number;
    yearly: number;
    extraMonthly: number;
    extraQuarterly: number;
    extraYearly: number;
    dataPoints: number;
    razorpayMonthly: string;
    razorpayYearly: string;
  }
> = {
  starter: {
    monthly: 999,
    quarterly: 2697,
    yearly: 9990,
    extraMonthly: 299,
    extraQuarterly: 249,
    extraYearly: 199,
    dataPoints: 2,
    razorpayMonthly: "PowerEMS Starter Monthly",
    razorpayYearly: "PowerEMS Starter Yearly",
  },
  growth: {
    monthly: 2500,
    quarterly: 6750,
    yearly: 25500,
    extraMonthly: 499,
    extraQuarterly: 399,
    extraYearly: 299,
    dataPoints: 5,
    razorpayMonthly: "PowerEMS Growth Monthly",
    razorpayYearly: "PowerEMS Growth Yearly",
  },
  pro: {
    monthly: 5000,
    quarterly: 13500,
    yearly: 50000,
    extraMonthly: 799,
    extraQuarterly: 649,
    extraYearly: 499,
    dataPoints: 10,
    razorpayMonthly: "PowerEMS Pro Monthly",
    razorpayYearly: "PowerEMS Pro Yearly",
  },
};

const TOTAL_COUNT = 24; // rolling 2-year mandate

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
      Authorization:
        "Basic " + btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`),
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });

async function getOrCreatePlan(
  planName: string,
  term: string,
): Promise<string> {
  const plan = PLANS[planName];
  if (!plan) throw new Error(`Unknown plan: ${planName}`);

  const razorpayName =
    term === "yearly" ? plan.razorpayYearly : plan.razorpayMonthly;
  const amount =
    (term === "yearly" ? plan.yearly : plan.monthly) * 100; // paise

  const res = await rzp("/plans?count=100");
  const { items } = await res.json();
  const existing = items?.find(
    (p: { item?: { name?: string }; amount?: number }) =>
      p.item?.name === razorpayName && p.amount === amount,
  );
  if (existing) return existing.id;

  const created = await rzp("/plans", {
    method: "POST",
    body: JSON.stringify({
      period: term === "yearly" ? "yearly" : "monthly",
      interval: 1,
      item: { name: razorpayName, amount, currency: "INR" },
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
    // already cancelled / completed
  }
}

async function createExtraDPAddonLink(
  user: { id: string; email: string },
  planName: string,
  delta: number,
  planTerm: string,
) {
  const plan = PLANS[planName];
  const ratePerMonth =
    planTerm === "yearly"
      ? plan.extraYearly
      : planTerm === "quarterly"
        ? plan.extraQuarterly
        : plan.extraMonthly;
  const months = planTerm === "yearly" ? 12 : planTerm === "quarterly" ? 3 : 1;
  const amount = delta * ratePerMonth * months * 100;

  const res = await rzp("/payment_links", {
    method: "POST",
    body: JSON.stringify({
      amount,
      currency: "INR",
      accept_partial: false,
      description: `PowerEMS ${planName} extra data point${delta > 1 ? "s" : ""} (x${delta}) — ${planTerm}`,
      customer: { email: user.email },
      notes: {
        user_id: user.id,
        plan_name: planName,
        delta_data_points: delta,
        plan_term: planTerm,
        action: "extra_dp_addon",
      },
      callback_url: PAYMENT_DONE_URL,
      callback_method: "get",
      reminder_enable: false,
    }),
  });
  const link = await res.json();
  if (!link.id)
    throw new Error(`payment link create failed: ${JSON.stringify(link)}`);
  return link;
}

async function getSubscriptionShortUrl(
  subscriptionId: string,
): Promise<string> {
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
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return json({ error: "unauthorized" }, 401);
  if (user.email === "demo@powerems.com") {
    return json({ error: "demo account is free" }, 400);
  }

  let planName = "growth";
  let extraDP = 0;
  let planTerm = "monthly";
  try {
    const body = await req.json();
    planName = String(body.plan_name ?? "growth").toLowerCase();
    extraDP = Math.max(0, Math.min(20, Number(body.extra_data_points) || 0));
    planTerm = String(body.plan_term ?? "monthly").toLowerCase();
  } catch {
    // defaults
  }

  if (!PLANS[planName]) {
    return json({ error: `Unknown plan: ${planName}` }, 400);
  }

  const planId = await getOrCreatePlan(planName, planTerm);

  const { data: existing } = await supabase
    .from("subscriptions")
    .select(
      "razorpay_subscription_id, status, plan_name, plan_term, extra_data_points, extra_meters",
    )
    .eq("user_id", user.id)
    .single();

  const existingStatus = existing?.status ?? "none";
  const isPaidBase = ["authenticated", "active"].includes(existingStatus);
  const samePlan = (existing?.plan_name ?? "") === planName;
  const sameTerm = (existing?.plan_term ?? "") === planTerm;

  // Same plan + same term: extra data points are a one-time addon (or noop).
  if (isPaidBase && samePlan && sameTerm) {
    const currentExtras =
      existing?.extra_data_points ?? existing?.extra_meters ?? 0;
    const delta = extraDP - currentExtras;
    if (delta <= 0) {
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
    const link = await createExtraDPAddonLink(user, planName, delta, planTerm);
    try {
      await supabase
        .from("subscriptions")
        .update({
          payment_link_id: link.id,
          paid_at: null,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", user.id);
    } catch (e) {
      console.error("addon link persist failed:", String(e));
    }
    const plan = PLANS[planName];
    const ratePerMonth =
      planTerm === "yearly"
        ? plan.extraYearly
        : planTerm === "quarterly"
          ? plan.extraQuarterly
          : plan.extraMonthly;
    const months =
      planTerm === "yearly" ? 12 : planTerm === "quarterly" ? 3 : 1;
    return json({
      mode: "addon",
      payment_link_id: link.id,
      payment_url: link.short_url,
      short_url: link.short_url,
      subscription_id: "",
      delta_meters: delta,
      amount: delta * ratePerMonth * months,
      extra_meters: currentExtras + delta,
      status: existingStatus,
    });
  }

  // Plan change (upgrade/downgrade), term change, or no active plan:
  // cancel any open/old Razorpay subscription, then start a fresh full checkout
  // for the newly requested plan.
  if (existing?.razorpay_subscription_id) {
    await cancelOpenSubscription(existing.razorpay_subscription_id);
  }

  const plan = PLANS[planName];
  const baseAmount =
    planTerm === "yearly" ? plan.yearly : plan.monthly;
  const extraRate =
    planTerm === "yearly"
      ? plan.extraYearly
      : planTerm === "quarterly"
        ? plan.extraQuarterly
        : plan.extraMonthly;
  const addonUnit = extraRate * (planTerm === "yearly" ? 12 : planTerm === "quarterly" ? 3 : 1) * 100;

  const addons =
    extraDP > 0
      ? [
          {
            item: {
              name: `Extra data point${extraDP > 1 ? "s" : ""} (x${extraDP})`,
              amount: addonUnit,
              currency: "INR",
            },
            quantity: extraDP,
          },
        ]
      : [];

  const created = await rzp("/subscriptions", {
    method: "POST",
    body: JSON.stringify({
      plan_id: planId,
      total_count: TOTAL_COUNT,
      customer_notify: 1,
      notes: {
        user_id: user.id,
        email: user.email,
        plan_name: planName,
        plan_term: planTerm,
      },
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
    plan_name: planName,
    plan_term: planTerm,
    extra_data_points: extraDP,
    extra_meters: extraDP,
    base_amount: baseAmount,
    meter_rate: extraRate,
  });

  if (upsertError) {
    return json({ error: upsertError.message }, 500);
  }

  return json({
    mode: "full",
    subscription_id: sub.id,
    short_url: sub.short_url,
    status: sub.status,
    extra_meters: extraDP,
    amount: baseAmount,
    base_amount: baseAmount,
    meter_rate: extraRate,
    plan_name: planName,
    plan_term: planTerm,
  });
});
