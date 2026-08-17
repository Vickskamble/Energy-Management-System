# Agent Instructions

## Lint / Typecheck Commands
- `dart analyze lib/` — quick Dart analysis of `lib/` only (faster)
- `flutter pub get` — resolve dependencies
- `flutter analyze --no-pub` — full Flutter analysis (skip pub get)
- `flutter analyze` — full Flutter analysis with pub get

## Data Safety (MANDATORY — user rule, never skip)
- NEVER delete/update/overwrite any production data (Supabase tables, user rows, files) without:
  1. Taking a full backup first (export the affected rows to a timestamped JSON/CSV file and keep it).
  2. Asking the user for explicit confirmation with the exact scope (table, filter, row count).
- Only proceed with the destructive operation after the user explicitly approves.
- If a backup is impossible (e.g., no records readable before delete), say so and stop — do not delete.
- When querying counts, use `Prefer: count=exact` and read `Content-Range` correctly (`start-end/total` — a `*` total means the count was NOT verified; never assume 0).
