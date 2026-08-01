# PowerEMS — Energy Management System

A professional Flutter-based Energy Management System for MSME industries. Helps small and medium enterprises understand electricity bills, perform accurate cost analysis, identify savings opportunities, and make better energy decisions.

## Features

### Bill Analysis
- Full bill breakdown: Energy Charges, Demand Charges, FAC, Wheeling, Duty, Taxes
- Power Factor analysis with rebate/surcharge calculation
- Billing Demand vs Contract Demand tracking
- Average unit cost per kWh
- Load Factor analysis

### Dashboard
- Bill Health Score and Energy Score
- Smart Insights with business context for every metric
- Data-driven Recommendations (no AI/hardware assumptions)
- Bill breakdown visualization
- Consumption & demand trends
- Data validation engine

### Smart Insights
Every metric includes business meaning:
- "Power Factor 0.94 — close to rebate threshold, improving can save ₹X/month"
- "Demand at 92% of contract — risk of excess demand penalty"
- "Energy charges are 68% of bill — focus on efficiency measures"

### Reports
- Executive Summary
- Bill Breakdown
- Reading History with export
- Validation status

### Data Management
- Offline-first with local Sembast storage
- Supabase cloud sync
- CSV export
- Manual meter reading entry
- Validation engine for data quality

## Screens

| Screen | Purpose |
|--------|---------|
| Dashboard | KPI cards, bill breakdown, insights, recommendations, charts |
| Reading Entry | Manual meter reading form with auto-fetch of previous readings |
| Analysis | Bill KPIs, insights, recommendations, data validation, reading log |
| Reports | Executive summary, bill breakdown, insights, recommendations, export |
| Meter Management | Add/edit meters with contract demand configuration |
| Settings | Theme toggle, sync status, user preferences |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ^3.11.4) |
| State Management | flutter_bloc (9.x) + Provider (6.x) |
| Local Database | Sembast (offline-first) |
| Cloud Backend | Supabase (Auth + Database) |
| Charts | fl_chart |
| Fonts | Google Fonts (Inter, JetBrains Mono) |
| Code Gen | freezed, build_runner |

## Architecture

```
User Input → Bloc/Provider → Repository → Local Datasource (Sembast)
                                         → Remote Datasource (Supabase)
                            ↓
                     Calculation Engine
                     Validation Engine
                     Insight Generator
                     Recommendation Engine
                            ↓
                         UI Layer
```

### Dual Data Flow
- **Bloc flow** (`EnergyBloc`): Dashboard, Reading Entry, Analysis, Reports — uses `energy_logs` table
- **Provider flow** (`EmsProvider`): Sites, Panels, Meters, Readings, Analysis Results — uses `ems_engine`

Both flows are offline-first — all writes go to local Sembast first, sync to Supabase happens in background.

## Calculation Modules

| Module | Location | Purpose |
|--------|----------|---------|
| `CalculationEngine` | `lib/core/utils/calculation_engine.dart` | Core calculations (PF, billing demand, charges) |
| `EnergyCalculator` | `lib/core/calculation/energy_calculator.dart` | Modular pure functions (16 calculations) |
| `BillCalculator` | `lib/core/calculation/bill_calculator.dart` | Logs → full BillBreakdown + MonthComparison + KPIs |
| `DataValidator` | `lib/core/validation/data_validator.dart` | Reading validation, bill consistency, comparison checks |
| `InsightGenerator` | `lib/core/insights/insight_generator.dart` | Business meaning for every metric |
| `RecommendationEngine` | `lib/core/recommendations/recommendation_engine.dart` | Data-driven recommendations (no AI) |

## Design System

- **Primary**: #2563EB (Blue)
- **Secondary**: #3B82F6
- **Border Radius**: 16px (inputs), 20px (cards)
- **Typography**: Inter (UI), JetBrains Mono (numbers)
- **Spacing**: 4/8/12/16/20/24/32/40px grid
- **KPI Colors**: Energy (blue), Power (purple), Demand (amber), Cost (green)

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
   Edit `.env` with your Supabase and OpenAI credentials:
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your_supabase_anon_key_here
   OPENAI_API_KEY=your_openai_api_key_here
   OPENAI_MODEL=gpt-4o-mini
   ```

3. **Create Supabase tables**
   - Open your Supabase project → SQL Editor
   - Copy-paste and run `supabase_schema.sql` (creates all 7 tables)

4. **Run the app**
   ```bash
   flutter run -d chrome
   ```

### Initial Login
- Register a new account from the Login screen
- No pre-seeded data required — add meters and readings via the app

## Deployment (GitHub Pages)

The repo has a CI workflow (`.github/workflows/deploy.yml`) that runs on every push to
`main`:

1. **Test** — `flutter test`
2. **Build** — `flutter build web --release`
3. **Deploy** — static site pushed to the `gh-pages` branch (GitHub Pages)

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
├── core/
│   ├── calculation/      # Bill breakdown, energy calculator, KPI calculator
│   ├── constants/        # App constants (tariffs, thresholds)
│   ├── database/         # Sembast database factory
│   ├── error/            # Custom exceptions
│   ├── insights/         # Smart insight generator
│   ├── network/          # Supabase client manager
│   ├── recommendations/  # Data-driven recommendations
│   ├── theme/            # Colors, typography, spacing, shadows, animations
│   ├── utils/            # Calculation engine, export, notifications, sync
│   ├── validation/       # Data validation engine
│   └── widgets/          # Reusable UI components (30+ widgets)
├── data/
│   ├── datasources/      # Local (Sembast) + Remote (Supabase)
│   ├── models/           # EnergyLogModel, MeterModel
│   └── repositories/     # EnergyRepository, MeterRepository
├── domain/
│   └── entities/         # EnergyLogEntity, MeterEntity
├── models/               # Site, Panel, Meter, Reading, AnalysisResult
├── presentation/
│   ├── auth_bloc/        # Authentication bloc
│   ├── bloc/             # Energy bloc + state/event
│   ├── pages/            # All app pages
│   └── widgets/          # Chart widgets
├── providers/            # EmsProvider (ChangeNotifier)
├── screens/              # Detail screens (site, panel, meter)
├── services/             # EmsEngine, AiService, SyncService
├── theme/                # Power theme (legacy)
└── widgets/power/        # Power monitoring widgets
```

## Supabase Schema

7 tables:

| Table | Purpose | Sync |
|-------|---------|------|
| `energy_logs` | Meter readings + bill breakdown | EnergyRepository |
| `sites` | Factory/plant locations | SyncService |
| `panels` | Electrical panels | SyncService |
| `meters` | Energy meters | SyncService |
| `readings` | Detailed meter readings | SyncService |
| `contract_demands` | Contract demand history | SyncService |
| `analysis_results` | AI + rule-based findings | SyncService |

## Lint / Analyze

```bash
dart analyze lib/           # Quick check (lib only)
flutter analyze --no-pub    # Full check (skip pub get)
flutter analyze              # Full check
```

## Version

1.0.0+1

## License

Private — for internal use.
