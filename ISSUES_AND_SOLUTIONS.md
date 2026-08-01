# Energy Management System — Issues & Solutions

> Documented: 01 Aug 2026 | Language: Hindi

---

## Issue 1: Local Data kabhi Supabase me sync nahi hota (agar internet continuous connected ho)

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

**Problem:** Dono screens `EnergyLoading()` par poore page ka spinner dikhati hain.
Har 30 sec auto-refresh (Issue 3) par dono flicker hoti hain.

**Affected Files**
- `lib/presentation/pages/analysis_page.dart:26-28`
- `lib/presentation/pages/reports_page.dart:28-30`

**Solution:** Issue 3 ka solution (silent refresh) laga do — dono screens me bhi apply.

---

### 4E. Trend chart misleading — multiple meters ek series me mix (Improvement)

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

### Problem
Client (MSME/Industry) Analysis tab me expected analysis nahi milta — screen me **sirf 3 cheezein** hain:
meter filter chips, 2 trend charts (kWh + MD, last 30 readings), aur reading history list.
Baaki analysis (bill breakdown, forecast, insights, recommendations) **Dashboard me bikhra hua hai**,
Analysis tab me nahi.

### Jo abhi Analysis screen me hai
1. Meter filter chips (All / ek meter)
2. Trend charts — kWh consumption + Max Demand (sirf last 30 readings)
3. Reading history list — edit/delete + kwh/unit cost/PF/MD/bill per reading

### Client expectations jo MISSING hai
| Expectation | Status |
|---|---|
| Bill breakdown (energy/demand/FAC/taxes) | ❌ Analysis me nahi — Dashboard me hai |
| PF analysis (trend + penalty/rebate kitna) | ❌ sirf current PF |
| Load factor / capacity utilization | ❌ nahi hai |
| MD breach risk prediction | ❌ sirf breach events list |
| Month-wise analysis (Jan vs Feb comparison) | ❌ koi date/month filter nahi |
| Cost trends (unit cost up/down) | ❌ nahi |
| Per-meter comparison (Meter A vs Meter B) | ❌ sirf single select |
| Anomaly detection (spike kyu hua) | ❌ AI Phase 2 me |
| Forecast (is month kitna bill) | ❌ sirf Dashboard me |
| Export analysis report | ❌ sirf raw readings CSV/PDF |
| Savings recommendations | ❌ Dashboard me, Analysis me nahi |

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

### Problem
Reports screen me sirf all-time summary + readings table hai — client ko
period/month-based professional reports nahi milte.

### Jo abhi Reports screen me hai
1. PDF Export + CSV Export buttons (sab readings ka)
2. Executive Summary — 8 KPIs (Net Bill, Total Units, Avg Unit Cost, Bill Health, PF, Billing Demand, Load Factor, Energy Score)
3. Reading History table — 8 columns (Date, Meter, kWh, Unit Cost, PF, MD, Bill, Status)
4. PDF content: summary table + readings table (text-based, koi chart nahi)

### Client expectations jo MISSING hai
| Expectation | Status |
|---|---|
| Month-wise report (Jan ka, Feb ka) | ❌ sirf all-time |
| Date range selection (custom period) | ❌ nahi hai |
| Meter-wise report (ek meter ki report) | ❌ filter nahi |
| Monthly bill history (har month ka bill trend) | ❌ sirf flat list |
| Charts in report/PDF (consumption & cost graphs) | ❌ PDF me table hi table |
| Bill comparison report (is month vs last month) | ❌ nahi |
| Report types (Daily / Monthly / Annual / Energy Audit) | ❌ sirf 1 type |
| MD breach report (kab-kab breach hua, penalty) | ❌ nahi |
| PF penalty/rebate summary | ❌ nahi |
| Email/share report (client ko bhejna) | ❌ sirf download |
| Auto-scheduled report (har month khud bane) | ❌ Phase 2 |
| Company header/logo branding | ❌ generic PDF |

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
- Problem: Tariff abhi hardcoded hai (`AppConfig.tariffPerUnit`) — UP/MP/Gujarat/Maharashtra ke
  alag-alag tariff, FAC rates, duty % handle nahi hote
- Fix: Settings me Tariff Editor — client apne state/utility ka tariff configure kare
  (per-unit rate, FAC, wheeling, duty %, tax %, subsidy, contract demand)
- Iske bina estimated bill galat hoga → trust issue

**2. Actual Bill vs Estimated Bill Reconciliation**
- Client utility ka actual bill enter kare → app compare kare
  ("Estimated ₹82,000, Actual ₹85,000 — diff 3.6%, karan: FAC change")
- Fix: Reports me naya section — "Bill Accuracy" (app vs actual)

**3. Contract Demand Optimizer (direct ₹ bachat)**
- 6 mahine MD < 80% contract → suggest "Contract 200→150 kVA karo, ₹X/month bachega"
- Fix: `savings_opportunity.dart` me naya type + Analysis me card

### 🟡 High Impact (adoption/usage)

**4. Hindi Language (i18n)**
- MSME operators Hindi prefer karte hain — Language toggle (EN/HI)
- Fix: `flutter_localizations` + translations (abhi UI me Hinglish mix hai)

**5. Multi-Site Support**
- Ek owner ke 2-3 factories — schema me `sites` table already hai, **UI nahi**
- Fix: Site selector + site-wise reports/dashboard

**6. Reading Reminders + Bill Due Alerts**
- Month end par reading reminder, MD breach instant alert
- Fix: `notification_service.dart` exists — timer/trigger connect karna hai

### 🟢 Good to Have

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

### R1 (Bug — Important): False "Reading saved successfully" har 30 sec
**File:** `lib/presentation/pages/reading_entry_page.dart:134-148`
- `BlocListener` har `EnergySuccess` par success snackbar + PF/MD alerts dikhata hai
- 30-sec auto-refresh (Issue 3) bhi `EnergySuccess` emit karta hai → bina save kiye
  "saved" message + alerts repeat → client confusion, trust issue
**Fix:** Listener me check karo — sirf `SubmitManualReadingForm` ke baad hi success
message/show alerts (30-sec refresh ko silent karo)

### R2 (Bug): Numeric validation nahi — crash risk
**File:** `lib/presentation/pages/reading_entry_page.dart:264-285,377`
- Sirf "Required" check hai — `double.parse()` FormatException crash karega agar
  user letter/typo type kare (web paste se bhi)
**Fix:** Sab fields par `double.tryParse` based numeric validator

### R3 (Bug): Dropdown non-reactive
**File:** `lib/presentation/pages/reading_entry_page.dart:194`
- `DropdownButtonFormField` me `initialValue` non-reactive — `_clearForm()` ka
  meter reset UI me reflect nahi hota
**Fix:** `key: ValueKey(_selectedMeter)` ya reactive pattern

### R4 (Feature gap — MSME must): No date/time picker
**File:** `lib/presentation/pages/reading_entry_page.dart:126`
- Reading hamesha `DateTime.now()` par save — MSME late entry (billing period ke
  baad) backdate nahi kar sakta
**Fix:** Reading entry me date/time picker add karo (Analysis edit dialog jaisa)

### S1 (Correction + half-fix): Tariff editor EXISTS hai
**File:** `lib/presentation/pages/settings_page.dart:180-245`
- ✅ Settings > Billing me ₹/kWh editable hai (`AppConfig.tariffPerUnit` + `TariffStore`)
- ❌ Baaki rates (demand ₹/kVA, FAC, wheeling, duty%, tax%, subsidy%) abhi bhi
  `AppConstants` me hardcoded — **Issue 7A half-fix hona chahiye**
**Fix:** Tariff editor expand — sab rates editable + per-state presets (Phase 2)

### S2 (Minor): "Supabase Connected" hardcoded
**File:** `lib/presentation/pages/settings_page.dart:260`
- Asli status reflect nahi karta
**Fix:** `SupabaseClientManager.isInitialized` se dynamic display

### S3 (Minor): Misleading message
**File:** `lib/presentation/pages/reading_entry_page.dart:173`
- "Add one in Settings first" — meter Meter Management tab me add hota hai
**Fix:** "Add one in Meter Management first"

### A1 (Minor): "Remember me" dead checkbox
**File:** `lib/presentation/pages/login_page.dart:21,260`
- Set hota hai, use kahi nahi hota
**Fix:** Hatao ya use karo (Supabase session anyway persist karta hai)

### A2 (Minor): Register — no "check your email" message
**File:** `lib/presentation/pages/register_page.dart:122`
- Email verification wale flow me specific message nahi
**Fix:** Verification required hone par "Check your email" dikhao

### A3 (Minor): Raw error leak
**File:** `lib/presentation/auth_bloc/auth_bloc.dart:108,134,153,176`
- `'Login failed: $e'` internal error user ko dikhta hai
**Fix:** User-friendly messages, internal error sirf log me

### ✅ Jo sahi hai (no change)
- Forgot password (resetPasswordForEmail + snackbar)
- Password visibility toggle, confirm-password validation
- 15s timeouts, session persist, login/register form validations

### Priority order (Issue 8 ke andar)
1. R1 (false success message) — HIGH
2. R2 (crash) — HIGH
3. R4 (date picker) — MEDIUM (MSME must)
4. S1 (tariff editor expand) — MEDIUM
5. A1/A2/A3 — LOW
6. R3, S2, S3 — LOW

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

### Pending (3 cheezein — detail me niche)

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
- ⚠️ Deploy docs nahi — naye developer ko kaise pata chalega?
- ❌ Local data backup/restore — device/data loss par koi recovery nahi

### Requirements
| Item | Action |
|---|---|
| Test coverage check | `test/` folder audit — core modules (CalculationEngine, DataValidator, BillCalculator) par tests |
| Deploy docs | README me: how to deploy, secrets setup (SUPABASE_URL/ANON_KEY), base-href note |
| Local backup/restore | Settings me "Backup data" (sembast file export) + "Restore" — JSON/CSV |
| Supabase backup | Platform-ke-managed backup on — check Supabase dashboard |
| Staging | Optional — feature branch deploy (github-pages ka alag environment) |

### Phase
- Background task — tests/backup kisi bhi sprint me, deploy docs abhi

---

## Issue 13: Multiplying Factor hardcoded (CT/PT ratio per meter missing)

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
1. **Bug fixes** — Issue 1 (Sync), 4B (Edit data loss), 4A (NaN), 4C (100 limit), 3 (flicker), 2 (meter refresh), 8 R1/R2
2. **Bulk upload — Phase 1: PDF only** (implementing now; Issue 11 — format flexibility iska core risk)
3. **MSME essentials — accurate bill** — Issue 7A (tariff full editor) + 13 (per-meter MF)
4. **Existing data migration — Phase 2** (Issue 10) — CSV/xlsx import + meter mapping
5. **AI Smart Insights — Phase 2** (Gemini free tier — abhi hold)
6. **Production hardening — Phase 2** — App Check / domain restriction, Edge Function (key server-side)
7. **Background** — Issue 12 (test coverage, deploy docs, backup/restore)

---

## Fix Priority
1. **Issue 1 (Sync)** — HIGH: data loss risk agar internet hamesha connected hai
2. **Issue 4B (Edit data loss + remote mismatch)** — HIGH: local/remote data mismatch
3. **Issue 7A (Tariff Config)** — HIGH: har state ka tariff alag, iske bina bill galat
4. **Issue 13 (Per-meter MF / CT-PT)** — HIGH: MF galat = consumption 2-4x galat = bill galat
5. **Issue 8 R1/R2 (False snackbar, crash)** — HIGH: trust + crash risk
6. **Issue 4A (NaN in Reports)** — MEDIUM: wrong display, easy fix
7. **Issue 4C (100 readings limit)** — MEDIUM: purani readings invisible
8. **Issue 3 (Dashboard/Analysis/Reports reload)** — MEDIUM: UX flicker
9. **Issue 2 (Meter refresh)** — MEDIUM: UX issue, data loss nahi lekin confusion
10. **Issue 11 (PDF format flexibility)** — MEDIUM: Phase 1 ka core risk
11. **Issue 5 (Analysis screen redesign)** — MEDIUM: client expectation gap
12. **Issue 6 (Reports screen redesign)** — MEDIUM: client expectation gap
13. **Issue 7B/C (Bill accuracy, Contract optimizer)** — MEDIUM: client trust + bachat
14. **Issue 8 R4/S1 (Date picker, tariff expand)** — MEDIUM: MSME must
15. **Issue 7D-G (Hindi, Multi-site, Reminders)** — MEDIUM: adoption
16. **Issue 10 (Data migration)** — MEDIUM: naye clients ke liye history
17. **Issue 8 A1-A3/R3/S2/S3 (Auth + minor)** — LOW
18. **Issue 7 (Good to have)** — LOW: role-based, CA export, WhatsApp, budget, YoY, onboarding
19. **Issue 4E/4F/4G (Trend mix, date filter, export error)** — LOW: improvements
20. **Issue 12 (Tests/Deploy docs/Backup)** — LOW: background task
