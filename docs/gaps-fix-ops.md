# PowerEMS — Server-Side Gap Closure Pack (Ops)

> Everything in this file is **server/ops side** — it cannot be fixed from the Flutter repo alone.
> Apply in order. Items marked ⏳ need access to the Supabase project dashboard / CLI / GitHub Pages CDN.

---

## 1. G4 — Verify RLS is Actually Enabled in Production

Run this in **Supabase → SQL Editor** (production project). It lists every table with RLS status and its policies:

```sql
SELECT
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY c.relname;

-- Every table must show rls_enabled = true.
-- If any is false:
ALTER TABLE public.<table_name> ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.<table_name> FORCE ROW LEVEL SECURITY;  -- recommended
```

Expected tables: `energy_logs`, `sites`, `panels`, `meters`, `readings`, `contract_demands`, `analysis_results`, `user_sessions`, `user_meters`, `user_settings`, `bill_reconcile`.

Then spot-check isolation (as a non-owner role / second user):

```sql
-- This must return 0 rows / be rejected when run by another user:
SET ROLE authenticated;
SELECT user_id, count(*) FROM public.energy_logs
WHERE user_id <> auth.uid() GROUP BY user_id;
```

---

## 2. Server-Side Password Policy (G5)

### 2a. Supabase Auth setting (5 min, recommended)
Dashboard → **Authentication → Providers / Settings → Security**:
- **"Minimum password length" → 8** (enforced server-side for all new passwords).
- Enable **"Confirm email"** already on; keep password recovery on.

No code change needed — Supabase enforces min length at the API level.

### 2b. Optional Edge Function for complexity checks
Create `supabase/functions/password-policy/index.ts`:

```ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const MIN = 8;
serve(async (req) => {
  try {
    const { password } = await req.json();
    const hasLetter = /[A-Za-z]/.test(password ?? "");
    const hasDigit = /[0-9]/.test(password ?? "");
    const ok = (password?.length ?? 0) >= MIN && hasLetter && hasDigit;
    return new Response(
      JSON.stringify({ ok, message: ok ? "ok" : `Min ${MIN} chars, one letter and one digit` }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (_) {
    return new Response(JSON.stringify({ ok: false, message: "invalid request" }), { status: 400 });
  }
});
```

Deploy: `supabase functions deploy password-policy` (requires Supabase CLI). Wiring the app to call it before signUp is optional (client already validates).

---

## 3. G12 — Server-Side Session Revocation (hard enforcement)

`SessionGuard` stays fail-open client-side (offline tolerance). This adds a **server-side gate**: an Edge Function that checks `user_sessions.last_seen` and rejects API calls when another device took over.

### 3a. Migration (run in SQL Editor)

```sql
-- Hard server-side check helper: true when this device token is the CURRENT owner.
create or replace function public.is_session_owner(p_token text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_sessions
    where user_id = auth.uid()
      and device_token = p_token
      and last_seen_at > now() - interval '3 minutes'
  );
$$;
```

### 3b. Edge Function `session-gate`

```ts
// supabase/functions/session-gate/index.ts
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
    return new Response("session revoked — another device took over", { status: 403 });
  }
  return new Response("ok");
});
```

Deploy: `supabase functions deploy session-gate`.

### 3c. Optional app-side hook (Phase 3)
Add the header + a periodic call in `EnergyLogRemoteDatasource`:

```dart
// request interceptor in supabase_client.dart (example)
final deviceToken = await SessionGuard.instance.token();
headers['x-device-token'] = deviceToken;
```

> Until the function is deployed and wired, G12 remains documented as **fail-open by design** (convenience control).

---

## 4. G6 — MFA (TOTP) Implementation Guide (ready to code)

Supabase Auth supports TOTP natively. Flow to add in-app (recommended: dedicated Settings → Security screen + login challenge):

### 4a. Enrollment (Settings → Security → "Enable 2FA")
```dart
final res = await supabase.auth.mfa.enroll(factorType: FactorType.totp);
// res.totp.qrCode = otpauth://totp/... (display as text or QR)
// res.totp.secret  = raw secret for manual entry
// store res.id as the factorId
```
Then verify enrollment (user enters a code from their authenticator app):
```dart
final challenge = await supabase.auth.mfa.challenge(factorId: res.id);
final verify = await supabase.auth.mfa.verify(
  challengeId: challenge.id,
  code: userEnteredCode,
);
// success → factor enrolled (verify.ticket -> updateUser? no — for enrollment
// the current session is upgraded to aal2 automatically after verify)
```

### 4b. Login challenge (after `signInWithPassword`)
```dart
final res = await supabase.auth.signInWithPassword(email: e, password: p);
final factors = res.user?.factors?.where((f) => f.status == FactorStatus.verified);
if (factors != null && factors.isNotEmpty) {
  // aal1 session active but 2FA required → emit AppAuthMfaRequired(factorId)
  final challenge = await supabase.auth.mfa.challenge(factorId: factors.first.id);
  // → show OTP screen → verify as in 4a → then proceed to session-guard flow
}
```
On app restart, check `await supabase.auth.mfa.getAuthenticatorAssuranceLevel()`; if `nextLevel == AuthenticatorAssuranceLevel.aal2` and `currentLevel != aal2`, re-prompt.

> ⏳ Recommended as a dedicated task with device testing — it touches the critical login path. All APIs above are available in the already-installed `supabase_flutter`.

---

## 5. G11 — Certificate Pinning (defer with plan)

Pinning mistakes lock users out; require a rotation plan:
1. Pin Supabase host via `flutter_secure_storage`-independent pin store with **two** pins (primary + backup).
2. Use a pinning HTTP client (e.g. `http` + manual `SecurityContext` on IO; web is browser-managed — pinning on web is not meaningful, document it).
3. Rotate quarterly; keep a remote "pin update" mechanism before the primary expires.
> ⏳ Recommend only after MFA is live; web platform is exempt.

---

## 6. HSTS (web)

`<meta>` cannot set HSTS. Options:
- **GitHub Pages + custom domain:** enable TLS in the DNS provider / Pages settings; HSTS requires a supported host.
- **Cloudflare proxy (free):** set `Strict-Transport-Security: max-age=31536000; includeSubDomains` in a rule → simplest reliable path.
- **Netlify/Vercel:** `_headers` file / `netlify.toml` → add the same header.
> ⏳ Ops action on the hosting layer, no app code.

---

## 7. Penetration Test Checklist (Phase 3)

1. Auth: password reset link abuse, email enumeration, token replay, session fixation.
2. RLS: cross-user data access via every table + RPC (G4 SQL above as the base).
3. Import/restore: crafted xlsx/json (size, nesting, zip-bombs) — limits already enforced client-side.
4. Web: CSP bypass attempts, open redirects (none expected — no external redirects), XSS (Flutter canvas).
5. Supply chain: Dependabot clean, `flutter pub outdated` report reviewed monthly.

---

## 8. Status Board

| Gap | Fix | Owner action |
|---|---|---|
| G4 RLS verify | SQL in §1 | Run in Supabase SQL Editor |
| Server-side password policy | §2a dashboard setting (2b optional) | Supabase dashboard |
| G12 session revocation | §3 Edge Function + RPC | Deploy via Supabase CLI |
| G6 MFA | §4 guide (code ready) | Implement + device-test |
| G11 pinning | §5 plan | After MFA |
| HSTS | §6 hosting header | CDN/proxy config |
| Pen test | §7 checklist | External firm / Phase 3 |
| Demo account + git purge | — | Deferred by owner decision |
