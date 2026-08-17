# PowerEMS — UAT / SAT Acceptance Checklist

**Version:** 1.0 · **Date:** 18 August 2026
Project: PowerEMS Energy Management System — client deployment

---

**Client:** ______________________
**Facility / Site(s):** ______________________
**Application version tested:** ______________________ (expected: 1.2.2+22)
**Test environment:** ☐ Web (app.brilliants.in)  ☐ Android  ☐ Windows
**Tester(s):** ______________________
**Test period:** from ______________ to ______________

**Instructions:** Execute each test case. Mark **P** (Pass), **F** (Fail), or **N/A**.
Record any failure in the Defect Log (§D). The checklist is complete when all
critical tests pass and open defects have an agreed resolution date.

---

## A. Accounts & Login

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| A1 | Create a new account | Registration succeeds, verification email received | | |
| A2 | Verify email + first sign-in | Sign-in works only after verification | | |
| A3 | Forgot password | Reset email received; password resets | | |
| A4 | Single-device enforcement | Signing in on a 2nd device signs out the 1st (demo account exempt) | | |
| A5 | Sign out / sign in on all platforms | Clean sign-out, no "already signed in" errors | | |
| A6 | Consent checkbox at signup | Cannot register without accepting ToS + Privacy Policy | | |

## B. Dashboard

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| B1 | KPI cards load | Bill, units, unit cost, PF, MD, load factor, score show correct values | | |
| B2 | Year/Month/Meter filter bar | Selection applies to all cards; "This Month" + "All Years" work with zero data | | |
| B3 | Daily mode | Day picker shows per-day readings (excludes demand charge in estimate) | | |
| B4 | Monthly bill history chart | Last 12 months rendered | | |
| B5 | Forecast card | Forecast visible for current month | | |

## C. Meters & Reading Entry

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| C1 | Add a meter | Meter appears instantly in Dashboard/Analysis/Reports dropdowns (no restart) | | |
| C2 | Enter a reading | Validation accepts valid data; duplicate/same-date blocked | | |
| C3 | Edit a reading | Change persists; chain recalculates | | |
| C4 | Delete a reading/meter | No crash anywhere after deletion (dropdowns, charts, reports) | | |
| C5 | Meter without readings | Still visible in all selectors | | |

## D. Billing & Tariffs

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| D1 | Bill computation | Matches discom calculation for the entered tariff | | |
| D2 | Actual bill reconciliation | Enter actual bill → accuracy shows app vs actual | | |
| D3 | Tariff presets (MERC FY25-26/FY26-27, HT/LT) | Preset applies; slab/duty/ToD rates correct | | |
| D4 | MD ratchet | max(recorded MD, 11-month peak) used; 75% line is reference only | | |

## E. Analysis & Reports

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| E1 | Trend charts (consumption/demand/PF) | Month-wise + daily drill-down render | | |
| E2 | Daily kWh chart with target line | Target line matches configured target | | |
| E3 | Recommendations | 3 highest-savings opportunities shown | | |
| E4 | PDF export | Report opens with applied filters | | |
| E5 | CSV export | File downloads with correct columns | | |
| E6 | Monthly history chart | 12-month trend visible | | |

## F. Import / Export / Backup

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| F1 | Excel import (from Import screen) | Column mapping → editable preview → readings saved | | |
| F2 | PDF import (Reports) | Label-based parse → preview → save | | |
| F3 | Export backup | Full JSON (logs, meters, settings, bills) — >1,000 logs also complete | | |
| F4 | Restore backup | Restore works (plaintext + passphrase-protected) | | |
| F5 | Restore limits | >20 MB file rejected with clear message | | |

## G. Subscription & Payments

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| G1 | Subscription page | Plan/entitlement reflects correct trial/paid state | | |
| G2 | Checkout (web/Android/Windows) | Razorpay flow completes; plan updates within ~4 s | | |
| G3 | Add extra meter (₹99) | Addon applied without re-charging base plan | | |
| G4 | Referral program | Code claims after sign-in; +1 free month on referral payment | | |

## H. Alerts & Notifications

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| H1 | Month-end reminder | Notification when no reading in last 3 days of month | | |
| H2 | MD breach awareness | MD vs contract threshold flagged (analysis) | | |

## I. Data Privacy & Account Controls

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| I1 | Export my data | Complete backup download (access right) | | |
| I2 | Reset All Data | All rows wiped from Supabase; account stays | | |
| I3 | Delete Account | Account + all data erased; app signs out | | |
| I4 | Data isolation | User A cannot see User B's data (log in with 2 accounts to verify) | | |

## J. Non-Functional

| # | Test case | Expected result | Result | Remarks |
|---|---|---|---|---|
| J1 | Performance | Dashboard loads ≤ 3 s on office broadband; reports ≤ 5 s | | |
| J2 | Reliability | No crash during 2-hour continuous use on each platform | | |
| J3 | Notifications permission (Android 13+) | Runtime permission requested once | | |

---

## D. Defect Log

| ID | Date | Test ref | Description | Severity (P1–P4) | Status (Open/Fixed/Deferred) | Resolved in version |
|---|---|---|---|---|---|---|
| D1 | | | | | | |
| D2 | | | | | | |
| D3 | | | | | | |

**UAT summary:** Total tested: _____  Passed: _____  Failed: _____  N/A: _____
**Open P1/P2 defects:** _____ (none → ready for acceptance)

---

## E. Acceptance (Sign-off)

**UAT — User Acceptance:**
I confirm the application has been tested per the above checklist and works in
accordance with the documented scope. Open defects (if any) do not block go-live
and are tracked with agreed resolution dates.

| | Name | Signature | Date |
|---|---|---|---|
| Client (UAT) | | | |
| PowerEMS (UAT lead) | | | |

**SAT — Site Acceptance (go-live):**
The system is accepted for production use at the site(s) listed above. Handover
assets confirmed: ☐ Web URL ☐ Android APK ☐ Windows installer ☐ User manual ☐ Operating manual ☐ Support contact (Mrvikas_kamble@rediffmail.com) ☐ SLA agreed.

| | Name | Signature | Date |
|---|---|---|---|
| Client (SAT) | | | |
| PowerEMS (delivery lead) | | | |

---
*Back to: docs/README.md · Release notes: docs/release-notes.md · SLA: docs/sla.md*