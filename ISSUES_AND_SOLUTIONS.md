# Energy Management System — Issues & Solutions

> Documented: 01 Aug 2026 | Language: Hindi
> **Final audit: 01 Aug 2026 — Phase 2 ke siva sab issues ✅ fix / verified.**

---

## Issue 1: Local Data kabhi Supabase me sync nahi hota (agar internet continuous connected ho)

> **Status: ✅ Fixed (01 Aug 2026)**
> - `energy_repository.dart:32` — `saveReading()` ab **save ke turant baad** Supabase push karta hai
>   (online ho to); fail par `is_synced=false` rehne deta hai, `syncUnsyncedLogs()` baad me pakad leta hai
> - `sync_manager.dart:27` — app start hone par `checkConnectivity()` se pending logs sync ho jaate hain
>   (sirf connectivity *change* par nahi, har launch par bhi)
> - `bulkSaveReadings()` (PDF import) bhi same pattern — local first, remote best-effort
> - Notification: "☁️ Sync Complete" (`NotificationService.showSyncCompleteAlert`)

### Problem
App **offline-first** architecture par bana hai — har reading pehle local (Sembast) me save hoti hai,
`is_synced = false` flag ke saath. Supabase me sync **sirf tabhi** hota hai jab device ka
connectivity status **change** hota hai (offline → online).

Agar internet **pehle se continuously connected** hai to `onConnectivityChanged` event kabhi fire
nahi hota → sync kabhi trigger nahi hota → data Supabase me kabhi nahi jaata.

### Root Cause (File: `lib/core/utils/sync_manager.dart:14`)
```dart
_connectivity.onConnectivityChanged.listen((results) {
  final hasConnection = results.any((r) => r != ConnectivityResult.none);
  if (hasConnection) {
    bloc.add(const SyncOfflineCachedLogs());
  }
});
```
- `onConnectivityChanged` **sirf status change par** fire hota hai
- Continuous connection par koi change event nahi aata
- `saveReading()` (`energy_repository.dart:32`) sirf local me save karta hai, remote call nahi karta

### Affected Files
- `lib/core/utils/sync_manager.dart` — sync trigger logic
- `lib/data/repositories/energy_repository.dart:32,144` — save + sync logic
- `lib/presentation/bloc/energy_bloc.dart:143` — sync event handler

### Solution (koi ek ya mix)
1. **Reading save ke turant baad sync (Recommended)**
   - `saveReading()` me internet check karke, agar online hai to direct Supabase push
   - Fail ho to `is_synced=false` rehne do, baad me sync ho jayega
2. **Periodic timer sync**
   - Har 30-60 second me `checkConnectivity()` + `syncUnsyncedLogs()` call karo
3. **App start par sync**
   - App launch hone par hamesha pending logs sync karo
4. **Har ek success event ke baad sync**
   - Dashboard load / form submit ke baad bhi sync trigger karo

---

## Issue 2: Meter Add karne par turant add nahi hota — pura Web Refresh karna padta hai

> **Status: ✅ Fixed (01 Aug 2026)**
> - `MeterRepository` ab `extends ChangeNotifier` hai — `saveMeter()` / `updateMeter()` /
>   `deleteMeter()` ke baad `notifyListeners()` call hota hai
> - `MeterManagementPage._MeterListState` repository ko `addListener(_load)` se listen karta hai
>   → meter add/edit/delete turant list me reflect hota hai, full refresh ki zaroorat nahi
> - `ReadingEntryPage` dropdown bhi `MeterRepository` listener se refresh hota hai

### Problem
Meter Management tab me meter add karne ke baad list to refresh ho jaati hai,
lekin **dusre pages (Reading Entry dropdown, Dashboard) me purana data hi dikhta hai**.
Pura web refresh karne par hi naya meter dikhta hai.

### Root Cause (File: `lib/presentation/pages/main_navigation_hub.dart:33,81`)
```dart
final List<Widget> _pages = const [
  DashboardPage(),
  ReadingEntryPage(),
  AnalysisPage(),
  ReportsPage(),
  MeterManagementPage(),
];
// ...
body: IndexedStack(index: _selectedIndex, children: _pages),
```
- `IndexedStack` saare 5 pages **app start par ek baar** build karta hai
- Tab switch hone par pages **destroy nahi hote** — unka state wahi rehta hai
- `ReadingEntryPage._loadMeters()` (`reading_entry_page.dart:46`) aur
  `MeterManagementPage._load()` (`meter_management_page.dart:127`) **sirf initState me ek baar** chalte hain
- Isliye naya meter list me add nahi hota jab tak page state reset na ho (i.e., full refresh)

### Affected Files
- `lib/presentation/pages/main_navigation_hub.dart` — IndexedStack page lifecycle
- `lib/presentation/pages/reading_entry_page.dart:46` — meter dropdown sirf initState me load
- `lib/presentation/pages/meter_management_page.dart:127` — meter list load
- `lib/data/repositories/meter_repository.dart` — repository me notification support nahi

### Solution
1. **ChangeNotifier pattern (Recommended)**
   - `MeterRepository` ko `extends ChangeNotifier` banao
   - `saveMeter()`, `updateMeter()`, `deleteMeter()` ke baad `notifyListeners()` call karo
   - `ReadingEntryPage` aur `MeterManagementPage` me `AnimatedBuilder` / `ListenableBuilder`
     se repository ko listen karo → jese hi change hoga, list auto-refresh
   - Ek jagah add karo, har jagah turant dikhega
2. **Tab switch par reload**
   - `_onItemTapped` me tab index change par page ko reload trigger karo
   - (e.g., `GlobalKey` + public `reload()` method, ya bloc event dispatch)
3. **Bloc-based state (Advance)**
   - Meters ko bhi `EnergyBloc` / alag `MeterBloc` me le aao — pure reactive app

---

## Issue 3: Dashboard har 30 second me khud reload/spinner hota rehta hai

> **Status: ✅ Fixed (01 Aug 2026)**
> - `energy_bloc.dart:37` — refresh par `EnergyLoading` **sirf tabhi** emit hota hai jab koi data nahi
>   hai (`if (!hasData)`); data exist kare to **silent refresh** (purana data dikhta hai, flicker nahi)
> - `dashboard_page.dart` — timer ab sirf **active tab** par chalta hai
>   (`DashboardPage(isActive: _selectedIndex == 0)`); tab switch par cancel, wapas aane par start
> - Issue 4D (Analysis/Reports flicker) bhi isi se theek — dono ab loading state par hi spinner dikhate hain

### Problem
Dashboard har 30 second me auto-refresh hota hai — puri screen me loading spinner (flicker)
dikhta hai. Ye tab switch karne ke baad bhi background me chalta rehta hai.

### Root Cause (File: `lib/presentation/pages/dashboard_page.dart:34-43`)
```dart
Timer? _refreshTimer;

@override
void initState() {
  super.initState();
  _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    if (!mounted) return;
    context.read<EnergyBloc>().add(const LoadInitialDashboardData());
  });
}
```
- Har 30 sec par `LoadInitialDashboardData` event fire hota hai
- `_onLoadDashboard` (`energy_bloc.dart:29`) pehle `EnergyLoading()` emit karta hai
  → poori screen spinner me chali jaati hai → fir `EnergySuccess` aata hai → **flicker**
- IndexedStack ki wajah se page kabhi dispose nahi hota, isliye timer **har tab par
  background me chalta rehta hai** — bina user ki jaroorat ke har 30 sec data re-read hota hai

### Affected Files
- `lib/presentation/pages/dashboard_page.dart:34-43` — 30 sec periodic timer
- `lib/presentation/bloc/energy_bloc.dart:29` — har reload par `EnergyLoading` emit
- `lib/presentation/pages/main_navigation_hub.dart:81` — IndexedStack (page kabhi dispose nahi hota)

### Solution (koi ek ya mix)
1. **Silent refresh (Recommended)**
   - Refresh par `EnergyLoading` emit mat karo — naya event/flag banao jo purana data dikhate
     hue background me update kare → flicker hamesha ke liye khatam
2. **Tab active hone par hi timer chale**
   - Timer me check karo ki dashboard tab currently visible hai ya nahi
   - (IndexedStack me index/visibility check, ya page destroy karke)
3. **Timer hatana / interval badhana**
   - Pull-to-refresh aur nayi reading submit ke baad hi refresh karo
   - Ya interval 60-120 sec kar do
4. **Data change check**
   - Timer fire hone par agar data same hai to `EnergySuccess` hi re-emit karo
   - (naya UI flicker nahi, silent update)

---

## Issue 4: Analysis & Reports Screen — Bugs + Improvements

### 4A. Reports table me "₹NaN" dikh sakta hai (Bug — Critical)

> **Status: ✅ Fixed** — `reports_page.dart` unit cost column me `log.kwh > 0 ? ... : '—'` guard.
> (Analysis page me guard pehle se tha.)

**Problem:** `reports_page.dart:264` me division by zero par NaN dikhta hai.

**Root Cause (File: `lib/presentation/pages/reports_page.dart:264`)**
```dart
Text('₹${(log.estimatedBill / log.kwh).toStringAsFixed(2)}'),
```
- Agar `log.kwh == 0` → `estimatedBill / 0` = `NaN` → table me "₹NaN" print hota hai
- Analysis page me guard hai (`analysis_page.dart:383`: `log.kwh > 0 ? ... : '—'`) lekin
  Reports page me nahi

**Solution:**
```dart
Text(log.kwh > 0
    ? '₹${(log.estimatedBill / log.kwh).toStringAsFixed(2)}'
    : '—'),
```

---

### 4B. Edit Reading dialog me data loss + remote mismatch (Bug — High)

> **Status: ✅ Fixed (01 Aug 2026)**
> - `analysis_page.dart` edit dialog me ab `rkvarhLag` / `rkvarhLead` / `isSynced` preserve hote hain
> - `energy_repository.dart:48` — `updateReading()` ab `isSynced` check ke **bina** remote update karta
>   hai (local + remote dono update, fir `markAsSynced`) → edited synced reading kabhi diverge nahi hoti

**Problem:** Reading edit karne par `rkvarh` values 0 ho jaati hain aur synced reading
"Pending" ban jaati hai — remote (Supabase) me update kabhi nahi hota.

**Root Cause (File: `lib/presentation/pages/analysis_page.dart:531`)**
```dart
final updatedModel = EnergyLogModel.create(
  id: log.id,
  meterName: log.meterName,
  kwh: ...,
  kvah: ...,
  mdRecorded: ...,
  loggedAt: date,
  contractDemand: log.contractDemand,
  userId: log.userId,
  // ❌ rkvarhLag / rkvarhLead pass nahi kiye → 0 ho jaate hain
);
```
- `EnergyLogModel.create()` me `isSynced: false` hardcoded hai (`energy_log_model.dart:337`)
- `updateReading()` (`energy_repository.dart:38`) me condition hai:
  ```dart
  if (model.isSynced && SupabaseClientManager.isInitialized)
  ```
  → `isSynced = false` hone ki wajah se **remote update skip** → local me naya, Supabase me purana data

**Solution:**
1. Edit dialog me bhi `rkvarhLag`/`rkvarhLead` pass karo (purane values preserve)
2. `updateReading()` ko `isSynced` check ke bina remote update karne do
   (update ke baad `markAsSynced` call karo)
3. Ya `updateReading()` me model ka original sync status pass karke proper update

---

### 4C. Sirf last 100 readings dikhti hain (Bug — Data visibility)

> **Status: ✅ Fixed** — `energy_repository.dart:122` ab `getAllLogs()` bina `limit` ke call karta
> hai → Analysis/Reports me saari readings dikhti hain. (Analysis me "Load More" pagination hai.)

**Problem:** Analysis aur Reports dono me 100+ readings hone par purani readings gayab — koi warning nahi.

**Root Cause (File: `lib/data/repositories/energy_repository.dart:94`)**
```dart
final allLogs = await _local.getAllLogs(limit: 100);
```
- Dashboard load event (`LoadInitialDashboardData`) sirf 100 logs fetch karta hai
- Analysis / Reports usi bloc state ka use karte hain → limit 100

**Solution:**
1. Dashboard ke liye 100 limit theek hai, lekin Analysis/Reports ke liye alag
   (full data) fetch karo — naya event ya repository call
2. Ya limit badhao (500/1000) + pagination
3. Ya loading par "Last 100 readings dikh rahi hain" warning dikhao

---

### 4D. 30-sec flicker Analysis/Reports par bhi (Issue 3 ka part)

> **Status: ✅ Fixed** — Issue 3 ke silent-refresh fix ke saath. Analysis/Reports sirf tab spinner
> dikhate hain jab state `EnergyLoading` ho (koi data na ho); background refresh silent hai.

**Problem:** Dono screens `EnergyLoading()` par poore page ka spinner dikhati hain.
Har 30 sec auto-refresh (Issue 3) par dono flicker hoti hain.

**Affected Files**
- `lib/presentation/pages/analysis_page.dart:26-28`
- `lib/presentation/pages/reports_page.dart:28-30`

**Solution:** Issue 3 ka solution (silent refresh) laga do — dono screens me bhi apply.

---

### 4E. Trend chart misleading — multiple meters ek series me mix (Improvement)

> **Status: ✅ Implemented (01 Aug 2026)** — Analysis trend chart ab multi-series hai:
> har meter ki apni series/color (`_miniLineChartMulti` + `_ChartSeries`), "All Meters" par mix nahi hota.

**Root Cause (File: `lib/presentation/pages/analysis_page.dart:161-168`)**
```dart
final meterLogs =
    _entities.where((e) => target == null || e.meterName == target).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
```
- "All Meters" select hone par har meter ki readings ek hi line chart me
  chronological mix ho jaati hain — galt interpretation

**Solution:**
1. "All Meters" hone par alag-alag series / alag color per meter
2. Ya "All Meters" par sirf average/aggregate dikhao
3. Ya default me pehla meter select karo

---

### 4F. No date-range filter (Improvement)

> **Status: ✅ Implemented (01 Aug 2026)** — Analysis me month selector + previous-month
> comparison; Reports me period selector (This Month / Last Month / All Time) + meter filter.

**Problem:** Analysis me sirf meter filter hai, month/date filter nahi.
Reports ka Executive Summary saare months ka mix karke dikhata hai.

**Affected Files**
- `lib/presentation/pages/analysis_page.dart` — meter chips ke saath date filter nahi
- `lib/presentation/pages/reports_page.dart:69-75` — all-time aggregate

**Solution:**
1. Analysis me month selector / date range picker add karo
2. Reports me month selector add karo — "Jan 2026", "Feb 2026" etc.
3. Executive Summary selected month par basis ho

---

### 4G. Export error silent (Improvement)

> **Status: ✅ Implemented (01 Aug 2026)** — Export fail hone par SnackBar me error dikhta hai.

**Root Cause (File: `lib/presentation/pages/reports_page.dart:92-101`)**
```dart
try {
  await PdfReportService.exportPdf(...);
} catch (e) {
  AppLogger.e('PDF export failed', e);  // ❌ user ko kuch nahi batata
}
```

**Solution:** catch block me SnackBar / dialog dikhao:
```dart
catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('PDF export failed: $e')),
  );
}
```

---

### 4H. Jo sahi hai (no change needed)

- Meter filter chips + "Load More" pagination (`analysis_page.dart:108`)
- Edit dialog me date/time picker + validations
- Delete confirmation + success/failure SnackBar
- `AppTable` horizontal scroll (`app_table.dart:33`) — overflow safe
- Cloud/Pending status column (Issue 1 fix ke baad meaningfull hoga)
- Executive summary KPIs, bill health score structure
- Duplicate guard, PF warning alerts

---

## Common Background

### Storage Architecture (2-Layer)
| Layer | Tech | Files |
|---|---|---|
| Local | Sembast (NoSQL) — `ems_energy_logs.db`, `ems_meters.db` | `lib/data/datasources/local/` |
| Remote | Supabase (PostgreSQL) — 7 tables, RLS enabled | `supabase_schema.sql` |

### Hierarchy
`sites → panels → meters → readings` (+ `energy_logs`, `contract_demands`, `analysis_results`)

### Security
Har table par RLS — `user_id = auth.uid()`, user sirf apna data dekhta hai.

---

## Feature: Bulk Data Upload (Bulk Import) — Phase 1: PDF only

> **Status: ✅ Implemented** — `lib/core/utils/pdf_import_service.dart` + Reports page "Import PDF" button. Scanned/OCR + CSV → Phase 2.

> **Target Client:** MSME / Industry | **Platform:** Web-first | **Cost:** ₹0 (sab free)

### Kyun aur kiske liye
- Clients technical nahi hain — CSV se kaam nahi chalega (CSV me columns, format ka gyan chahiye)
- **PDF upload** dena hai — client bas file select karega, baaki app khud karegi
- **Phase 1 me sirf PDF** — JPG/Gemini OCR aur CSV baad me (Phase 2)

### Intake (Phase 1)
| Method | Kaise | Cost | Accuracy |
|---|---|---|---|
| **PDF (only)** | Text-based PDF → direct text extraction | ₹0 offline | ~100% |

> JPG/Scanned PDF (Gemini OCR) + CSV → **Phase 2** me

### Flow
```
Upload PDF
    ↓
Extract (text-pdf parse — pdf package, already in pubspec)
    ↓
Preview dialog — "3 readings mili" + editable rows
    ↓
Confirm → bulk save (insertLogs already exists) → dashboard/reports update
```

### Tech Stack (pubspec.yaml)
```yaml
file_picker: ^8.0.0        # PDF file select (web + io)
pdfrx: ^1.0.0              # PDF text extraction (web-first, openData + loadText)
```
> ⚠️ **Important:** Project me jo `pdf` package hai (3.12.0) wo **sirf PDF banane/merge** ke liye hai
> — usse text extract NAHI hota (source verified). Text reading ke liye **`pdfrx`** add karna padega.

### Extraction Strategy (Phase 1)
```dart
final doc = await PdfDocument.openData(bytes);   // web: file_picker se bytes
final text = await doc.pages[0].loadText();      // page text
// text → lines → rows → parse → DataValidator → EnergyLogModel.create()
```

### Files jo banegi
- `lib/core/utils/pdf_import_service.dart` — PDF text extract + rows parse + validate
- `lib/presentation/pages/reports_page.dart` — "Import PDF" button + preview dialog
- `lib/data/repositories/energy_repository.dart` — `bulkSaveReadings()`

---

## Feature: AI Smart Insights (Gemini free tier) — PHASE 2 (baad me)

> ⏳ **Phase 2 ke liye hold** — abhi implement nahi karna. Ye plan sirf future reference ke liye.

> Upload ke saath-saath **AI se smart insights** bhi — OpenAI paid hai, isliye **Gemini free tier** hi use karenge (ek hi tool: OCR + Insights dono)

### Flow
```
Data (local/Supabase me)
    ↓
Summarize — monthly totals, MD, PF, bill breakdown, load factor (sirf summary, raw rows nahi)
    ↓
Gemini (free tier) — "Ye MSME industry ka data hai, insights do"
    ↓
Structured JSON → [severity, title, description, recommendation, savings]
    ↓
Cache locally + Analysis page me "AI Insights" section me dikhao
```

### Insights types (prompt se)
- **Anomaly detection** — consumption spike/deep kyu hua
- **PF alert** — penalty amount ke saath solution
- **MD breach risk** — kab breach hone ka risk hai
- **Cost optimization** — TOU tariff shift savings
- **Seasonality/trends** — month vs pehle saal comparison

### Free quota protection (important)
| Protection | Kaise |
|---|---|
| Summary only | Aggregated data bhejo, raw rows nahi |
| Result cache | Insights 24h cache — repeat calls nahi |
| Daily limit | Max 3 AI analysis/day/user (Settings toggle) |
| Fallback | AI fail/limit par rule-based insights dikhao |

### Reuse (already exists)
- `InsightItem` + `InsightSeverity` + `_InsightCard` UI — AI insights wahi cards me
- `BillCalculator`/`BillForecastCalculator` — summary data
- Analysis page — naya section + "Refresh AI Insights" button

### Files
- `lib/core/insights/ai_insight_engine.dart` — Gemini call + prompt + JSON parse
- `lib/core/insights/ai_insight_cache.dart` — local cache (sembast)
- `lib/presentation/pages/analysis_page.dart` — AI Insights section
- `lib/presentation/pages/settings_page.dart` — AI toggle + daily limit

---

## Issue 5: Analysis Screen — Client expectations vs availability (Redesign needed)

> **Status: ✅ Implemented (01 Aug 2026)** — Bill Analysis section, PF + Load
> Factor trend charts, month selector + previous-month comparison, Export PDF,
> multi-meter trend series, **MD breach prediction** ("is rate par kab breach
> hoga" — MD growth rate se), **rule-based anomaly highlights** (month consumption
> avg se ±30% deviation → SPIKE/DIP cards).

### Problem
Client (MSME/Industry) Analysis tab me expected analysis nahi milta — screen me **sirf 3 cheezein** hain:
meter filter chips, 2 trend charts (kWh + MD, last 30 readings), aur reading history list.
Baaki analysis (bill breakdown, forecast, insights, recommendations) **Dashboard me bikhra hua hai**,
Analysis tab me nahi.

### Jo abhi Analysis screen me hai
1. Meter filter chips (All / ek meter)
2. Trend charts — kWh consumption + Max Demand (sirf last 30 readings)
3. Reading history list — edit/delete + kwh/unit cost/PF/MD/bill per reading

### Client expectations jo MISSING hai — **sab ✅ ab implement hain (01 Aug 2026)**
> Table me "❌" = fix se **pehle** ka state. Ab sab present:
> Bill Analysis (breakdown), PF + Load Factor trend charts, month selector +
> previous-month comparison, MD breach prediction, anomaly highlights (SPIKE/DIP),
> cost trends (unit cost chart), multi-meter trend series, export PDF, savings
> recommendations (Dashboard + Analysis), forecast (Dashboard). AI anomaly — Phase 2.
| Expectation | Status |
|---|---|
| Bill breakdown (energy/demand/FAC/taxes) | ✅ Analysis me Bill Analysis section |
| PF analysis (trend + penalty/rebate kitna) | ✅ PF + Load Factor trend charts |
| Load factor / capacity utilization | ✅ Load Factor trend chart |
| MD breach risk prediction | ✅ MD breach prediction ("is rate par kab breach") |
| Month-wise analysis (Jan vs Feb comparison) | ✅ Month selector + previous month compare |
| Cost trends (unit cost up/down) | ✅ Avg unit cost trend chart |
| Per-meter comparison (Meter A vs Meter B) | ✅ multi-meter trend series |
| Anomaly detection (spike kyu hua) | ✅ rule-based SPIKE/DIP highlights (AI Phase 2) |
| Forecast (is month kitna bill) | ✅ Dashboard me (Analysis me nahi — by design) |
| Export analysis report | ✅ Export PDF button |
| Savings recommendations | ✅ Dashboard Bill Saving Opportunities (Analysis me nahi — by design) |

### Root Cause
Analysis content zyada tar Dashboard me hai — Analysis tab ko "detailed view" banana hai.

### Solution — Analysis screen redesign (phases)
1. **Bill Analysis section** — `BillCalculator` breakdown yahan shift karo
2. **PF + Load Factor trend charts** — 2 aur charts
3. **Month selector** + previous month comparison (`BillCalculator.compare` already hai)
4. **MD breach prediction** — "is rate par 18th ko breach hoga"
5. **Anomaly highlights** — rule-based pehle (AI Phase 2 me upgrade)
6. **Export PDF** — analysis summary export
7. **Per-meter comparison** — multiple meters side-by-side

### Affected Files
- `lib/presentation/pages/analysis_page.dart` — main redesign
- `lib/core/calculation/bill_calculator.dart` — already hai, reuse
- `lib/core/calculation/bill_forecast.dart` — already hai, reuse
- `lib/core/insights/insight_generator.dart` — rule-based, reuse

---

## Issue 6: Reports Screen — Client expectations vs availability (Redesign needed)

> **Status: ✅ Implemented (01 Aug 2026)** — Period selector (This Month / Last Month /
> All Time), meter filter, monthly bill history bar chart (last 12 months), ₹NaN fix (4A),
> export error SnackBars (4G). ⏳ Phase 2: report type dropdown, PDF charts + branding,
> email/share, auto-scheduled reports.

### Problem
Reports screen me sirf all-time summary + readings table hai — client ko
period/month-based professional reports nahi milte.

### Jo abhi Reports screen me hai
1. PDF Export + CSV Export buttons (sab readings ka)
2. Executive Summary — 8 KPIs (Net Bill, Total Units, Avg Unit Cost, Bill Health, PF, Billing Demand, Load Factor, Energy Score)
3. Reading History table — 8 columns (Date, Meter, kWh, Unit Cost, PF, MD, Bill, Status)
4. PDF content: summary table + readings table (text-based, koi chart nahi)

### Client expectations jo MISSING hai — **core sab ✅ (01 Aug 2026), baaki Phase 2**
> Table me "❌" = fix se **pehle** ka state. Core implement ho chuka hai (detail status
> uper): period selector (This Month/Last Month/Custom/All Time), meter filter,
> monthly history bar chart (last 12 months), Bill Accuracy (app vs actual, 7B),
> PDF/CSV export with applied filters, NaN/100-limit/export-error bugs fixed.
> Phase 2: report types dropdown, PDF me charts+branding, email/share, auto-scheduled.
| Expectation | Status |
|---|---|
| Month-wise report (Jan ka, Feb ka) | ✅ Period selector (This Month / Last Month / Custom / All Time) |
| Date range selection (custom period) | ✅ Custom Range |
| Meter-wise report (ek meter ki report) | ✅ Meter filter (multi-site ke saath) |
| Monthly bill history (har month ka bill trend) | ✅ Monthly History bar chart (12 months) |
| Charts in report/PDF (consumption & cost graphs) | ⏳ Phase 2 (PDF charts+branding) |
| Bill comparison report (is month vs last month) | ✅ Bill Accuracy section (est vs actual, 7B) |
| Report types (Daily / Monthly / Annual / Energy Audit) | ⏳ Phase 2 (report types dropdown) |
| MD breach report (kab-kab breach hua, penalty) | ⏳ Phase 2 (Analysis me MD prediction hai) |
| PF penalty/rebate summary | ⏳ Phase 2 (PF trends Analysis me hain) |
| Email/share report (client ko bhejna) | ⏳ Phase 2 |
| Auto-scheduled report (har month khud bane) | ⏳ Phase 2 |
| Company header/logo branding | ⏳ Phase 2 (PDF me branding) |

### Existing bugs (isse link hain)
- Issue 4A — ₹NaN (kwh=0 par division by zero) — `reports_page.dart:264`
- Issue 4C — 100 readings limit (purana data report me nahi)
- Issue 4G — export error silent (user ko kuch nahi batata)
- No pagination — 100 rows ek saath render

### Solution — Reports redesign
1. **Period selector** — This Month / Last Month / Custom Range / All Time
2. **Meter filter** — month + meter combo
3. **Monthly bill history chart** — last 6-12 months bill + consumption bar chart
4. **Report types dropdown** — Summary / Detailed / MD Breach / PF Analysis
5. **PDF upgrade** — charts + company name/logo + generated date/period
6. **Bug fixes** — NaN, 100 limit, export error messages

### Affected Files
- `lib/presentation/pages/reports_page.dart` — main redesign
- `lib/core/utils/pdf_report_service.dart` — PDF upgrade (charts + branding)
- `lib/core/calculation/bill_calculator.dart` — reuse
- `lib/data/repositories/energy_repository.dart` — 100 limit fix

### Note
Issue 5 (Analysis redesign) aur Issue 6 (Reports redesign) **together fix** honge —
dono me same filters + BillCalculator modules reuse honge.

---

## Issue 7: MSME Clients ke liye Additional Improvements

### 🔴 Critical (accuracy/trust — pehle ye)

**1. Tariff Configuration per State/Utility** ⭐ sabse bada
> **Status: ✅ Implemented (01 Aug 2026)** — Settings > Billing me **full Tariff Editor**:
> energy tariff (₹/kWh), demand (₹/kVA), FAC, wheeling, duty %, tax %, subsidy % — sab
> editable + `TariffStore` me persist + "Reset to defaults" + validations.
> `BillCalculator` sab rates `AppConfig` se leta hai (hardcoded nahi).
> ⏳ Phase 2: per-state presets (UPCL/MKVVNL/MSEDCL ready-made sets).

- Problem: Tariff abhi hardcoded hai (`AppConfig.tariffPerUnit`) — UP/MP/Gujarat/Maharashtra ke
  alag-alag tariff, FAC rates, duty % handle nahi hote
- Fix: Settings me Tariff Editor — client apne state/utility ka tariff configure kare
  (per-unit rate, FAC, wheeling, duty %, tax %, subsidy, contract demand)
- Iske bina estimated bill galat hoga → trust issue

**2. Actual Bill vs Estimated Bill Reconciliation**
> **Status: ✅ Implemented (01 Aug 2026)** — Reports me "Bill Accuracy" section:
> har month actual bill enter karo (`BillReconcileStore`), app estimated se compare karta
> hai — diff ₹ + % with ±10% tolerance color (green/orange/red), "Clear all" bhi hai.

- Client utility ka actual bill enter kare → app compare kare
  ("Estimated ₹82,000, Actual ₹85,000 — diff 3.6%, karan: FAC change")
- Fix: Reports me naya section — "Bill Accuracy" (app vs actual)

**3. Contract Demand Optimizer (direct ₹ bachat)**
> **Status: ✅ Implemented (01 Aug 2026)** — `SavingType.contractDemandOptimization`:
> last 6 months ka peak MD contract ke 80% se kam ho to suggestion
> "Contract X → Y kVA karo, ₹Z/month bachega" — Dashboard > Bill Saving
> Opportunities me dikhta hai (60% use hone par bhi sahi threshold logic).

- 6 mahine MD < 80% contract → suggest "Contract 200→150 kVA karo, ₹X/month bachega"
- Fix: `savings_opportunity.dart` me naya type + Analysis me card

### 🟡 High Impact (adoption/usage)

**4. Hindi Language (i18n)**
> **Status: ⏸️ Deferred (01 Aug 2026)** — Client/team decision: abhi English me
> aage badhna hai. Jab chaho: `flutter_localizations` + translations + Settings
> toggle (is feature ke liye alag sprint).

- MSME operators Hindi prefer karte hain — Language toggle (EN/HI)
- Fix: `flutter_localizations` + translations (abhi UI me Hinglish mix hai)

**5. Multi-Site Support**
> **Status: ✅ Implemented (01 Aug 2026)** — `MeterModel`/`MeterEntity` me `site`
> field (default "Main Site"), Meter Management dialog me Site input, meter list me
> site display, aur **Dashboard / Analysis / Reports me Site selector** — site
> select karo to KPIs, charts, trends, reports sab usi site ke meters par filter.

- Ek owner ke 2-3 factories — schema me `sites` table already hai, **UI nahi**
- Fix: Site selector + site-wise reports/dashboard

**6. Reading Reminders + Bill Due Alerts**
> **Status: ✅ Implemented (01 Aug 2026)** — Month-end reminder: month ke aakhri 3 din me
> agar koi reading record nahi hui to ek local notification (`ReadingReminderService` +
> `NotificationService.showReadingReminder`), har month sirf ek baar.

- Month end par reading reminder, MD breach instant alert
- Fix: `notification_service.dart` exists — timer/trigger connect karna hai

### 🟢 Good to Have — **→ PHASE 2 me shift (01 Aug 2026)**

> Yeh 6 features **Phase 2** me hain — is round me implement nahi kiye (LOW priority, no-code).
> Jab Phase 2 sprint shuru ho, pehle ye order me:

| Feature | Kyu |
|---|---|
| Role-based access (Owner/Operator) | Owner bill dekhe, operator sirf readings enter kare |
| CA/Auditor Export | GST/audit ke liye yearly summary + meter-wise report |
| WhatsApp share | PDF ko whatsapp se bhejna (web par wa.me link) |
| Monthly Budget/Goal | Client target set kare — "is mahine ₹70K ke andar" |
| YoY comparison | Is saal vs pichle saal (seasonality) |
| Onboarding/Help | Guide + WhatsApp support number |

### Kya nahi karna (over-engineering)
- IoT/AMR integration — MSME abhi manual reading karta hai
- Real-time sensor dashboards — cost zyada, ROI nahi
- ML forecasting — AI Phase 2 me, tab tak rule-based kaafi

### Affected Files
- `lib/core/config/app_config.dart` — hardcoded tariff (tariff editor banega)
- `lib/presentation/pages/settings_page.dart` — tariff editor + language toggle
- `lib/data/repositories/energy_repository.dart` — bill accuracy calc
- `lib/core/calculation/savings_opportunity.dart` — contract demand optimizer
- `lib/main.dart` — i18n setup

---

## Issue 8: Remaining Screens Audit — Reading Entry, Settings, Auth

> **Status: ✅ All fixed (01 Aug 2026)**

### R1 (Bug — Important): False "Reading saved successfully" har 30 sec
> **Status: ✅ Fixed** — `reading_entry_page.dart` BlocListener ab sirf
> `SubmitManualReadingForm` ke result par success message + PF/MD alerts dikhata hai;
> background refresh ke success par kuch nahi. (`energy_bloc.dart:37` silent refresh ka part)
**File:** `lib/presentation/pages/reading_entry_page.dart:134-148`
- `BlocListener` har `EnergySuccess` par success snackbar + PF/MD alerts dikhata hai
- 30-sec auto-refresh (Issue 3) bhi `EnergySuccess` emit karta hai → bina save kiye
  "saved" message + alerts repeat → client confusion, trust issue
**Fix:** Listener me check karo — sirf `SubmitManualReadingForm` ke baad hi success
message/show alerts (30-sec refresh ko silent karo)

### R2 (Bug): Numeric validation nahi — crash risk
> **Status: ✅ Fixed** — `reading_entry_page.dart` sab numeric fields par
> `double.tryParse` based validator (letter/typo par error message, crash nahi).
**File:** `lib/presentation/pages/reading_entry_page.dart:264-285,377`
- Sirf "Required" check hai — `double.parse()` FormatException crash karega agar
  user letter/typo type kare (web paste se bhi)
**Fix:** Sab fields par `double.tryParse` based numeric validator

### R3 (Bug): Dropdown non-reactive
> **Status: ✅ Fixed** — meter dropdown par `key: ValueKey(_selectedMeter)` —
> `_clearForm()` ke baad UI reset turant reflect hota hai.
**File:** `lib/presentation/pages/reading_entry_page.dart:194`
- `DropdownButtonFormField` me `initialValue` non-reactive — `_clearForm()` ka
  meter reset UI me reflect nahi hota
**Fix:** `key: ValueKey(_selectedMeter)` ya reactive pattern

### R4 (Feature gap — MSME must): No date/time picker
> **Status: ✅ Implemented (01 Aug 2026)** — Reading entry me date + time picker
> (`_pickDateTime`), late entry backdate ho sakta hai.

**File:** `lib/presentation/pages/reading_entry_page.dart:126`
- Reading hamesha `DateTime.now()` par save — MSME late entry (billing period ke
  baad) backdate nahi kar sakta
**Fix:** Reading entry me date/time picker add karo (Analysis edit dialog jaisa)

### S1 (Correction + half-fix): Tariff editor EXISTS hai
> **Status: ✅ Fixed (01 Aug 2026)** — Settings > Billing ka **full Tariff Editor**
> (Issue 7-1 ka part): ₹/kWh, demand ₹/kVA, FAC, wheeling, duty %, tax %, subsidy %
> — sab editable + `TariffStore` persist. ⏳ Phase 2: per-state presets.
**File:** `lib/presentation/pages/settings_page.dart:180-245`
- ✅ Settings > Billing me ₹/kWh editable hai (`AppConfig.tariffPerUnit` + `TariffStore`)
- ✅ Baaki rates (demand ₹/kVA, FAC, wheeling, duty%, tax%, subsidy%) bhi editable
**Fix:** Tariff editor expand — sab rates editable + per-state presets (Phase 2)

### S2 (Minor): "Supabase Connected" hardcoded
> **Status: ✅ Fixed** — settings me "Connected" status ab `SupabaseClientManager`
> se real-time reflect hota hai.
**File:** `lib/presentation/pages/settings_page.dart:260`
- Asli status reflect nahi karta
**Fix:** `SupabaseClientManager.isInitialized` se dynamic display

### S3 (Minor): Misleading message
> **Status: ✅ Fixed** — message ab "Add one in Meter Management first".
**File:** `lib/presentation/pages/reading_entry_page.dart:173`
- "Add one in Settings first" — meter Meter Management tab me add hota hai
**Fix:** "Add one in Meter Management first"

### A1 (Minor): "Remember me" dead checkbox
> **Status: ✅ Fixed** — dead `_rememberMe` state + login check hata diya
> (Supabase session anyway persist karta hai).
**File:** `lib/presentation/pages/login_page.dart:21,260`
- Set hota hai, use kahi nahi hota
**Fix:** Hatao ya use karo (Supabase session anyway persist karta hai)

### A2 (Minor): Register — no "check your email" message
> **Status: ✅ Fixed** — email verification flow par "Check your email" message
> ab dikhta hai.
**File:** `lib/presentation/pages/register_page.dart:122`
- Email verification wale flow me specific message nahi
**Fix:** Verification required hone par "Check your email" dikhao

### A3 (Minor): Raw error leak
> **Status: ✅ Fixed** — `auth_bloc.dart` ab user-friendly messages emit karta hai
> ("Invalid email or password"), internal error sirf debugPrint me.
**File:** `lib/presentation/auth_bloc/auth_bloc.dart:108,134,153,176`
- `'Login failed: $e'` internal error user ko dikhta hai
**Fix:** User-friendly messages, internal error sirf log me

### ✅ Jo sahi hai (no change)
- Forgot password (resetPasswordForEmail + snackbar)
- Password visibility toggle, confirm-password validation
- 15s timeouts, session persist, login/register form validations

### Priority order (Issue 8 ke andar) — sab ✅ done
1. R1 (false success message) — HIGH — done
2. R2 (crash) — HIGH — done
3. R4 (date picker) — MEDIUM (MSME must) — done
4. S1 (tariff editor expand) — MEDIUM — done
5. A1/A2/A3 — LOW — done
6. R3, S2, S3 — LOW — done

---

## Issue 9: Repo me 2 Frontends the — Dead React App (Resolved: removed)

### Problem
Repo me **do alag frontends** the:
1. **Flutter app** (`lib/`) — asli production app, GitHub Pages par live
2. **`power-dashboard/`** — React + Vite + Tailwind mock/demo app
   (AlertsList, ConsumptionChart, DeviceList, Sidebar, StatCard components)
   - **Koi Supabase/backend integration nahi** — sirf mock data
   - **Koi deployment workflow uska build nahi karta** — dead code

### Risks (agar rakhte)
- Developer confusion — "kaunsa production hai?"
- Dual maintenance — features inconsistent
- Waste time — koi usme feature bana de jayegi

### Verification
- `.github/workflows/deploy.yml` — sirf `flutter build web --release` hota hai
  → GitHub Pages par `/Energy-Management-System/` base-href ke saath
- React app kisi workflow me reference nahi tha

### Resolution ✅
- **`power-dashboard/` folder DELETE kar diya** (01 Aug 2026)
- Live app confirmed: **Flutter web app** (GitHub Pages)

> **Status: ✅ Resolved (01 Aug 2026)** — dead React app repo se hat gaya, sirf Flutter
> app + ek hi deploy workflow hai. Koi pending item nahi.

---

## Issue 10: Existing Data Migration (client ke purane data ka import)

### Problem
MSME client ke paas **2-3 saal ka purana data** hai (Excel sheets, paper bills, purane
software exports). Abhi app me **koi migration path nahi** — client naye app me khaali
shuru karega, history ka comparison (YoY, seasonality) kabhi nahi dikhega.

### Kya chahiye
| Source | Kaise import |
|---|---|
| Excel (.xlsx) | Phase 2 — CSV export → CSV import (Advanced) ya direct xlsx parse |
| Purane bills PDF | PDF upload (Phase 1) — text-PDF wala flow hi |
| Manual | Manual entry (already hai) — par 2 saal manual bharna possible nahi |

### Requirements
- **Batch import** with preview + error report (Phase 1 bulk flow jaisa)
- **Meter mapping** — purane data ke meter naam → configured meters (mismatch list)
- **Backdated readings** — Reading Entry me date picker (Issue 8 R4) iska base hai
- **Validation** — DataValidator reuse (kwh/kvah ratio, cumulative consistency)

### Phase
- Phase 2 (PDF upload Phase 1 ke baad)

---

## Issue 11: PDF Format Flexibility (Phase 1 ka risk)

> **Status: ✅ Implemented (01 Aug 2026)** — PDF import **label-based pattern matching**
> se parse hota hai (keywords: `kWh`, `kVAh`, `MD`, `MAX DEMAND`, `PF`, `BILL AMOUNT`,
> `Contract Demand` — regex, next-line/same-line), positions par depend nahi karta →
> har utility ka layout alag ho to bhi kaam karta hai. PDF ko pehle image par nahi,
> text layer se extract kiya jaata hai; preview + manual edit + "Replace" flow hai
> (`pdf_import.dart` + `pdf_picker.dart`, test fixtures `test/fixtures/`).

### Problem
Har state ki utility ka bill **layout alag** hota hai (UPCL, MP MKVVNL, Maharashtra
MSEDCL, Torrent...) — **ek hi parser sab par kaam nahi karega**. Position-based
parsing (row 5, column 3) fragile hai — format change hote hi toot jayega.

### Solution (flexible pattern-matching)
1. **Label-based extraction** — PDF text me keywords dhoondo:
   `kWh`, `KWH`, `kVAh`, `MD`, `MAX DEMAND`, `PF`, `BILL AMOUNT`, `Contract Demand`
2. Numbers ko label ke aas-paas (regex, next line, same line) se nikaalo
3. **Per-utility templates** (configurable) — jaise `upcl_template.json`,
   `mvvnl_template.json` — naya client aaye to naya template, code change nahi
4. **Preview + manual edit mandatory** — machine jitna bhi bharose wala parse kare,
   client confirm karega
5. Test PDFs store karo (`test/fixtures/`) — har utility ka sample bill

### Phase
- Phase 1 ke saath (PDF import ka core risk)

---

## Issue 12: Testing / CI / Deployment / Backup

### Status
- ✅ CI hai — `.github/workflows/deploy.yml` (main push → test → build → GitHub Pages)
- ✅ `flutter test` run hota hai CI me
- ⚠️ Tests kitni hain? Coverage? (`test/` folder — audit nahi kiya)
- ✅ Deploy docs ab README me hain (deploy steps, secrets, base-href note) — 01 Aug 2026
- ✅ Local backup/restore — `lib/core/utils/backup_service.dart` + Settings > System >
  "Backup & Restore" (Export Backup / Restore From File). Teeno local DBs
  (energy_logs, meters, meta) ek JSON file me export/import hote hain, int/string keys
  preserved — 01 Aug 2026

### Requirements
| Item | Action |
|---|---|
| Test coverage check | ⚠️ `test/` folder audit baaki — core modules (CalculationEngine, DataValidator, BillCalculator) par tests. 37+ tests pass (40/40 last run), CI me run hote hain. **Remaining (non-Phase 2): coverage audit** |
| Deploy docs | ✅ README me: how to deploy, secrets setup (SUPABASE_URL/ANON_KEY), base-href note |
| Local backup/restore | ✅ Settings me "Backup data" + "Restore" (JSON) |
| Supabase backup | ⚠️ Platform-ke-managed backup on — **manual check** Supabase dashboard → Project Settings → Backups (code side kuch nahi karna) |
| Staging | ⏳ Optional — feature branch deploy (github-pages ka alag environment) |

### Phase
- Background task — tests/backup kisi bhi sprint me, deploy docs abhi
- **Remaining (Phase 2 ke siva):** (1) test coverage audit, (2) Supabase backup manual check (user action), (3) staging (optional)

---

## Issue 13: Multiplying Factor hardcoded (CT/PT ratio per meter missing)

> **Status: ✅ Implemented (01 Aug 2026)** — `MeterModel` me `ctRatio`/`ptRatio` (default 1:1),
> per-meter `multiplyingFactor = ctRatio * ptRatio`, `EnergyLogModel` par per-log MF,
> `BillCalculator` + `monthly_consumption_chart` dono ab per-log MF use karte hain.
> Backward compat: `AppConstants.multiplyingFactor` default.

### Problem
App me **ek global Multiplying Factor (MF)** hardcoded hai — sab meters ke liye same:
- `AppConstants.multiplyingFactor = 5` (sab ke liye ek hi)
- `energy_repository.dart:130`: `totalConsumption = totalKwhMonth * AppConstants.multiplyingFactor`
- `energy_log_model.dart:257`: bill calculation me bhi same global MF

**Asli duniya me MF = CT ratio × PT ratio** — har meter ka apna alag hota hai:
- Meter A: CT 100/5 → MF = 20
- Meter B: CT 50/5 → MF = 10
- Client ke 2 meters par alag MF → dono par 5 lagta hai → **consumption 2-4x galat** → **bill galat**

### Root Cause
- `MeterModel` me `ctRatio` / `ptRatio` fields **nahi hain**
- `meters` table schema me `ct_ratio`, `pt_ratio` columns **already hain** (migrate_schema.sql:88-89) — par model/UI me use hi nahi hote
- Meter Management dialog me CT/PT enter karne ka option nahi
- Repository me per-meter MF logic nahi

### Solution
1. `MeterModel` me `ctRatio`, `ptRatio` add karo (default 1:1 → MF = 1)
2. Meter Management dialog me CT/PT input fields
3. Per-meter `multiplyingFactor = ctRatio * ptRatio` — meter-specific consumption calculation
4. `AppConstants.multiplyingFactor` se migrated meters ke liye backward compat (ya ek "legacy MF" field)
5. Bill calculation aur dashboard total me same per-meter MF use karo

### Phase
- Issue 7A (tariff) ke saath — dono milke "accurate bill" deliver karte hain

---

## Milestone Roadmap
1. **Bug fixes** — ✅ DONE: Issue 1 (Sync), 4B (Edit data loss), 4A (NaN), 4C (100 limit), 3 (flicker), 2 (meter refresh), 8 R1-R4/S1-S3/A1-A3 (01 Aug 2026)
2. **Bulk upload — Phase 1: PDF only** ✅ DONE — `PdfImportService` (label-based parse, Issue 11), Reports → "Import PDF" button + editable preview dialog, `EnergyRepository.bulkSaveReadings()`, tests (`test/unit/pdf_import_test.dart`). Phase 2 (CSV/xlsx/OCR) abhi nahi.
3. **MSME essentials — accurate bill** ✅ DONE — Issue 7A (tariff full editor) + 13 (per-meter MF) + 7B (bill reconciliation) (01 Aug 2026)
4. **Existing data migration — Phase 2** (Issue 10) — CSV/xlsx import + meter mapping
5. **AI Smart Insights — Phase 2** (Gemini free tier — abhi hold)
6. **Production hardening — Phase 2** — App Check / domain restriction, Edge Function (key server-side)
7. **Background** — ✅ Issue 12 (deploy docs + backup/restore done 01 Aug 2026; test coverage audit baaki — non-Phase 2)

---

## Fix Priority — **sab ✅ done except Phase 2 / remaining**

| # | Item | Status |
|---|---|---|
| 1 | Issue 1 (Sync) | ✅ |
| 2 | Issue 4B (Edit data loss) | ✅ |
| 3 | Issue 7A (Tariff Config) | ✅ |
| 4 | Issue 13 (Per-meter MF / CT-PT) | ✅ |
| 5 | Issue 8 R1/R2 | ✅ |
| 6 | Issue 4A (NaN) | ✅ |
| 7 | Issue 4C (100 limit) | ✅ |
| 8 | Issue 3 (flicker) | ✅ |
| 9 | Issue 2 (Meter refresh) | ✅ |
| 10 | Issue 11 (PDF format flexibility) | ✅ |
| 11 | Issue 5 (Analysis redesign) | ✅ |
| 12 | Issue 6 (Reports redesign — core) | ✅ |
| 13 | Issue 7B/C (Bill accuracy, Contract optimizer) | ✅ |
| 14 | Issue 8 R4/S1 (Date picker, tariff expand) | ✅ |
| 15 | Issue 7D-G (Hindi, Multi-site, Reminders) | 7D ⏸️ deferred (English), 7E/7F ✅ |
| 16 | Issue 10 (Data migration) | Phase 2 |
| 17 | Issue 8 A1-A3/R3/S2/S3 | ✅ |
| 18 | Issue 7 Good-to-have (role, CA export, WhatsApp, budget, YoY, onboarding) | **Phase 2** (01 Aug 2026) |
| 19 | Issue 4E/4F/4G | ✅ |
| 20 | Issue 12 (Tests/Deploy docs/Backup) | ✅ core; ⚠️ coverage audit + Supabase backup check + staging (optional) |

**Phase 2 items (by design):** Issue 10 (CSV/xlsx import), AI insights, Issue 6 (report types dropdown, PDF charts/branding, email/share, auto-scheduled), per-state tariff presets, Good-to-have table (6 features), 7D Hindi i18n (deferred), App Check/Edge Function, OCR/JPG import.
**Remaining non-Phase 2:** Issue 12 test coverage audit (code audit — optional), Supabase backup manual check (user), staging (optional).
