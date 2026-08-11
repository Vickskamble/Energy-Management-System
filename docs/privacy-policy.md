# PowerEMS — Privacy Policy

**Effective date:** 11 August 2026
**Last updated:** 11 August 2026
**Applies to:** PowerEMS ("the Service", "we", "us", "our") — web app, Android app, Windows and macOS desktop apps, and any related services.

> This policy explains what data we collect, why we collect it, how we protect it, and the rights you have over it. It applies to all users of PowerEMS, including the demo account.

---

## 1. Data We Collect

### 1.1 Information you provide
| Data | Purpose | Where stored |
|---|---|---|
| Email address & password (hashed by Supabase Auth) | Account creation, login, password reset, security notifications | Supabase Auth |
| Meter details (name, location, site, contract demand, CT/PT ratio, active flag) | Billing calculations, trend analysis | Your account's rows |
| Electricity readings (kWh, kVAh, rkVARh, MD, date/time, per meter) | Bill computation, analysis, alerts, reconciliation | Your account's rows |
| Tariff settings (rates, TOD multipliers, subsidies, preceding 11-month demands) | Accurate bill recomputation | Your account's settings |
| Actual bill amounts (optional) | Bill reconciliation vs discom bill | Your account's rows |
| Imported Excel/PDF files (processed transiently) | Parsing readings; files are not retained after successful import | Ephemeral (in memory) |

### 1.2 Device & technical data
- Device token used for **single-device session enforcement** (stored locally on the device).
- Session records (device token + last-seen timestamp) to support the single-device policy.
- Standard usage metadata (app version, platform) in anonymous form where available.

### 1.3 What we do NOT collect
- No payment/card/bank details (billing for the Service itself is handled by external providers and is out of scope of this app).
- No location tracking, no contacts, no photos, no identity documents.
- No advertising identifiers, no cross-app tracking.

## 2. How We Use Your Data

1. To operate the Service: compute bills, trends, forecasts, alerts, and savings insights.
2. To secure your account: authentication, email verification, password reset, single-device enforcement.
3. To improve the Service: anonymized aggregate usage analytics (e.g., "PF alerts triggered per month") — never individual data.
4. To comply with law or respond to legal process (only where required).

**We do NOT:**
- sell, rent, or trade your data;
- share your data with advertisers;
- use your data for any purpose other than the Service without consent.

## 3. Legal Bases (where GDPR/DPDP applies)

- **Contract performance** — operating your account and the Service.
- **Legitimate interest** — security monitoring, abuse prevention, product improvement.
- **Consent** — where we ask for optional processing.
- **Legal obligation** — compliance with applicable laws (e.g., India's Digital Personal Data Protection Act 2023, once applicable).

## 4. Data Storage & Security

- **Hosting:** Supabase (Postgres + Auth), data centers configured per Supabase's regional policies.
- **Transit:** HTTPS/TLS end-to-end; no plaintext endpoints.
- **At rest:** encrypted at the infrastructure level; database-level Row-Level Security isolates every user's data (`auth.uid() = user_id`).
- **Session tokens:** stored in OS-level secure storage (Android Keystore / Keychain / Windows DPAPI / Web Crypto).
- **Access control:** only the signed-in account can read/write its own rows; RLS is enforced by the database itself.
- Full details: `security-overview.md`.

## 5. Data Retention

- Your data is retained **while your account is active**.
- On account deletion, we delete your rows (energy logs, meters, settings, reconciliation data, sessions) within 30 days, except where law requires longer retention.
- Backups (where applicable) are purged within 90 days of account deletion.
- You may export your data at any time (JSON backup / CSV/PDF reports) before deletion.

## 6. Your Rights

Subject to applicable law (DPDP Act 2023 / GDPR where relevant), you may:

| Right | How to exercise |
|---|---|
| Access | Request a copy of your data |
| Rectification | Edit meters/readings/settings in-app, or request correction |
| Erasure | Request account + data deletion |
| Export (portability) | Use built-in backup/export |
| Withdraw consent | Where processing is consent-based |
| Complaint | Raise with us first; then your local authority (e.g., DPDP Board in India) |

**Contact for rights requests:** the account owner email at the end of this document. We respond within 30 days.

## 7. Sharing & Third Parties

| Third party | Role | Data shared |
|---|---|---|
| Supabase | Cloud hosting, database, auth | Your account data (processed per their DPA) |
| Google Fonts / gstatic (web) | Font rendering | IP address (standard web request) |
| GitHub Pages | Web hosting | Standard web server logs |

We enter appropriate data-processing terms with providers. We do **not** share your data with any other third party.

## 8. Children's Privacy

The Service is intended for business use by adults. We do not knowingly collect data from children under 18. If you believe a child has provided data, contact us for deletion.

## 9. Cookies & Local Storage

- The web app uses standard browser storage (localStorage/IndexedDB) for the session token and minimal device meta — no tracking cookies, no third-party cookies.
- Mobile/desktop apps store only device meta (token, reminder flags) locally via sembast.

## 10. Data Breach Notifications

In the event of a breach affecting your data, we will notify you within 72 hours of confirmation (and regulators where required), with scope, impact, and remediation steps. Our isolation model (per-user RLS) limits any breach's blast radius.

## 11. Changes to This Policy

Material changes are posted here with an updated date at the top. Continued use after the effective date constitutes acceptance. For material changes, we will additionally notify via in-app notice.

## 12. Contact

**Data controller / service provider:** PowerEMS (Vick Skamble)
**Email:** [support email — to be filled]
**Address:** [to be filled]

Questions, rights requests, or complaints: contact the above with the subject "Privacy".

---

*Associated documents: Terms of Service · Data Processing Agreement (DPA) · NDA · Security Overview.*
