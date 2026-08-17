# PowerEMS — Operating Manual (Admin / Ops / Support)

**Version:** 1.2.2
**Audience:** System administrators, implementation engineers, support & operations teams, client IT/security teams.
**Last updated:** 18 August 2026

---

## Table of Contents
1. [System Overview & Architecture](#1-system-overview--architecture)
2. [Environment & Access](#2-environment--access)
3. [Deployment Runbooks](#3-deployment-runbooks)
4. [Environment Configuration (.env)](#4-environment-configuration-env)
5. [Database & Schema](#5-database--schema)
6. [Tariff Configuration](#6-tariff-configuration)
7. [Billing & Subscription Operations](#7-billing--subscription-operations)
8. [Alerts & Notification Rules](#8-alerts--notification-rules)
9. [Excel Import Operations](#9-excel-import-operations)
10. [Backup & Disaster Recovery](#10-backup--disaster-recovery)
11. [Security Operations](#11-security-operations)
12. [Monitoring & Support](#12-monitoring--support)
13. [Upgrade & Release Process](#13-upgrade--release-process)
14. [Troubleshooting Runbooks](#14-troubleshooting-runbooks)
15. [Compliance Checklist](#15-compliance-checklist)

---

## 1. System Overview & Architecture

PowerEMS is a Flutter multi-platform application with a cloud backend.

```
┌──────────────┬──────────────┬───────────────┐
│  Web (Vercel)│ Windows (exe)│ Android (APK) │
│  app.brill-  │  Inno Setup  │  release build│
│  iants.in    │  installer   │               │
└──────┬───────┴──────┬───────┴───────┬───────┘
       │              │               │
       └──────────────┼───────────────┘
                      ▼
        ┌─────────────────────────┐
        │  App (Flutter/Dart)     │
        │  - local DB (sembast)   │  ← offline-first
        │  - sync engine          │  → queued offline readings
        └────────────┬────────────┘
                     │
        ┌────────────┴────────────┐
        │  Supabase (PostgreSQL)  │  ← auth + data + RLS
        │  - auth (email OTP)     │
        │  - user_meters          │
        │  - energy_logs          │
        └─────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │  Razorpay               │  ← subscriptions, UPI/card/netbanking
        └─────────────────────────┘
```

**Key design decisions**

- **Offline-first:** every reading is written to the local sembast database and synced to Supabase when online. Sync failures are queued and retried.
- **Single-writer billing:** bill estimates are computed on-device from configured tariffs; the cloud stores raw readings + meter metadata only.
- **Versioned releases:** web (GitHub Actions → Pages + Vercel), Windows installer + APK attached to GitHub releases on version tags.

---

## 2. Environment & Access

| Environment | URL / Location | Purpose |
|---|---|---|
| **Production web** | `app.brilliants.in` (Vercel, repo `Vickskamble/powerems-web`) | Client-facing web app |
| **Web fallback** | GitHub Pages `https://<owner>.github.io/Energy-Management-System/` | Same build via Actions |
| **GitHub repo** | `Vickskamble/Energy-Management-System` | Source, issues, releases |
| **Supabase** | Project dashboard (see `.env` keys) | Auth, DB, RLS |
| **Razorpay** | Razorpay dashboard | Payments, invoices, refunds |

> *Figure A — Supabase project dashboard (Auth + Table editor): PENDING — requires dashboard access for capture.*
> *Figure B — Vercel project (deployments list): PENDING — requires dashboard access for capture.*

---

## 3. Deployment Runbooks

### 3.1 Web (Vercel — app.brilliants.in)

**Automatic path (recommended):**

```bash
git add -A
git commit -m "vX.Y.Z: <summary>"
git push origin main
```

- `main` push → GitHub Actions runs **tests + analyze + web build + security headers**, deploys to Pages.
- Then build the Vercel folder manually (Vercel needs the compiled folder; there is no CI on powerems-web):

```bat
build_web.bat        :: reads pubspec version → flutter build web --release → robocopy build\web → web-deploy\
cd web-deploy
git add -A
git commit -m "PowerEMS web vX.Y.Z"
git push origin master     :: branch is `master` here
```

> ⚠️ **Gotcha:** `web-deploy` default branch is **master** (not main). Pushing to `main` fails with *"src refspec main does not match any"*.

### 3.2 GitHub Release (APK + Windows installer)

APK and Windows installer jobs run **only on version tags**:

```bash
# 1. bump version in pubspec.yaml (e.g. 1.2.2+22)
# 2. commit + push
# 3. create + push the tag
git tag v1.2.2
git push origin v1.2.2
```

The `Release Build` workflow then attaches to the release:

| Job | Artifacts |
|---|---|
| `android-apk` | `app-release.apk` |
| `windows-desktop` | `EMS.Setup.<ver>.exe` (Inno Setup), `Energy-Management-System-Windows-<ver>.zip` |

Windows build takes ~15–20 min. **Secrets** are injected from GitHub Actions secrets (see §4).

> *Figure C — GitHub Actions run (workflow): PENDING — requires dashboard access for capture.*
> *Figure D — GitHub Release with assets: PENDING — requires dashboard access for capture.*

### 3.3 Version policy

- `build_name+build_number` in `pubspec.yaml` (e.g. `1.2.2+22`).
- Tag name must equal the build_name part: `v1.2.2`.
- Inno installer version is taken from the **tag** (`/DAppVersion`), so always tag after bumping.

---

## 4. Environment Configuration (.env)

The app reads these keys at build/runtime (`flutter_dotenv`):

| Key | Purpose | Where set |
|---|---|---|
| `SUPABASE_URL` | Supabase project URL | `.env`, GitHub secrets, Vercel env |
| `SUPABASE_ANON_KEY` | Supabase anon key (RLS-protected) | `.env`, GitHub secrets, Vercel env |
| `RAZORPAY_KEY_ID` | Razorpay live/test key id | `.env`, GitHub secrets, Vercel env |

Rules:

- `.env` is git-ignored — never commit real keys. Keep `.env.example` updated with placeholders.
- Anon key is safe to ship (RLS protects data); the **service-role key must never ship**.
- Rotation: regenerate key in Supabase dashboard → update `.env` + GitHub secrets + Vercel env → rebuild/redeploy.

---

## 5. Database & Schema

### 5.1 Tables

| Table | Purpose | Key columns |
|---|---|---|
| `auth.users` | Supabase Auth users | id, email, email_confirmed_at |
| `user_meters` | Meter metadata | name, site, contract_demand_kw, ct_ratio, pt_ratio, multiplying_factor, **daily_kwh_target**, is_active, user_id |
| `energy_logs` | Readings | meter_name, kwh, kvah, current_kwh, current_kvah, rkvarh_lag/lead, md_recorded, power_factor, contract_demand, logged_at, is_synced, user_id |

> ⚠️ **Critical:** `user_meters.daily_kwh_target` is a **numeric column that must exist** in Supabase. If missing, meter saves retry without it (so the app never crashes) but **targets get lost on reload** — the daily target line stops showing. Apply:

```sql
ALTER TABLE user_meters ADD COLUMN IF NOT EXISTS daily_kwh_target numeric DEFAULT 0;
```

### 5.2 Schema migrations

- `supabase/migrations/` — versioned SQL migrations (apply in order).
- Root SQL dumps (legacy): `supabase_schema.sql`, `supabase_cloud_data_migration.sql`, `supabase_single_device_migration.sql`, `supabase_auth_schema.sql`.
- **Always** snapshot before destructive changes; test migrations in a scratch project first.

### 5.3 Row Level Security (RLS)

Every table must enforce `user_id = auth.uid()` policies. Verify in Supabase → Table editor → RLS policies. Any table without RLS is a data leak risk.

> *Figure E — Supabase RLS policies: PENDING — requires dashboard access for capture.*

---

## 6. Tariff Configuration

All bill estimation is on-device; there is **no tariff table in the cloud**. Configuration lives in the app's Settings → Tariff.

### 6.1 Presets (recommended)

Category + version presets (MERC) fill all fields automatically. Supported: energy rate (₹/kWh), demand rate (₹/kVA), FAC, wheeling, duty %, tax %, subsidy %, contract demand (kVA), preceding 11-month window, rebates.

### 6.2 Advanced fields (admin only)

| Field | Meaning |
|---|---|
| Energy rate (₹/kWh) | Per-unit energy charge |
| Demand charge (₹/kVA) | Per-kVA demand charge |
| FAC (₹/kWh) | Fuel adjustment charge |
| Wheeling (₹/kWh) | Wheeling charge |
| Electricity duty % | Duty on energy |
| Tax % | GST/surcharge |
| Subsidy % | State subsidy |
| MD / Contract (kVA) | Contract demand — reference for 75% line & MD alerts (never used as a floor; billing demand = max(MD, ratchet window)) |
| Preceding 11-month demand (kVA) | Ratchet window — monthly highs enter automatically |
| Rebates & adjustments | ICR rebate, LF incentive, PPD, bulk rebate, arrears, round to ₹10, bill on kVAh |

### 6.3 Change management

- Changing tariffs affects **future estimates only** (past reports keep stored `estimated_bill`/`net_bill` per reading).
- Document every change in the client's change log; verify with the client's actual bill (*Reports → Record Actual Bill*).
- **Accuracy target:** estimate within **10%** of actual (`billAccuracyTolerancePercent`).

---

## 7. Billing & Subscription Operations

### 7.1 Pricing (code constants in `subscription_config.dart`)

| Item | Value |
|---|---|
| Trial | **60 days** full access |
| Base plan | ₹**799**/month (includes 1 meter) |
| Extra meter | ₹**99**/month each (one-time top-up, base not re-charged) |
| Owner access key | Redeemable for full access (demo/trial installs) |

### 7.2 Payment flow

1. Client clicks Subscribe → Razorpay checkout (UPI/cards/netbanking).
2. On success, PowerEMS polls the payment status endpoint; plan activates automatically.
3. Expired plans lock new readings + meter adds; existing data remains.

### 7.3 Operations checklist

- Monitor Razorpay dashboard for failed/reversed payments; manual refunds via Razorpay (not in-app).
- `RAZORPAY_KEY_ID` is the **live key** in production — never point clients to a test key.
- Owner key redemption is one-time per account (`redeemOwnerKey`); keep the key secret.

> *Figure F — Razorpay dashboard (payments/subscriptions): PENDING — requires dashboard access for capture.*

---

## 8. Alerts & Notification Rules

Thresholds live in `app_constants.dart` (tunable per deployment):

| Constant | Value | Meaning |
|---|---|---|
| `pfRebateThreshold` | 0.95 | Below → rebate missed |
| `pfSurchargeThreshold` | 0.90 | Below → 5% surcharge risk |
| `mdWarningRatio` | 0.90 | MD ≥ 90% contract → warning (95% used in reading-entry alert) |
| `dailyKwhWarningRatio` | 0.90 | Day consumption ≥ 90% target → "near target" alert |
| `billAccuracyTolerancePercent` | 10 | Estimate vs actual bill tolerance |
| `multiplyingFactor` | 5.0 | Default MF fallback when meter has none |

Reminder: **PF guidance must only reference checking the APFC panel / capacitor bank** — never recommend adding capacitors outright.

---

## 9. Excel Import Operations

- Sample format generated by `ExcelImportService.generateSampleTemplate()` → exported as `ems_import_template.xlsx` via `ExportService.exportSampleTemplate()`.
- Import flow: pick file(s) → column mapping dialog (auto-detected, editable) → per-row editable preview → bulk save.
- Supports **daily, monthly, and multi-file** uploads; rows without kWh/MD are skipped (invalid rows show "Incomplete").
- Meter is matched by name; unknown names default to the first meter — validate in preview.

**Common client mistakes (support script):** wrong date format (app accepts `d/m/yyyy`, `d-m-yy`, dots), PF entered as percent >1 (auto-divided), leaving MD blank (row becomes invalid), changing sample columns (mapping dialog fixes this).

---

## 10. Backup & Disaster Recovery

| Item | Method | RPO/RTO target |
|---|---|---|
| **On-device data** | Settings → Export backup (optional encrypted passphrase) | Client-driven; monthly recommended |
| **Cloud data** | Supabase automatic backups (enable in Supabase dashboard) + periodic `pg_dump` | RPO ≤ 24 h recommended |
| **Tariff config** | Part of backup file (tariff store) | — |
| **Restore** | Settings → Restore from file (passphrase if encrypted) | Immediate |

Disaster runbook:

1. Restore app → Settings → Restore → pick backup file.
2. If cloud sync fails, verify Supabase row count for the user (`energy_logs` where user_id) vs backup.
3. Validate PF/MD/daily-target alerts fire for the restored data.

> ⚠️ **Reset All Data is irreversible** (clears local + Supabase). Always take an export before testing it.

---

## 11. Security Operations

Implemented (see also `docs/security-overview.md`):

- Supabase auth with email verification; passwords policy (min length + letter + digit).
- RLS on all data tables.
- Web: CSP, nosniff, X-Frame-Options DENY, Referrer-Policy, Permissions-Policy injected at build (GitHub Actions).
- Backup encryption with passphrase; passphrase never stored.
- Keys: anon key only in app; service-role key never shipped.
- Session guard + user cache guard (see `lib/core/network/`).

Ongoing duties:

- Rotate keys quarterly; review RLS policies on every schema change.
- Keep Flutter & Supabase SDKs patched (`flutter pub outdated`).
- Re-run security headers verification on web deploy.

---

## 12. Monitoring & Support

- **Supabase dashboard:** auth logins, table row growth, errors, storage.
- **Vercel:** deployment logs & uptime for `app.brilliants.in`.
- **GitHub Actions:** build/test results; broken builds block releases.
- **App logging:** `AppLogger` (see `lib/core/utils/app_logger.dart`) — collect device logs from clients for debugging.
- Suggested alerting: Supabase health + Razorpay failed-payment webhook → ops mailbox.

---

## 13. Upgrade & Release Process

```bash
# 1. bump pubspec version (e.g. 1.2.3+23)
git add pubspec.yaml && git commit -m "v1.2.3: <summary>" && git push origin main
# 2. tag for APK + installer
git tag v1.2.3 && git push origin v1.2.3
# 3. web (Vercel)
build_web.bat && cd web-deploy && git add -A && git commit -m "PowerEMS web v1.2.3" && git push origin master
# 4. release notes: add changelog entry + update this manual's version header
```

Checklist before each release:

- [ ] `dart analyze lib/` clean
- [ ] `flutter test test/unit` — 76/76 passing (current suite)
- [ ] Schema migrations applied (e.g. `daily_kwh_target`)
- [ ] Version + tag match
- [ ] Web deployed + verified (main.dart.js hash vs local build)
- [ ] Release assets attached (APK, installer)
- [ ] Changelog/notes updated

---

## 14. Troubleshooting Runbooks

| Symptom | Root cause | Fix |
|---|---|---|
| **Blank Import tab** | Sidebar index 7 vs IndexedStack slots (fixed v1.2.1) | Update app; if recurs, check `main_navigation_hub.dart` `_onItemTapped` mapping |
| **Daily target line missing** | `daily_kwh_target` column absent in Supabase | `ALTER TABLE user_meters ADD COLUMN IF NOT EXISTS daily_kwh_target numeric DEFAULT 0;` |
| **Meter save "fails silently"** | Upsert blocked by missing column / RLS | Check Supabase error logs; code retries without unknown column (PGRST204) |
| **Web push fails "refspec main"** | web-deploy uses `master` branch | `git push origin master` |
| **Readings not syncing** | Offline queue stuck / network | Restart app; verify `is_synced` flags → cloud |
| **Payment not activating** | Razorpay key mismatch / webhook delay | Verify `RAZORPAY_KEY_ID` env; check payment-status polling |
| **Estimate far from actual bill** | Tariff rates outdated | Update Settings → Tariff; record actual bill to reconcile |
| **Windows build fails in CI** | Stderr noise kills pwsh steps | `PSNativeCommandUseErrorActionPreference=false` is already set in workflow |

---

## 15. Compliance Checklist

- [ ] **DPDP Act 2023 (India):** consent on sign-up (Terms + Privacy), DPA signed, data minimization, deletion on request (`Reset All Data`)
- [ ] **IT Act 2000 / SPDI Rules:** reasonable security practices (RLS, TLS, encrypted backups)
- [ ] **ISO 50001 alignment:** consumption KPIs, daily targets, PF/MD monitoring support client energy objectives
- [ ] **BEE:** MD/PF reporting supports compliance submissions
- [ ] **GST invoicing:** Razorpay invoices; share with client finance
- [ ] **Data residency:** keep Supabase region per client agreement; document in DPA
- [ ] **SLA:** publish uptime/support/backup commitments (create `docs/sla.md` if not yet agreed)

---

*End of Operating Manual — deliver together with the User Manual, Terms, Privacy Policy, DPA, NDA, and Security Overview.*
