// send-alert-email: Sends a single critical alert email via Resend.
//
// Deploy: supabase functions deploy send-alert-email
// Env:    RESEND_API_KEY (set via `supabase secrets set RESEND_API_KEY=re_...`)
//
// Test:  curl -X POST -H "Authorization: Bearer <anon-key>" \
//          -H "Content-Type: application/json" \
//          -d '{"type":"pf","site":"Main Site","meter":"HT-I","title":"Low PF","message":"PF is 0.88"}' \
//          https://<project>.functions.supabase.co/send-alert-email
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const RESEND_FROM = Deno.env.get("RESEND_FROM") ?? "PowerEMS <supports@brilliants.in>";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function severityColor(severity: string): string {
  switch (severity) {
    case "critical": return "#DC2626";
    case "warning": return "#F59E0B";
    default: return "#3B82F6";
  }
}

function severityEmoji(type: string): string {
  switch (type) {
    case "pf": return "&#9888;&#65039;";
    case "md": return "&#128680;";
    case "bill_spike": return "&#128176;";
    case "consumption": return "&#9889;";
    case "reminder": return "&#128221;";
    default: return "&#128276;";
  }
}

function buildHtml(title: string, message: string, severity: string, type: string): string {
  const color = severityColor(severity);
  const emoji = severityEmoji(type);
  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:24px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.1);">
        <tr><td style="background:${color};padding:20px 24px;">
          <span style="font-size:24px;">${emoji}</span>
          <span style="color:#fff;font-size:18px;font-weight:700;margin-left:8px;">${title}</span>
        </td></tr>
        <tr><td style="padding:24px;">
          <p style="font-size:14px;color:#374151;line-height:1.6;margin:0 0 16px;">${message}</p>
          <table width="100%" cellpadding="0" cellspacing="0" style="background:#F9FAFB;border-radius:8px;padding:12px 16px;">
            <tr><td style="font-size:12px;color:#6B7280;">
              Severity: <strong style="color:${color};">${severity.toUpperCase()}</strong><br>
              Time: ${new Date().toLocaleString("en-IN", { timeZone: "Asia/Kolkata" })}
            </td></tr>
          </table>
        </td></tr>
        <tr><td style="padding:0 24px 24px;">
          <a href="https://vickskamble.github.io/Energy-Management-System/"
             style="display:inline-block;background:#3B82F6;color:#fff;padding:10px 20px;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">
            View Dashboard
          </a>
        </td></tr>
        <tr><td style="padding:12px 24px;background:#F9FAFB;border-top:1px solid #E5E7EB;">
          <p style="font-size:11px;color:#9CA3AF;margin:0;">PowerEMS &mdash; Energy Management System</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // Authenticate the caller via Supabase JWT.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const { type, site, meter, title, message, severity = "critical" } = await req.json();

    if (!type || !title || !message) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: type, title, message" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Fetch the user's alert email from user_settings.data JSONB.
    const { data: settings } = await supabase
      .from("user_settings")
      .select("data")
      .eq("user_id", user.id)
      .maybeSingle();

    const alertEmail = settings?.data?.alert_email;
    if (!alertEmail || typeof alertEmail !== "string") {
      return new Response(
        JSON.stringify({ error: "No alert email configured. Set it in Settings > Account." }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Log the alert.
    await supabase.from("alert_log").insert({
      user_id: user.id,
      alert_type: type,
      severity,
      site: site ?? null,
      meter: meter ?? null,
      title,
      message,
      emailed: true,
      email_sent_at: new Date().toISOString(),
    });

    // Send via Resend.
    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: RESEND_FROM,
        to: [alertEmail],
        subject: `[PowerEMS ${severity.toUpperCase()}] ${title}`,
        html: buildHtml(title, message, severity, type),
      }),
    });

    if (!emailResponse.ok) {
      const errText = await emailResponse.text();
      console.error("Resend error:", errText);
      return new Response(
        JSON.stringify({ error: "Email send failed", details: errText }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, email: alertEmail }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("send-alert-email error:", e);
    return new Response(
      JSON.stringify({ error: "Internal error" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
