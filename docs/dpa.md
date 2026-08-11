# Data Processing Agreement (DPA)

**Parties:**
- **Controller (Customer / Client):** the organization or individual using PowerEMS (`"Controller"` or `"you"`)
- **Processor (Service Provider):** PowerEMS, Vick Skamble (`"Processor"` or `"us"`)

**Effective date:** 11 August 2026

> This DPA forms part of the agreement between the parties for the use of the PowerEMS Service. It governs the processing of personal data that the Controller entrusts to the Processor. It applies alongside the Privacy Policy and Terms of Service.

---

## 1. Roles & Definitions

- **Controller:** determines the purposes and means of processing. The Controller owns the data entered into PowerEMS (readings, meters, tariff settings, reconciliation data).
- **Processor:** processes personal data on behalf of and under the instructions of the Controller, strictly to provide the Service.
- **Personal data:** any information relating to an identified or identifiable natural person that is processed under this DPA (in practice, limited — see §2).
- **"Applicable law"** includes the India Digital Personal Data Protection Act 2023 (once in force), GDPR (where it applies to the Controller), and other relevant data-protection statutes.

## 2. Data We Process (Scope)

In practice the Service processes **minimal personal data** — primarily business data (meter readings, consumption). The following personal data may be processed:

| Category | Examples | Purpose |
|---|---|---|
| Account data | Email address, hashed password | Authentication, security, support |
| Operational data | Device token, session timestamps | Single-device enforcement, security |
| Incidental business data | Meter names/locations you choose to enter | As instructed by the Controller |

**Sensitive data:** the parties agree the Service is **not designed or intended** to process special-category/sensitive personal data. Controller warrants it will not upload such data.

## 3. Processing Instructions

- The Processor processes personal data **only on documented instructions** from the Controller (i.e., to operate the Service as described in the Terms of Service and Privacy Policy).
- The Processor will not: sell personal data; retain/use it for its own purposes; or transfer it outside the lawful bases under this DPA.
- If the Processor believes an instruction violates applicable law, it will inform the Controller and may suspend the affected processing.

## 4. Subprocessors

| Subprocessor | Role | Location |
|---|---|---|
| Supabase | Cloud hosting, database (Postgres), authentication, RLS enforcement | Data centers per Supabase's regional configuration |
| GitHub Pages / GitHub Releases | Web hosting and distribution of the client app | GitHub's global infrastructure |
| Google Fonts (web) | Font assets for the web build | Google CDN |

- Prior written notice will be given before adding or replacing subprocessors; Controller may object within 30 days.
- Each subprocessor is bound by contractual data-protection obligations at least equivalent to this DPA.

## 5. Security Measures

The Processor maintains technical and organizational measures (T&OM), as implemented and detailed in `security-overview.md`, including at minimum:

1. Database-level **Row-Level Security** isolating each user's rows (`auth.uid() = user_id` on all tables).
2. **HTTPS/TLS** for all traffic; no plaintext endpoints.
3. OS-level **secure storage** for session tokens (Keystore/Keychain/DPAPI/WebCrypto).
4. **Single-device session enforcement** with heartbeat and staleness detection.
5. Hardened web deployment (CSP, security headers, quality gates in CI).
6. Input validation, import size caps, duplicate-prevention indexes.
7. Dependency vulnerability monitoring (Dependabot) and CI static analysis.
8. Access to production data limited to authorized personnel with least privilege.

## 6. Data Breach Notification

- The Processor will notify the Controller **without undue delay** (target: within 72 hours of confirmation) upon becoming aware of a breach affecting Controller's personal data.
- Notification includes: nature of the breach, categories/approximate number of records, likely consequences, and remediation measures.
- The Processor will cooperate with the Controller's obligations to notify regulators/data subjects.

## 7. Data Subject Rights Assistance

- Given the Controller's own users hold their own accounts (Controller's data is entered by its own users or by the Controller), the Processor will assist the Controller in responding to data-subject requests (access, rectification, erasure, export) using the Service's built-in capabilities (export, account deletion) and reasonable technical support.

## 8. Audits

- The Controller may request reasonable evidence of compliance (e.g., this DPA, security-overview.md, audit summary). On-site audits are not provided except for cause, with reasonable notice and at the Controller's cost; reliance on SOC2-type reports is planned for Phase 3.

## 9. Retention & Deletion

- On termination of the account, the Processor deletes the Controller's rows within 30 days (logs, meters, settings, reconciliation, sessions), subject to legal retention requirements (max 90 days for backups).

## 10. International Transfers

- Data may be processed in India and in jurisdictions used by the subprocessors. Standard contractual clauses / appropriate safeguards apply for any cross-border transfer; where Supabase processes data, its regional configuration and DPA apply.

## 11. Liability & Indemnity

- Each party remains liable for its own breaches of this DPA, subject to the liability cap in the Terms of Service (§8).
- The Controller indemnifies the Processor for fines/claims arising from the Controller's unlawful instructions or the nature of data provided, except where caused by the Processor's own breach.

## 12. Term & Termination

- This DPA remains in effect while the Controller uses the Service and for 90 days after, or until data deletion is complete.

## 13. Contact

**Processor:** PowerEMS (Vick Skamble) — [email], [address]
**Controller:** ______________________ — [email], [address]

**Signatures:**

| | Processor | Controller |
|---|---|---|
| Name | Vick Skamble | ______________________ |
| Role | Service Provider | ______________________ |
| Signature | | |
| Date | | |

---

*Associated documents: Privacy Policy · Terms of Service · NDA · Security Overview.*
