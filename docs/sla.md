# PowerEMS — Service Level Agreement (SLA)

**Version:** 1.0
**Date:** 18 August 2026
**Parties:**
- **Provider:** PowerEMS (Brilliants Automation and Software Solutions) — "we", "us"
- **Client:** ______________________ ("you", "the Client")

> This SLA defines the availability, support response, and backup commitments for the
> PowerEMS Service ("the Service"). It forms part of the agreement between the parties
> alongside the Terms of Service, Privacy Policy, and DPA. For the early-adopter phase,
> commitments are **best-effort targets** with service credits as the only remedy.

---

## 1. Service Scope

| Item | Description |
|---|---|
| Covered services | Web app (app.brilliants.in), Android app, Windows app — login, dashboard, readings, billing, analysis, reports, import/export, subscriptions |
| Data hosting | Supabase (India region) |
| Support channel | Email: Mrvikas_kamble@rediffmail.com (subject: "Support") |
| Support hours | 10:00 – 19:00 IST, Monday – Saturday (excluding public holidays) |

## 2. Availability (Uptime)

| Metric | Commitment |
|---|---|
| Monthly availability | **99.5%** per calendar month (≈ 3.6 hours max downtime/month) |
| Measurement | Availability = (total minutes − downtime minutes) ÷ total minutes × 100, measured on the web app core (login, readings, dashboard) |
| Availability report | Monthly summary on request; weekly status via https://status.supabase.com for infrastructure |

**Exclusions** (not counted as downtime — no credit):
1. Planned maintenance — notified at least 48 hours in advance, max 2 hours/month between 00:00–05:00 IST.
2. Outages of upstream providers (Supabase, Vercel, Razorpay, public Internet, discom/FTP integrations).
3. Downtime caused by the Client (network, device, browser, credentials, missed renewals).
4. Beta-stage preview environments.

## 3. Support Response Times

Severity is assigned by the Client on request, adjusted by us in good faith. Business hours apply.

| Severity | Definition | Examples | First response | Status update |
|---|---|---|---|---|
| **P1 — Critical** | Service unusable / data loss risk | Login down for all users, readings lost, account deletion failure | ≤ **4 business hours** | Every 8 hours until resolved |
| **P2 — High** | Major feature broken, workaround available | Payment not confirming, export failing | ≤ **8 business hours** | Daily |
| **P3 — Medium** | Minor defect, no business impact | Wrong label, odd formatting | ≤ **24 business hours** (next business day) | On status change |
| **P4 — Low** | Question / feature suggestion | "How do I...", roadmap queries | ≤ **48 business hours** (2 business days) | On status change |

**Target resolution:** P1 within 2 business days; P2 within 5 business days; others in the next regular release.

## 4. Backup — RPO / RTO

| Metric | Commitment |
|---|---|
| **RPO — Recovery Point Objective** | **≤ 24 hours** — Supabase point-in-time recovery (PITR) snapshots; in addition, each user can export a full backup **at any time** (Settings → Export Backup, optional AES-256-GCM encryption), i.e., an RPO of effectively zero for users who export regularly |
| **RTO — Recovery Time Objective** | **≤ 48 hours** from confirmed data-loss incident to restored service (restore + verification) |
| Backup coverage | Energy logs, meters, tariff settings, bill reconciliation, sessions — full cloud dataset, per-user isolation preserved |
| Restore verification | Quarterly restore test; evidence on request |
| User restore | Self-service restore via Settings → Restore From File (max 20 MB, encrypted or plaintext) |

**Fallback commitment:** if we fail to restore within RTO, we provide the latest exported backup file (if the Client exported any) and assistance re-importing it.

## 5. Incident Management

1. **Report:** email support with subject "INCIDENT — P1/P2", or WhatsApp on the account owner's registered number (once shared).
2. **Ack:** automated reply within 1 hour; first human response per §3.
3. **Track:** status updates per severity; P1 gets a public note (in-app banner or email blast).
4. **Resolve + report:** P1/P2 post-incident report within 5 business days — cause, impact window, affected users/data, remediation steps, prevention.

## 6. Credits (remedy)

| Failure | Credit (next invoice / renewal) |
|---|---|
| Uptime < 99.5% | 5% credit per 0.5% below target, max 25% monthly |
| P1 response > 4 business hours | 2% credit per occurrence |
| Backup restore misses RTO (48h) | 10% credit following the incident |
| P1 post-incident report missed | 2% credit |

Credits are the **exclusive remedy** for SLA failures; they do not cover indirect or consequential losses (see Terms of Service §8).

## 7. Exclusions & Force Majeure

Government action, war, terrorism, natural disasters, strikes, power/network failure beyond our control, and events reasonably outside our control excuse SLA commitments for the duration.

## 8. Review

This SLA is reviewed every 6 months or on material infrastructure changes. Client may request a revision with 30 days' notice.

---

## Sign-off

| | Provider | Client |
|---|---|---|
| Name | Vick Skamble | ______________________ |
| Role | Service Provider | ______________________ |
| Signature | | |
| Date | | |