# PowerEMS — Energy Management System

A professional Flutter-based Energy Management System for MSME industries. Helps small and medium enterprises understand electricity bills, perform accurate cost analysis, identify savings opportunities, and make better energy decisions.

## Features

### Dashboard
- Live KPI grid: Estimated Monthly Bill, Total Consumption, Max Demand, Power Factor, Bill Health Score, Load Factor, Today's Usage
- Auto-refresh (30 s) + pull-to-refresh; site filter chips
- Alert banner & System Alerts (Low PF penalty, Near MD breach)
- Bill Saving Opportunities incl. Contract Demand Optimizer
- Bill Forecast (projected month-end bill / units)
- Charts: Demand Trend (kVA) + Monthly Consumption
- Month-over-month comparison with savings badge

### Bill Analysis
- Full bill breakdown: Energy Charges, Demand Charges, FAC, Wheeling, Duty, Taxes, PF Rebate/Surcharge, Subsidy
- Power Factor analysis with rebate/surcharge calculation
- Billing Demand vs Contract Demand tracking (75% demand floor)
- Average unit cost per kWh, Load Factor analysis
- MD breach prediction (least-squares growth-rate extrapolation)
- Anomaly detection (month-level SPIKE/DIP ≥ 30%)

### Smart Insights (rule-based)
Every metric includes business meaning:
- "Power Factor 0.94 — close to rebate threshold, improving can save ₹X/month"
- "Demand at 92% of contract — risk of excess demand penalty"
- "Energy charges are 68% of bill — focus on efficiency measures"

### Reading Entry
- Meter dropdown with live meter list
- Auto-fetch of previous kWh / kVAh readings
- Validation: current ≥ previous, no future dates, duplicate-reading guard (±2 min)
- PF (< 0.95) and MD (≥ 95% of contract) alerts on save

### Reports
- Executive Summary (8 KPIs)
- Bill Accuracy reconciliation (estimated vs actual, ±10% tolerance)
- Monthly Bill History (12-month chart)
- Reading History with pagination + edit/delete
- PDF export, CSV export, Excel import

### Excel Import (Reports → Import Data)
- Multi-file picker (.xlsx / .xls)
- Auto header-row discovery + column auto-detection
- Manual column-mapping dialog (incl. "kVA demand under Contract KVA" case)
- Per-row editable preview before save
- Cumulative-reading detection (running totals → per-day consumption)

### Data Management
- Supabase cloud backend with Row Level Security (user-scoped)
- Backup & Restore as single JSON (device-to-device migration)
- Data Reset (Danger Zone) — clears local + Supabase
- Data validation engine

### Platform & Session
- Email/password auth with email verification + password reset
- Single-device login enforcement (`user_sessions` + session heartbeat)
- Notifications: Low PF, MD breach, month-end reading reminder (Android/iOS)
- Dark mode, responsive shell (sidebar on desktop, drawer on mobile)

## Screens

| Screen | Purpose |
|--------|---------|
| Dashboard | KPI cards, alerts, forecast, insights, recommendations, charts |
| Reading Entry | Manual meter reading form with auto-fetch of previous readings |
| Analysis | Bill breakdown, trends, MD breach prediction, anomalies, reading log edit/delete |
| Reports | Executive summary, bill accuracy, history, PDF/CSV export, Excel import |
| Meter Management | Add/edit/delete meters with contract demand, CT/PT, site config |
| Settings | Account, appearance (dark mode), tariff editor, backup & restore, reset data |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ^3.11.4) |
| State Management | flutter_bloc (9.x) |
| Cloud Backend | Supabase (Auth + Database + RLS) |
| Charts | fl_chart (0.70.x) |
| Local meta storage | sembast (device token, session, reminder flags) |
| PDF | pdf, share_plus |
| Excel | excel, file_picker |
| Notifications | flutter_local_notifications |
| Other | intl, uuid, connectivity_plus, flutter_dotenv, decimal, google_fonts |

## Architecture

**Cloud-first, single Bloc flow:**

```
UI → Bloc (AuthBloc / EnergyBloc) → Repository → Remote Datasource (Supabase)
                            ↓
                      Calculation Engine
                      Validation Engine
                      Insight Generator
                      Recommendation Engine
                            ↓
                         UI Layer
```

- All reads/writes go directly to Supabase, scoped by `auth.uid()` RLS policies.
- Sembast is used only for small app meta state (device token, last user, reminder flag) — there is no user-data cache.

## Calculation Modules

| Module | Location | Purpose |
|--------|----------|---------|
| `CalculationEngine` | `lib/core/utils/calculation_engine.dart` | Core calculations (PF, billing demand, charges) |
| `EnergyCalculator` | `lib/core/calculation/energy_calculator.dart` | Modular pure functions (16 calculations) |
| `BillCalculator` | `lib/core/calculation/bill_calculator.dart` | Logs → full BillBreakdown + MonthComparison + KPIs |
| `BillForecastCalculator` | `lib/core/calculation/bill_forecast.dart` | Projects month-end bill & units |
| `SavingsOpportunity` | `lib/core/calculation/savings_opportunity.dart` | Demand/PF/load-smoothing/contract-demand savings |
| `DataValidator` | `lib/core/validation/data_validator.dart` | Reading validation, bill consistency, comparison checks |
| `InsightGenerator` | `lib/core/insights/insight_generator.dart` | Business meaning for every metric |
| `RecommendationEngine` | `lib/core/recommendations/recommendation_engine.dart` | Data-driven recommendations (rule-based, no AI) |

## Design System

- **Primary**: #2563EB (Blue)
- **Secondary**: #3B82F6
- **Border Radius**: 16px (inputs), 20px (cards)
- **Typography**: Inter (UI), JetBrains Mono (numbers)
- **Spacing**: 4/8/12/16/20/24/32/40px grid
- **KPI Colors**: Energy (blue), Power (purple), Demand (amber), Cost (green)

## Supabase Schema

Active tables (all RLS-scoped to the signed-in user):

| Table | Purpose |
|-------|---------|
| `energy_logs` | Meter readings + full bill breakdown columns |
| `user_meters` | Meters (name, site, contract demand, CT/PT, active) |
| `user_settings` | Per-user tariff configuration |
| `bill_reconcile` | Actual bill amounts for Bill Accuracy report |
| `user_sessions` | Single-device login enforcement |

> Legacy tables (`sites`, `panels`, `meters`, `readings`, `contract_demands`, `analysis_results`) are still defined in `supabase_schema.sql` but are **not used** by the current app.

## Getting Started

### Prerequisites
- Flutter SDK ^3.11.4
- Supabase project (free tier works)

### Setup

1. **Clone and install dependencies**
   ```bash
   flutter pub get
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your Supabase credentials:
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your_supabase_anon_key_here
   ```

3. **Create Supabase tables**
   - Open your Supabase project → SQL Editor
   - Run the SQL scripts in this order:
     1. `supabase_schema.sql` — base tables + RLS policies
     2. `supabase_cloud_data_migration.sql` — `user_meters`, `user_settings`, `bill_reconcile`
     3. `supabase_single_device_migration.sql` — `user_sessions` (single-device login)
   - Enable Email auth provider in Supabase → Authentication → Providers

4. **Run the app**
   ```bash
   flutter run -d chrome
   ```

### Initial Login
- Register a new account from the Login screen
- No pre-seeded data required — add meters via Meter Management, then enter readings

## Deployment (GitHub Pages)

The repo has a CI workflow (`.github/workflows/deploy.yml`) that runs on every push to
`main`:

1. **Test** — `flutter test`
2. **Build** — `flutter build web --release`
3. **Deploy** — static site pushed to GitHub Pages (Actions `deploy-pages`)

### Secrets

Configure these in **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `SUPABASE_URL` | e.g. `https://your-project.supabase.co` |
| `SUPABASE_ANON_KEY` | Anon (publishable) key from Supabase → Settings → API |

The workflow writes them into `.env` at build time (`.env` is git-ignored, so no secrets
are committed).

### Base-href note

The app is served from `/Energy-Management-System/` (org repo), so the workflow builds
with `--base-href=/Energy-Management-System/`. If you fork or rename the repo, update the
base-href in `.github/workflows/deploy.yml` and the `README` accordingly.

### Manual deploy (any host)

```bash
cp .env.example .env   # fill in SUPABASE_URL / SUPABASE_ANON_KEY
flutter build web --release
# serve build/web/ from any static host (Nginx, Netlify, Firebase Hosting, etc.)
# for non-root paths add: --base-href=/your-path/
```

### Data backup

All local data (readings, meters, settings) can be exported/imported as a single JSON
file from **Settings → System → Backup & Restore**. Supabase backups are managed in the
Supabase dashboard (Platform → Backups).

## Project Structure

```
lib/
├── main.dart                 # App bootstrap, theme, bloc wiring
├── core/
│   ├── calculation/          # Bill breakdown, energy calculator, bill calculator, forecast, savings
│   ├── config/               # AppConfig (tariffs, defaults)
│   ├── constants/            # App constants (thresholds)
│   ├── database/             # Sembast meta DB factory (web/io)
│   ├── error/                # Custom exceptions
│   ├── insights/             # Smart insight generator
│   ├── network/              # Supabase client manager, session guard
│   ├── recommendations/      # Rule-based recommendations
│   ├── theme/                # Colors, typography, spacing, shadows, animations
│   ├── utils/                # Calculation engine, export (CSV/PDF), Excel import, backup, notifications, reminders, logger
│   ├── validation/           # Data validation engine
│   └── widgets/              # Reusable UI components (AppShell, AppSidebar, KPI cards, tables…)
├── data/
│   ├── datasources/remote/   # Supabase remote datasources (energy_logs, user_meters)
│   ├── models/               # EnergyLogModel, MeterModel
│   └── repositories/         # EnergyRepository, MeterRepository
├── domain/
│   └── entities/             # EnergyLogEntity, MeterEntity
└── presentation/
    ├── auth_bloc/            # Authentication bloc
    ├── bloc/                 # Energy bloc + state/event
    ├── pages/                # All app pages
    └── widgets/              # Chart widgets
```

## Testing

Unit tests cover the calculation engine, bill breakdown, bill forecast, savings
opportunities, and Excel import column mapping (`test/unit/`). Run them with:

```bash
flutter test
```

## Roadmap — Phase 2 (Upcoming)

Planned Phase 2 features (from `ISSUES_AND_SOLUTIONS.md`):

| Area | Feature |
|------|---------|
| AI Insights | Gemini free-tier smart insights + AI anomaly explanations (currently rule-based) |
| Reports | Report-type dropdown (Daily / Monthly / Annual / Energy Audit) |
| Reports | PDF charts + company header/logo branding |
| Reports | MD breach report + PF penalty/rebate summary |
| Reports | Email/share report, auto-scheduled monthly report |
| Import | OCR / JPG import of scanned bills (Gemini OCR) |
| Tariffs | Per-state tariff presets (UPCL / MKVVNL / MSEDCL) |
| Data migration | CSV/xlsx migration with meter mapping |
| Roles | Role-based access (Owner / Operator) |
| CA/Auditor export | Yearly summary + meter-wise report for GST/audit |
| Sharing | WhatsApp share (wa.me link) |
| Budgeting | Monthly budget/goal tracking |
| Comparison | YoY comparison (seasonality) |
| UX | Hindi i18n, onboarding/help guide |
| Security | Supabase App Check / domain restriction, Edge Function (server-side keys) |

## Version

1.0.0+1

## License

Private — for internal use.
