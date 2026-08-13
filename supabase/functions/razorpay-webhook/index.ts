// Razorpay webhook: verifies signature, syncs subscription state, logs events,
// and rewards referrers (+1 month) on the referred client's first activation.
//
// Configure in Razorpay Dashboard -> Settings -> Webhooks:
//   URL: https://onfovsadlqeebguuswzg.functions.supabase.co/razorpay-webhook
//   Events: subscription.authenticated, subscription.activated,
//           subscription.paid, subscription.charged, subscription.halted,
//           subscription.cancelled, subscription.completed,
//           subscription.paused, subscription.resumed, subscription.expired,
//           payment.failed, payment_link.paid
//   Secret: RAZORPAY_WEBHOOK_SECRET
//
// Deploy: supabase functions deploy razorpay-webhook --no-verify-jwt
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  SUPABASE_SERVICE_KEY,
);

const STATUS_MAP: Record<string, string> = {
  "subscription.authenticated": "authenticated",
  "subscription.activated": "active",
  "subscription.paid": "active",
  "subscription.charged": "active",
  "subscription.halted": "halted",
  "subscription.cancelled": "cancelled",
  "subscription.completed": "completed",
  "subscription.paused": "paused",
  "subscription.resumed": "active",
  "subscription.expired": "expired",
};

function verifySignature(body: string, signature: string): boolean {
  const key = new TextEncoder().encode(WEBHOOK_SECRET);
  const data = new TextEncoder().encode(body);
  return crypto.subtle
    .importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"])
    .then((k) => crypto.subtle.sign("HMAC", k, data))
    .then((sig) => {
      const expected = new Uint8Array(sig);
      let decoded: Uint8Array;
      try {
        const raw = atob(signature);
        decoded = Uint8Array.from(raw, (c) => c.charCodeAt(0));
      } catch {
        return false;
      }
      if (expected.length !== decoded.length) return false;
      let diff = 0;
      for (let i = 0; i < expected.length; i++) diff |= expected[i] ^ decoded[i];
      return diff === 0;
    })
    .catch(() => false);
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  const body = await req.text();
  const signature = req.headers.get("x-razorpay-signature") ?? "";
  if (!signature || !(await verifySignature(body, signature))) {
    return new Response("invalid signature", { status: 400 });
  }

  let event;
  try {
    event = JSON.parse(body);
  } catch {
    return new Response("invalid json", { status: 400 });
  }

  const eventType: string = event.event ?? "";
  const entity = event.payload?.subscription?.entity ?? {};
  // payment links carry the user in notes; subscription events carry it in notes too.
  const userId: string | undefined =
    entity.notes?.user_id ??
    (event.payload?.payment_link?.entity?.notes?.user_id as string | undefined);
  const subscriptionId: string | undefined = entity.id;

  // Extra-meter add-on top-ups: payment_link.paid applies the delta to the
  // existing (active) subscription — the base ₹799 is never re-charged.
  const linkEntity = event.payload?.payment_link?.entity as
    | {
        id?: string;
        notes?: { user_id?: string; delta_meters?: number; action?: string };
      }
    | undefined;
  if (eventType === "payment_link.paid" &&
      linkEntity?.notes?.action === "extra_meter_addon") {
    const addonUserId = linkEntity.notes.user_id ?? null;
    const delta = Math.max(1, Math.min(50, Number(linkEntity.notes.delta_meters) || 0));
    const linkId = linkEntity.id ?? "";
    if (addonUserId && delta > 0) {
      const { data: cur } = await supabase
        .from("subscriptions")
        .select("extra_meters, payment_link_id")
        .eq("user_id", addonUserId)
        .single();
      // Idempotency: Razorpay retries deliveries; never apply a link twice.
      if (cur && cur.payment_link_id !== linkId) {
        const { error: linkError } = await supabase
          .from("subscriptions")
          .update({
            extra_meters: Math.min(50, (cur.extra_meters ?? 0) + delta),
            payment_link_id: linkId,
            paid_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", addonUserId);
        if (linkError) {
          console.error("payment link addon update failed:", linkError.message);
        } else {
          console.log(
            `extra_meter_addon applied: +${delta} for user ${addonUserId}`,
          );
        }
      }
    }
  }

  const { error: logError } = await supabase.from("billing_events").upsert(
    {
      razorpay_event_id: event.unique_id ?? eventType,
      event_type: eventType,
      user_id: userId ?? null,
      payload: entity,
    },
    { onConflict: "razorpay_event_id" },
  );
  if (logError) {
    console.error("billing_events insert failed:", logError.message);
  }

  if (userId && subscriptionId && STATUS_MAP[eventType]) {
    const status = STATUS_MAP[eventType];
    const { error: subError } = await supabase.from("subscriptions").upsert(
      {
        user_id: userId,
        razorpay_subscription_id: subscriptionId,
        status,
        current_period_start: entity.period_start
          ? new Date(entity.period_start * 1000).toISOString()
          : null,
        current_period_end: entity.period_end
          ? new Date(entity.period_end * 1000).toISOString()
          : null,
      },
      { onConflict: "user_id" },
    );
    if (subError) {
      console.error("subscriptions upsert failed:", subError.message);
    }

    // Reward the referrer once, when the referred client first becomes active.
    if (status === "active" || status === "authenticated") {
      const { data: rewarded } = await supabase.rpc("reward_referral", {
        p_referred_user_id: userId,
      });
      if (rewarded) console.log(`referral rewarded for referrer of ${userId}`);
    }
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
