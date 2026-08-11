# PowerEMS — Security Documentation

**App:** PowerEMS (Energy Management System)
**Platforms:** Android, Web (GitHub Pages), Windows/macOS desktop (CI builds)
**Backend:** Supabase (Auth + Postgres + PostgREST)
**Local storage:** sembast (meta only — device token, last user, reminder flags)

This document is a living security audit: it covers the current security posture per layer, known gaps, and a prioritized improvement roadmap.

---

## 1. Security Posture Summary

| Layer | Control | Status |
|---|---|---|
| Authentication | Supabase Auth (email/password) | ✅ Implemented |
| Authorization | Row-Level Security (RLS) on all data tables | ✅ Implemented |
| Session management | Single-device enforcement + heartbeat | ⚠️ Partial (fail-open by design; server-side revocation deliverable ready) |
| Transport | HTTPS end-to-end | ✅ Implemented |
| Input validation | Client-side numeric/date validation + length caps | ✅ Implemented |
| Secrets | Supabase URL + anon key in `.env`, gitignored; CI from GitHub secrets | ✅ Implemented |
| Local data encryption | Session token via secure storage; backups AES-256-GCM (passphrase) | ✅ Implemented |
| Multi-factor auth | — | ⏳ Phase 2 (implementation guide ready) |
| Rate limiting / lockout | Supabase platform defaults only | ⏳ Phase 2 (dashboard settings + Edge Function options) |
| Dependency scanning | Dependabot + CI `pub outdated` | ✅ Implemented |

---

## 2. Application Architecture (Security View)

```
┌─────────────┐    HTTPS     ┌──────────────────────────────┐
│  Flutter App│ ───────────▶ │  Supabase (PostgREST + Auth) │
│ (Android/   │              │  ┌────────────────────────┐  │
│  Web/Windows)│             │  │ RLS scoped tables:     │  │
│             │              │  │ energy_logs, user_meters│ │
│  ┌────────┐ │              │  │ user_settings, bill_   │  │
│  │sembast │ │ ◀─────────── │  │ reconcile, user_sessions│ │
│  │meta db │ │  (local only)│  └────────────────────────┘  │
│  └────────┘ │              └──────────────────────────────┘
└─────────────┘
```

- **Business data is cloud-only.** No local cache of energy logs/bills (by design).
- **All queries use typed PostgREST builders** — no raw SQL, no SQL injection surface (`energy_log_remote_datasource.dart`, `meter_remote_datasource.dart`).
- **sembast** stores only non-critical meta: device token, last signed-in user id, reminder flag.

---

## 3. Layer-by-Layer Analysis

> **⚠️ Historical narrative (pre-audit state).** Section 3 describes the code as it was *before* the security fixes (register G1–G15, see §4) and does NOT reflect the current posture — e.g. it claims there is no `flutter_secure_storage`, that CI "destroys" `index.html`, and that the password policy is 6 chars. All of those are fixed. **For the current state, trust §4 (register) and §5 (roadmap), not §3.**

### 3.1 Authentication & Identity

**Implemented:**
- Email/password sign-in via Supabase Auth (`auth_bloc.dart:171`)
- Sign-up with email verification flow (auto sign-out until verified)
- Password reset via email link
- 15-second timeouts on all auth calls
- Logout releases the `user_sessions` row and stops the heartbeat

**Gaps:**
- **Weak password policy** — client enforces only 6-char minimum (`login_page.dart:140-142`, `register_page.dart:101-104`). No complexity requirements, no server-side policy.
- **Weak email validation** — only checks for `@` (`login_page.dart:110-112`).
- **No MFA / TOTP** — planned Phase 2.
- **No account lockout / throttling** — relies on Supabase platform defaults; not configurable per app.
- **Session token stored unencrypted** — browser localStorage (web), SharedPreferences (IO).

### 3.2 Authorization & Data Access (RLS) — *Core Strength*

RLS is the primary data protection control and is **comprehensively implemented**:

| Table | RLS Policy | File |
|---|---|---|
| `energy_logs`, `sites`, `panels`, `meters`, `readings`, `contract_demands`, `analysis_results`, `user_sessions` | `auth.uid() = user_id` | `supabase_schema.sql:149-294` |
| `user_meters`, `user_settings`, `bill_reconcile` | `auth.uid() = user_id` | `supabase_cloud_data_migration.sql:47-100` |
| `user_sessions` | `auth.uid() = user_id` | `supabase_single_device_migration.sql:16-34` |

- `user_id` defaults to `auth.uid()` server-side (INSERT `WITH CHECK`).
- Defense-in-depth: datasources also filter `.eq('user_id', uid)` client-side.
- Writes use typed `upsert` — no mass-assignment vectors.

**Gap:** RLS is only as good as the deployed schema. **Verify in the Supabase dashboard** that all policies are actually enabled in production (SQL files are authoritative, but drift is possible).

### 3.3 Session Management (Single-Device)

**Implemented:**
- Persistent per-device token in sembast (`session_guard.dart:50-70`)
- `user_sessions` row with 3-min staleness, 60-sec heartbeat
- Force sign-out on conflict detection

**Gap — Critical design decision:** `SessionGuard` is **fail-open** (`session_guard.dart:74-75, 95-98, 129-132`). Any error (table missing, network down, timeout) returns `SessionStatus.ok`. Single-device enforcement is a *convenience* control, **not a security boundary**. An attacker with stolen credentials is never blocked by it.

### 3.4 Secrets & Configuration

| Item | Status |
|---|---|
| `.env` in git | ❌ No (gitignored, verified empty in history) |
| Keys in CI | ✅ Injected from GitHub secrets (`deploy.yml:36-39`) |
| Key type | ✅ `sb_publishable_*` (safe-by-design to be public, **if RLS is enforced**) |
| **`seed_data.ps1`** | ⚠️ **CRITICAL GAP** — git-tracked with real URL + anon key + demo account `demo@example.com` / `REDACTED_PASSWORD` (`seed_data.ps1:6-7, 30-31`) |

**Recommended actions:**
1. **Delete the `demo@example.com` account** from the production Supabase project immediately.
2. Rewrite `seed_data.ps1` to read URL/key from environment variables (never hardcode).
3. The `.env` shipped as a Flutter asset (`pubspec.yaml:69`) exposes URL + anon key in every release build — acceptable for anon keys, but confirm RLS is on (see 3.2).

### 3.5 Data Protection & Local Storage

**Gaps:**
- **No local encryption anywhere** — no `flutter_secure_storage`, no `crypto` usage.
  - sembast meta DB: plaintext file (IO) / IndexedDB (web)
  - Supabase session token: plaintext localStorage (web) / SharedPreferences (IO)
- **Backup export is unencrypted JSON** (`backup_service.dart:43-52`) — anyone with device/backup file access reads all meter data, tariffs, bills. No password protection or encryption option.
- Recommended: `flutter_secure_storage` for the device token and session; encrypted backups (AES) with user passphrase; or disable backup export on shared devices.

### 3.6 Input Handling & Import

**Implemented:**
- Excel import restricted to `.xlsx`/`.xls`, parsed by the `excel` package (no macro/formula execution)
- All imported rows pass through a **user-editable preview dialog** before saving (`reports_page.dart:1107-1129`)
- Numeric parsing strips currency/whitespace; dates validated; future dates skipped
- Strong numeric validation in `energy_bloc.dart:170-232` (negatives, decreasing cumulative, future dates)
- **No XSS risk on web** — Flutter canvas rendering, no `innerHTML`/DOM injection paths (verified)

**Gaps:**
- **No file-size or row-count limits** on Excel import / backup restore — a crafted huge workbook can exhaust memory.
- **Bulk import bypasses the duplicate-reading guard** (`reports_page.dart:1143` vs `energy_bloc.dart:86-96`) and there is **no unique index** on `(user_id, meter_name, logged_at)` — double-submit/concurrent import can create duplicate readings (TOCTOU race).
- **No length caps** on meter name / location / site strings (`meter_management_page.dart`) — unbounded strings persist to DB.
- Backup restore `jsonDecode` has no size limit (scoped by RLS, low risk).

### 3.7 Network & Transport

**Implemented:**
- HTTPS everywhere (Supabase URL is HTTPS; iOS ATS defaults apply — no `NSAllowsArbitraryLoads`)
- Timeouts on all network calls (10–15 s)
- Web download path uses Blob + `URL.revokeObjectURL` (clean)

**Gaps:**
- **No certificate pinning** — a compromised CA or MITM proxy could read traffic. Consider pinning the Supabase host (trade-off: cert rotation burden).
- `connectivity_plus` is declared (`pubspec.yaml:35`) but **never used** — dead dependency, remove it.

### 3.8 Web-Specific Security

**Implemented (CI):**
- CSP meta tag: `default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self' https://*.supabase.co; frame-ancestors 'none'`
- `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`

**Gaps — Critical (CI pipeline):**
1. **`deploy.yml:89-97` DESTROYS the web build.** The "Configure Security Headers" step *overwrites* `build/web/index.html` with `>` instead of appending — the Flutter bootstrap (`<script src="flutter_bootstrap.js">`) is **deleted**, so the deployed site fails to load. The subsequent "Append Security Headers" step (`:100-107`) is a no-op.
2. **HSTS via `<meta>` does not work** (`deploy.yml:97`). HSTS is only honored as an HTTP response header (GitHub Pages does not emit it; requires custom domain + TLS config or a host that supports `_headers`/`netlify.toml`-style headers).
3. GitHub Pages serves static files with its own headers — meta tags are the *only* way to get CSP etc. Correct fix: **append** meta tags to the generated `index.html` (not overwrite).

### 3.9 Permissions & Platform Config

**Implemented:**
- Android: only `INTERNET` permission (main/debug/profile manifests). No sensitive permissions. ✅
- iOS: no ATS exceptions, notification permission requested as non-required. ✅

**Gaps:**
- **macOS release is broken by design**: `macos/Runner/Release.entitlements` is missing `com.apple.security.network.client` — release builds cannot make network calls.
- **Android 13+ (`POST_NOTIFICATIONS`)** runtime permission not declared — notifications silently fail on API 33+ (functional, not security).
- `.github/workflows/deploy.yml` **Security Report claims are false**: it prints "Account Lockout — Active (15-min)", "Password Policy — Active (12+ chars, complexity)", "Rate Limiting", "MFA — Ready" — **none of these exist in code**. This is misleading marketing, not verification.

### 3.10 Logging & Error Handling

**Implemented:**
- Network timeouts, structured error handling in BLoCs

**Gaps:**
- **Raw exception text shown to end users** (`reports_page.dart:222,1161`, `settings_page.dart:259,491,543,592`, `energy_log_remote_datasource.dart:38` "Detail: $e", error boundary shows stack lines at `app_error_boundary.dart:50-56`)
- **Release-mode logging** — `app_logger.dart` uses `debugPrint` without a `kReleaseMode` guard; logs persist in release consoles (`user_cache_guard.dart:39` logs user-id prefix). Strip/guard logging in release builds.

---

## 4. Security Gap Register (Prioritized)

| # | Priority | Gap | Status | Impact | Fix |
|---|---|---|---|---|---|
| G1 | 🔴 Critical | Live demo account `demo@example.com`/`REDACTED_PASSWORD` + hardcoded creds in git-tracked `seed_data.ps1` | ✅ Fixed (env vars, creds removed; delete demo account in Supabase still pending) | Account takeover, credential stuffing, data access | Rewrote script to use env vars; remove creds from git history (filter-branch/BFG) |
| G2 | 🔴 Critical | CI security-header step overwrites web `index.html` → deployed site broken; HSTS-meta non-functional | ✅ Fixed (Python injects meta tags; bootstrap preserved; verification fails on corruption) | DoS of the web app; false sense of HTTPS security | Meta tags appended into `<head>`; HSTS claim dropped |
| G3 | 🟠 High | No local encryption (sembast meta, session token, backups) | ✅ Fixed (session token via `flutter_secure_storage`; backups AES-256-GCM — G19) | Data exposure on device compromise | `flutter_secure_storage` for token; encrypted backups |
| G4 | 🟠 High | RLS effectiveness depends on production schema drift | ✅ Fixed (verified live 11 Aug 2026: all 11 tables `rls_enabled=true`, 49 policies, via `supabase db query --linked`) | Data leak if policies disabled | Verified in production + `is_session_owner` migration confirmed |
| G5 | 🟠 High | Weak password policy (6 chars), weak email validation | ✅ Fixed (client: min 8 chars, letter+digit, RFC email regex; server-side min-length 8 set in Supabase Auth settings 11 Aug 2026) | Brute force / account takeover | Client validation added; server-side enforcement enabled |
| G6 | 🟠 High | No MFA, no lockout/rate-limiting control | ⏳ Open | Credential attacks | Enable Supabase MFA (Phase 2); platform-level rate limiting |
| G7 | 🟡 Medium | TOCTOU duplicate readings — no unique index, bulk import bypasses duplicate guard | ✅ Fixed (unique index `(user_id, meter_name, logged_at)`; import dedupe) | Data integrity corruption | Unique index in `migrate_schema.sql`; duplicate check in import path |
| G8 | 🟡 Medium | No size/row limits on Excel import & backup restore | ✅ Fixed (10 MB / 5000 rows import; 20 MB restore) | Memory exhaustion | Size/row limits enforced with user-facing errors |
| G9 | 🟡 Medium | No length caps on meter name/location/site strings | ✅ Fixed (60/100/100 chars) | DB bloat, malformed records | maxLength validators on inputs |
| G10 | 🟡 Medium | Raw exceptions shown in UI; release-mode logging | ✅ Fixed | Information disclosure | User-friendly error messages; logging guarded by `kReleaseMode` |
| G11 | 🟡 Medium | No certificate pinning | ⏳ Open | MITM on compromised CAs | Pin Supabase host cert (with rotation plan) |
| G12 | 🟡 Medium | `SessionGuard` fail-open design | ✅ Fixed (server-side `session-gate` Edge Function + `is_session_owner` RPC deployed 11 Aug 2026; app-side header wiring = Phase 3) | Enforcement silently disabled offline | Edge Function deployed; wire `x-device-token` header in datasources |
| G13 | 🟢 Low | Dead dependency `connectivity_plus`; macOS release network entitlement missing | ✅ Fixed (dep removed; entitlement added; dead `core/security/` folder removed) | Attack surface + broken macOS build | Removed dependency; added entitlement |
| G14 | 🟢 Low | No dependency vulnerability scanning (Dependabot/OSV) | ✅ Fixed (Dependabot config + CI `pub outdated` check) | Known-CVE exposure | Dependabot monthly + CI outdated check added |
| G15 | 🟢 Low | False security claims in CI "Security Report" step | ✅ Fixed (honest verified/unimplemented list) | Trust erosion, misleading audit trail | Report rewritten with only verified claims |
| G16 | 🟢 Low | Android 13+ `POST_NOTIFICATIONS` permission not declared/requested | ✅ Fixed | Alerts silently blocked on API 33+ | Manifest permission + runtime request in `notification_service.dart` |
| G17 | 🟢 Low | Windows desktop notifications not supported (reminders/alerts desktop-only gap) | ✅ Fixed | No desktop alerts | Windows plugin init + AUMID on installer shortcuts |
| G18 | 🟢 Low | Login page enforced 6-char minimum while registration enforces 8+ | ✅ Fixed (login now uses `ValidationRules.validatePassword`) | Policy inconsistency | Shared validator on both pages |
| G19 | 🟢 Low | Backup export was plaintext JSON | ✅ Fixed (AES-256-GCM + PBKDF2 100k, passphrase-protected; legacy plaintext restore still supported) | Data exposure at rest / on device | `backup_service.dart` encryption; passphrase dialog in Settings |

---

## 5. Improvement Roadmap

### Phase 1 — Immediate (days) ✅ Done
1. ✅ Remove hardcoded creds from `seed_data.ps1` (G1)
2. ✅ Fix CI web header step to append (not overwrite) meta tags; remove HSTS-meta (G2)
3. ✅ Verify all RLS policies live in production Supabase (G4) — **verified 11 Aug 2026** (11 tables enabled, 49 policies)
4. ✅ Tighten client password policy to 8+ chars with complexity (G5)
5. ✅ Strip release-mode logging; sanitize UI error messages (G10)
6. ✅ Add `flutter_secure_storage` for session token (G3)
7. ✅ Unique index + duplicate guard in import path (G7)
8. ✅ File-size/row limits on import/restore (G8); length caps on strings (G9)
9. ✅ Dependabot config + CI outdated check (G14); honest Security Report (G15)

### Phase 2 — Short term (weeks) ⏳ Pending
10. Enable Supabase MFA + login throttling (G6) — implementation guide in `docs/gaps-fix-ops.md`
11. Remove demo account + hardcoded creds from git history (G1 cleanup) — **deferred by owner decision**
12. ~~Server-side password policy~~ ✅ **Done** (Supabase Auth min length 8, 11 Aug 2026)

### Phase 3 — Medium term (months) ⏳ Pending
13. Certificate pinning with rotation plan (G11)
14. Server-side session revocation / true device enforcement (G12) — **deployed 11 Aug 2026** (`session-gate` + `is_session_owner`); app-side `x-device-token` header wiring pending
15. ~~Encrypted backup export~~ ✅ **Done — G19** (AES-256-GCM, passphrase, PBKDF2 100k)
16. Penetration testing + bug bounty-style review of auth flows

---

## 6. Vulnerability Reporting

If you discover a security vulnerability in PowerEMS:

- **Do not** open a public issue.
- Email the maintainer directly (or open a private security advisory on GitHub: *Security → New advisory*).
- Include: affected version/build, platform, reproduction steps, and impact.
- Expected response: acknowledgement within 48 hours, fix or mitigation plan within 7 days.

---

## 7. Compliance Notes

- This app stores **energy consumption data** (potentially commercially sensitive). No PII/PHI handling today, but if user identities map to real billing accounts, review applicable data-protection regulations for your jurisdiction (e.g., DPDP Act / GDPR) — encryption-at-rest and access logs become requirements.
- Backup files (unencrypted JSON) must be treated as sensitive data.
