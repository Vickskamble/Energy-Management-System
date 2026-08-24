// send-daily-digest: Batches all unemailed WARNING alerts per user into a
// single digest email, then marks them as emailed.
//
// Deploy: supabase functions deploy send-daily-digest
// Cron:   supabase cron schedule "daily-digest" "0 20 * * *" send-daily-digest
//         (runs daily at 8 PM IST)
// Env:    RESEND_API_KEY, SUPABASE_SERVICE_ROLE_KEY (for admin read)
//
// Test:  curl -X POST -H "Authorization: Bearer <service-role-key>" \
//          https://<project>.functions.supabase.co/send-daily-digest
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const RESEND_FROM = Deno.env.get("RESEND_FROM") ?? "PowerEMS <supports@brilliants.in>";

function buildDigestHtml(userEmail: string, alerts: Record<string, unknown>[]): string {
  const rows = alerts
    .map(
      (a) => `
    <tr>
      <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;">
        <span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${a.severity === "critical" ? "#DC2626" : "#F59E0B"};margin-right:6px;"></span>
        <strong style="font-size:13px;color:#111827;">${a.title}</strong>
      </td>
      <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;font-size:12px;color:#6B7280;">
        ${a.meter ? a.meter + " &mdash; " : ""}${a.site ?? ""}
      </td>
      <td style="padding:8px 12px;border-bottom:1px solid #E5E7EB;font-size:12px;color:#6B7280;">
        ${new Date(a.sent_at as string).toLocaleString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit" })}
      </td>
    </tr>`
    )
    .join("");

  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:24px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.1);">
        <tr><td style="background:#3B82F6;padding:20px 24px;">
          <span style="color:#fff;font-size:18px;font-weight:700;">&#128202; PowerEMS Daily Digest</span>
          <span style="color:rgba(255,255,255,.8);font-size:13px;margin-left:12px;">${alerts.length} alert(s)</span>
        </td></tr>
        <tr><td style="padding:16px 24px;">
          <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
            <tr style="background:#F9FAFB;">
              <td style="padding:8px 12px;font-size:11px;font-weight:700;color:#6B7280;text-transform:uppercase;letter-spacing:.5px;">Alert</td>
              <td style="padding:8px 12px;font-size:11px;font-weight:700;color:#6B7280;text-transform:uppercase;letter-spacing:.5px;">Meter / Site</td>
              <td style="padding:8px 12px;font-size:11px;font-weight:700;color:#6B7280;text-transform:uppercase;letter-spacing:.5px;">Time</td>
            </tr>
            ${rows}
          </table>
        </td></tr>
        <tr><td style="padding:0 24px 24px;">
          <a href="https://app.brilliants.in/"
             style="display:inline-block;background:#3B82F6;color:#fff;padding:10px 20px;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">
            View Dashboard
          </a>
        </td></tr>
        <tr><td style="padding:12px 24px;background:#F9FAFB;border-top:1px solid #E5E7EB;">
          <p style="font-size:11px;color:#9CA3AF;margin:0;">PowerEMS &mdash; Daily Digest &bull; ${new Date().toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" })}</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

serve(async (req) => {
  try {
    // Use service-role key for admin access (bypasses RLS).
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Find all users with unemailed warnings.
    const { data: pendingAlerts, error } = await supabase
      .from("alert_log")
      .select("user_id, id, alert_type, severity, site, meter, title, message, sent_at")
      .eq("emailed", false)
      .eq("severity", "warning")
      .order("sent_at", { ascending: true });

    if (error) {
      console.error("Query error:", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    if (!pendingAlerts || pendingAlerts.length === 0) {
      return new Response(JSON.stringify({ success: true, message: "No pending warnings" }));
    }

    // Group by user_id.
    const byUser = new Map<string, typeof pendingAlerts>();
    for (const alert of pendingAlerts) {
      const list = byUser.get(alert.user_id) ?? [];
      list.push(alert);
      byUser.set(alert.user_id, list);
    }

    const results: Array<{ user_id: string; emailed: number; error?: string }> = [];

    for (const [userId, alerts] of byUser) {
      // Fetch user's alert email.
      const { data: settings } = await supabase
        .from("user_settings")
        .select("data")
        .eq("user_id", userId)
        .maybeSingle();

      const email = settings?.data?.alert_email;
      if (!email || typeof email !== "string") {
        results.push({ user_id: userId, emailed: 0, error: "No alert email configured" });
        continue;
      }

      // Send digest email.
      const emailResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: RESEND_FROM,
          to: [email],
          subject: `[PowerEMS] Daily Digest — ${alerts.length} alert(s)`,
          html: buildDigestHtml(email, alerts),
        }),
      });

      if (!emailResponse.ok) {
        const errText = await emailResponse.text();
        console.error(`Resend error for ${userId}:`, errText);
        results.push({ user_id: userId, emailed: 0, error: errText });
        continue;
      }

      // Mark alerts as emailed.
      const ids = alerts.map((a) => a.id);
      await supabase
        .from("alert_log")
        .update({ emailed: true, email_sent_at: new Date().toISOString() })
        .in("id", ids);

      results.push({ user_id: userId, emailed: alerts.length });
    }

    return new Response(JSON.stringify({ success: true, results }));
  } catch (e) {
    console.error("send-daily-digest error:", e);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
});
