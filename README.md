# Rudransh CT — Admin Panel

Flutter **web** admin panel for रुद्रांश चैरिटेबल ट्रस्ट. Admin-only: create Yojna
(schemes), manage agents and members, and keep payment + closing-claim records.
Fully responsive from a 390px phone to a 1920px desktop.

## Run

```bash
flutter pub get
flutter run -d chrome          # dev
flutter build web              # bundle in build/web (see Backend for Supabase defines)
flutter test                   # unit + responsive-layout tests
```

## What is in the box

| Route | Page | Notes |
| --- | --- | --- |
| `/dashboard` | Overview | Stat tiles, **Closed Cases** table, members-by-yojna, top agents, recent payments |
| `/members` | Members | Search + status/agent/district filters, add/edit/delete, detail sheet |
| `/agents` | Agents | Agent roster, member counts, collections, commission |
| `/yojna` | Yojna | Scheme cards; create/edit contribution, claim and registration amounts |
| `/closing-payments` | Closing Payments | Raise claims, track collected vs pending, mark settled |
| `/payments` | Payments | Receipt ledger with date-range, mode, type and status filters |
| `/login` | Sign in | Email + OTP via Supabase Auth (bypassed in demo builds) |

Top bar carries the breadcrumb, the **Yojna scope selector** (every page filters
by it), the three primary actions, the requests bell, a light/dark toggle and
the admin menu.

## Responsive behaviour

| Width | Layout |
| --- | --- |
| `< 680px` | Drawer navigation, single-column forms, tables render as cards |
| `680–1024px` | Drawer navigation, two-column forms |
| `1024–1360px` | Docked sidebar (starts collapsed to an icon rail), three-column forms |
| `> 1360px` | Docked expanded sidebar, full table columns |

Breakpoints live in [`lib/core/responsive/breakpoints.dart`](lib/core/responsive/breakpoints.dart).
`ResponsiveTable` hides low-priority columns as space shrinks, scrolls
horizontally before it ever overflows, and switches to a card list on phones.

## Project layout

```
lib/
  core/        theme tokens, breakpoints, Hindi strings, router, formatters, validators
  data/        models, repository interface, Supabase + in-memory implementations, seed data
  state/       Riverpod providers, derived selectors, auth controller
  widgets/     shell (sidebar/top bar), primitives, responsive table, form dialogs
  features/    one folder per page
supabase/      migrations, database checks, auth email templates, local config
scripts/       operational scripts (backup restore)
.github/       CI/deploy, nightly backup, keep-alive workflows
```

## Backend

The app talks only to `TrustRepository`
([`lib/data/repositories/trust_repository.dart`](lib/data/repositories/trust_repository.dart)).
[`lib/state/providers.dart`](lib/state/providers.dart) picks the implementation:

| Build | Repository | Login |
| --- | --- | --- |
| No Supabase defines (demo) | `InMemoryTrustRepository`, ~150 seed members, resets on reload | Bypassed |
| `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` defined | `SupabaseTrustRepository` | Email OTP, invited admins only |

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Never commit keys. CI injects them from repository secrets.

Database schema, numbering triggers, row-level security and dashboard SQL
functions live in [`supabase/migrations/`](supabase/migrations/). Check them on
plain Postgres (no Docker needed):

```bash
psql -v ON_ERROR_STOP=1 -f supabase/tests/auth_stub.sql      # empty database only
for f in supabase/migrations/*.sql; do psql -v ON_ERROR_STOP=1 -f "$f"; done
psql -v ON_ERROR_STOP=1 -f supabase/tests/database_test.sql
```

The Supabase repository itself is tested against a real PostgREST in CI (`test/integration/`, seeded by `supabase/tests/integration_seed.sql`); those tests skip locally unless `POSTGREST_URL` and the test JWTs are set.

Importing existing records from Excel: [`tool/import/README.md`](tool/import/README.md).

Setup, deploys, backups and admin tasks: [`docs/RUNBOOK.md`](docs/RUNBOOK.md).
Delivery plan: [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).

## Notes

- Registration numbers, receipt numbers and agent codes are assigned by the
  database; the form shows a preview only.
- A member with receipts cannot be deleted (mark them Inactive), and a Yojna
  with members cannot be deleted (deactivate it).
- The requests bell is a placeholder that reports the pending-payment count.
