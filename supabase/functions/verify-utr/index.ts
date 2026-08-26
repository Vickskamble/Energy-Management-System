// UTR payment verification: auto-verify bank transfer payments.
//
// Client submits UTR number + amount paid. Backend checks:
//   1. Amount matches expected plan price → auto-activate
//   2. Amount doesn't match → flag for review
//   3. Duplicate UTR → reject
//
// Deploy: supabase functions deploy verify-utr --no-verify-jwt
// Test: curl -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
//   -d '{"utr_number":"123456789","amount_paid":25500,"plan_name":"growth","plan_term":"yearly","extra_data_points":0,"bank_name":"Bank of Baroda"}' \
//   https://onfovsadlqeebguuswzg.functions.supabase.co/verify-utr
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

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
  },
  growth: {
    monthly: 2500,
    quarterly: 6750,
    yearly: 25500,
    extraMonthly: 499,
    extraQuarterly: 399,
    extraYearly: 299,
    dataPoints: 5,
  },
  pro: {
    monthly: 5000,
    quarterly: 13500,
    yearly: 50000,
    extraMonthly: 799,
    extraQuarterly: 649,
    extraYearly: 499,
    dataPoints: 10,
  },
};

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function expectedAmount(
  planName: string,
  planTerm: string,
  extraDP: number,
): number {
  const plan = PLANS[planName];
  if (!plan) return -1;
  const base =
    planTerm === "yearly"
      ? plan.yearly
      : planTerm === "quarterly"
        ? plan.quarterly
        : plan.monthly;
  const extraRate =
    planTerm === "yearly"
      ? plan.extraYearly
      : planTerm === "quarterly"
        ? plan.extraQuarterly
        : plan.extraMonthly;
  return base + extraDP * extraRate;
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

  try {
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

    const body = await req.json();
    const utrNumber = String(body.utr_number ?? "").trim();
    const amountPaid = Number(body.amount_paid) || 0;
    const planName = String(body.plan_name ?? "growth").toLowerCase();
    const planTerm = String(body.plan_term ?? "monthly").toLowerCase();
    const extraDP = Math.max(0, Math.min(20, Number(body.extra_data_points) || 0));
    const bankName = String(body.bank_name ?? "");

    // Validate inputs
    if (!utrNumber || utrNumber.length < 5) {
      return json({ verified: false, error: "INVALID_UTR" }, 400);
    }
    if (amountPaid <= 0) {
      return json({ verified: false, error: "INVALID_AMOUNT" }, 400);
    }
    if (!PLANS[planName]) {
      return json({ verified: false, error: "INVALID_PLAN" }, 400);
    }

    // Calculate expected amount
    const expected = expectedAmount(planName, planTerm, extraDP);
    if (expected < 0) {
      return json({ verified: false, error: "INVALID_PLAN_TERM" }, 400);
    }

    // Auto-verify: check if amount matches (within ₹1 tolerance for rounding)
    const autoVerified = Math.abs(amountPaid - expected) <= 1;

    const totalDP = PLANS[planName].dataPoints + extraDP;

    // Call the SQL RPC to activate (inserts payment + updates subscription)
    const { data, error } = await supabase.rpc("activate_utr_payment", {
      p_user_id: user.id,
      p_utr_number: utrNumber,
      p_amount_paid: amountPaid,
      p_plan_name: planName,
      p_plan_term: planTerm,
      p_data_points: totalDP,
      p_extra_data_points: extraDP,
      p_bank_name: bankName,
      p_auto_verified: autoVerified,
    });

    if (error) {
      const msg = error.message ?? "";
      if (msg.includes("DUPLICATE_UTR")) {
        return json({ verified: false, error: "DUPLICATE_UTR" }, 409);
      }
      console.error("activate_utr_payment error:", msg);
      return json({ verified: false, error: "SERVER_ERROR" }, 500);
    }

    const result = data as Record<string, unknown>;
    return json({
      verified: result.verified ?? false,
      plan_activated: result.plan_activated ?? false,
      plan_name: planName,
      plan_term: planTerm,
      data_points: totalDP,
      expected_amount: expected,
      amount_paid: amountPaid,
      period_end: result.period_end ?? null,
      message: autoVerified
        ? "Payment verified and plan activated successfully."
        : "Amount mismatch — payment flagged for review.",
    });
  } catch (e) {
    console.error("verify-utr error:", String(e));
    return json({ verified: false, error: "INTERNAL_ERROR" }, 500);
  }
});
