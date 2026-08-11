# PowerEMS — Security Overview (What Is Actually Applied)

> This document reflects the **current implemented state** (security register G1–G15, final audit 01 Aug 2026).
> A separate section lists documented Phase-2/3 gaps. Nothing here is aspirational — each item maps to code/schema/CI.

---

## 1. Architecture at a Glance

```
Flutter app (Android / iOS / Web / Windows / macOS)
   │  HTTPS (TLS end-to-end)
   ▼
Supabase (Postgres + PostgREST + Auth)
   ├─ Row-Level Security (RLS) on all 11 tables
   ├─ unique indexes + dedup guards
   └─ auth.uid() scoping, user_id default auth.uid()
```
- **Cloud-first:** every read/write goes through the Supabase API; no local data cache of logs (only device meta like token/reminder flags in sembast).
- **Typed PostgREST builders only** — no raw SQL in the app.

## 2. Database-Level Isolation (RLS)

Every table has per-user policies. Policy naming convention: `"Users can view/insert/update/delete own <table>"`.

**Tables (11):** `energy_logs`, `sites`, `panels`, `meters`, `readings`, `contract_demands`, `analysis_results`, `user_sessions`, `user_meters`, `user_settings`, `bill_reconcile`.

**Rule used everywhere:** `auth.uid() = user_id` (USING for select/update/delete, WITH CHECK for insert). `user_id` is server-defaulted to `auth.uid()` — a client cannot insert another user's rows.

**Defense-in-depth:** the app additionally filters `.eq('user_id', uid)` on every query, so data stays isolated even if RLS were misconfigured.

**Integrity guards:**
- Unique index `uq_energy_logs_user_meter_date` on `(user_id, meter_name, logged_at)` — blocks duplicate readings even on concurrent requests (TOCTOU-proof).
- Dedup cleanup keeps the newest row per `(user_id, meter_name, logged_at)`.

## 3. Authentication & Sessions

- Email/password with **email verification** and password reset; 15-second timeouts.
- **Password policy (registration):** min 8 chars, at least 1 letter + 1 digit; RFC-compliant email validation.
- **Single-device enforcement** (user-facing convenience + risk control):
  - persistent device token (sembast), `user_sessions` row per device,
  - 60-second heartbeat, 3-minute staleness window,
  - force sign-out on session conflict; returning device force-takes its own leftover row,
  - **demo account exempt** by design.
  - *Note: deliberately fail-open (any error → OK) — documented as a convenience control, not a security boundary.*
- **Token storage:** OS-level secure storage — Android Keystore, iOS/macOS Keychain, Windows DPAPI, Web Crypto (`flutter_secure_storage`).

## 4. Web Deployment Hardening (CI-injected)

Injected into `index.html` at build time, then **verified** and gated by the pipeline:
- **Content-Security-Policy:** `default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https:; font-src 'self' https://fonts.gstatic.com; connect-src 'self' https://*.supabase.co https://fonts.googleapis.com https://fonts.gstatic.com; worker-src 'self' blob:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: geolocation=(); microphone=(); camera=(); payment=(); usb=()`
- **Quality gates in CI:** fail if inline event handlers (`onerror=` etc.) or `eval()` appear; fail if `flutter_bootstrap.js` missing; fail if headers missing.

## 5. Input Validation & Data Hygiene

- **Readings:** no negatives, current ≥ previous, no future dates, consumed > 0 when a previous reading exists; first entry = baseline (0 units) with an explicit confirm dialog.
- **Duplicates:** blocked at app level and by DB unique index (see §2).
- **Import:** Excel ≤ 10 MB / 5,000 rows; restore ≤ 20 MB; automatic column mapping + per-row editable preview before any write.
- **Text fields:** length caps (60/100/100); no HTML surface (Flutter canvas — no innerHTML/XSS surface).
- **Errors:** sanitized user-facing messages; logging guard in release mode (no sensitive data in logs).
- **Numbers:** `double.tryParse` with validation on every numeric input.

## 6. Secrets & Keys

- `.env` is **gitignored**; CI injects `SUPABASE_URL` + `SUPABASE_ANON_KEY` from GitHub Secrets.
- `SUPABASE_ANON_KEY` is a publishable key — safe by design **only because RLS is enforced** (it is, on all tables).
- A leaked-credentials script (`seed_data.ps1`) was rewritten to env-var form (G1 closed); production demo account cleanup + git-history purge are tracked as pending cleanup.

## 7. Platform Hardening

- **Android:** only the INTERNET + POST_NOTIFICATIONS (API 33+, with runtime request) permissions are declared.
- **iOS:** no ATS exceptions (HTTPS only).
- **macOS:** release network entitlement fixed (G13).
- **Windows:** desktop notifications enabled — plugin initialized with AUMID `PowerEMS.EMS`, matching the installer shortcuts (toast notifications need a Start Menu shortcut with the same AUMID).
- **Notifications:** Android channel `ems_alerts`; month-end reading reminders (last 3 days of month if no reading) on Android/iOS/Windows.

## 8. Supply Chain & CI/CD

- **CI pipeline (every push):** `flutter test` → `dart analyze lib/` → dependency health check → APK + Web build → security-header injection + verification + quality gates → Pages deploy + Release assets.
- **Dependabot:** monthly dependency updates (pub) + monthly actions updates; `flutter pub outdated` report in CI.

## 9. Incident & Breach Handling (Operational)

1. Contain: revoke the affected user's sessions (single-device rows), rotate keys if any secret touched.
2. Assess: review RLS policies + access logs; scope of exposure is inherently limited by per-user row isolation.
3. Notify: affected users within 72 hours per applicable law; regulators where required.
4. Remediate: patch + regression tests + updated security register.
5. Post-mortem: documented in this repo's `SECURITY.md` register style.

## 10. Documented Gaps / Roadmap (Phase 2/3)

| ID | Gap | Plan |
|---|---|---|
| G4 | Verify RLS in production dashboard (Supabase admin) | SQL ready in `gaps-fix-ops.md` — run in SQL Editor |
| G6 | MFA (TOTP), account lockout, server-side rate limiting | Implementation guide ready in `gaps-fix-ops.md` |
| G11 | Certificate pinning | Post-MFA, with rotation plan |
| G12 | Server-side session revocation (hard enforcement) | Edge Function + RPC code ready in `gaps-fix-ops.md` |
| — | Server-side password policy | Supabase dashboard setting (min 8) + optional Edge Function |
| — | ~~Encrypted backups~~ | ✅ **Fixed — G19** (AES-256-GCM + PBKDF2 100k, passphrase) |
| — | HSTS header (meta-tag not honored) | via CDN/proxy — instructions in `gaps-fix-ops.md` |
| — | App Check / Edge Functions | Phase 3 |
| — | Penetration test | Phase 3 (funded) — checklist in `gaps-fix-ops.md` |

## 11. Compliance Documents (this package)

- `privacy-policy.md` — what we collect/store and why
- `terms-of-service.md` — usage terms & liability limits
- `dpa.md` — data-processing agreement (controller/processor roles)
- `nda.md` — mutual non-disclosure agreement
- `formulas.md` — full calculation reference

---

*Maintained per the security register (G1–G15) in `SECURITY.md`; verified by final audit 01 Aug 2026.*
