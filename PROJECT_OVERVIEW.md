# Rudransh CT — Project Overview

A one-page map of the project: what it is, how it is built, how work flows from a code change to production, and where to find the details.

*Status as of 17 Sep 2026.*

| | |
| --- | --- |
| **Client** | रुद्रांश चैरिटेबल ट्रस्ट (Rudransh Charitable Trust) |
| **Product** | Flutter **web** app: member register, receipt book and claim (closing) tracking |
| **Live URL** | `https://rudransh-ct.pages.dev` (no custom domain) |
| **Scale** | 10–15 office users, up to ~2,000 members, text data only (files go to Cloudinary) |
| **Running cost** | ₹0/month, free tiers only |
| **Release 1** | Mon 5 Oct 2026, admin panel (owner and staff) |
| **Release 2** | Thu 5 Nov 2026, agent and member logins |

---

## 1. What the app does

The trust runs **Yojnas** (schemes). Members join a Yojna through a field **agent**. When a member's claim falls due (for example their wedding in Shadi Sahyog Yojna), a **closing case** is raised, every other active member of that Yojna pays one **contribution** for it, and the collected amount goes to the member or their nominee (**Waris**). The member stays active and keeps paying for other closings.

### Business workflow

```
Yojna set up ──► Agents added ──► Members enrolled ──► Payments recorded
                                                              │
                          Family paid ◄── Contributions ◄── Closing case raised
                         (Unpaid → Partial → Paid)           (member stays Active)
```

1. **Yojna** — code (e.g. `SSY`), registration fee, contribution amount, claim amount.
2. **Agent** — code `AG-007` assigned by the database; linked Yojnas and commission %.
3. **Member** — reg no `SSY-2026-0184` assigned by the database; phone must be unique.
4. **Payment** — receipt no `RCP-1001` assigned by the database; kind (registration, contribution, closing payout), mode (cash, UPI, bank, cheque), status.
5. **Closing case** — raises one contribution per active member (added before it); tracks collected vs pending; the member stays Active.
6. **Payout** — the case moves to Paid once the family is settled.

### Roles

| Role | Who | Sees | Lands on |
| --- | --- | --- | --- |
| **Owner** | Trustees | Everything; deletes, cancels, invites, audit log | `/dashboard` |
| **Staff** | Office staff | Daily work; no deletes, no scheme or agent changes | `/dashboard` |
| **Agent** | Field agents | Only their own members; entries wait for approval | `/agent` |
| **Member** | Enrolled members | Only their own record | `/me` |

**Core rule:** agents and members *submit*, admins *approve*. Nothing is hard-deleted: members go Inactive, receipts are cancelled with a reason.

### Screens

| Route | Page | Role |
| --- | --- | --- |
| `/login` | Email + 6-digit OTP | All |
| `/dashboard` | KPI tiles, closed cases, members by Yojna, top agents, recent payments | Owner, staff |
| `/members` | Register with search and filters | Owner, staff |
| `/agents` | Roster, collections, commission, invite to app, move members | Owner, staff |
| `/yojna` | Schemes and amounts | Owner, staff |
| `/closing-payments` | Claims, collected vs pending, settle | Owner, staff |
| `/payments` | Receipt ledger | Owner, staff |
| `/approvals` | New members, agent payments, cancel requests | Owner, staff |
| `/agent`, `/agent/members`, `/agent/collections` | Agent home, my members, collections | Agent |
| `/me`, `/me/payments` | Member home, my receipts | Member |

---

## 2. Tech stack

| Layer | Tool | Job |
| --- | --- | --- |
| App | Flutter web, Riverpod, go_router | UI, state, routing |
| Database + auth | **Supabase** (Postgres, Mumbai region) | Tables, row-level security, SQL functions, email OTP |
| Server logic | Supabase Edge Function `invite_user` | Owner invites agents/members/staff |
| Email | **Brevo** SMTP (sender `rudranshct@gmail.com`) | OTP and invite emails, 300/day |
| Hosting | **Cloudflare Pages** | Serves `build/web` |
| Backups | **Cloudflare R2** + `age` encryption | Nightly encrypted `pg_dump` |
| Files | **Cloudinary** | Proof documents, photos |
| CI/CD | **GitHub Actions** | Test, build, deploy, backup, keep-alive |

All accounts belong to the trust's email. Credentials live in the shared password manager.

---

## 3. Code architecture

```
lib/
  core/        config (env), router + routes, theme, breakpoints, strings, utils (formatters, validators, whatsapp)
  data/
    models/        Yojna, Member, Agent, Payment, ClosingCase, AppUser, Dues, queries
    repositories/  TrustRepository interface
                   ├─ SupabaseTrustRepository   (real backend)
                   └─ InMemoryTrustRepository   (demo mode + tests)
                   AccessRepository, AgentRepository, UploadRepository
  state/       Riverpod providers, selectors, auth controller, agent providers
  widgets/     app shell, sidebar, top bar, role shell, responsive table, form dialogs
  features/    one folder per page (dashboard, members, agents, yojna, closing, payments,
               approvals, agent, portal, auth)
supabase/
  migrations/  schema, security, stats/search, roles, agent work, dues
  functions/   invite_user (Deno/TypeScript)
  templates/   otp.html, invite.html
  tests/       SQL checks (database, roles, agent work, dues, concurrent numbering)
test/          widget, routing, responsive-layout and integration tests
tool/import/   CSV import script (not needed: no existing data)
scripts/       restore_backup.sh
.github/       ci-deploy, nightly backup, keep-alive workflows
```

### Key design decisions

- **The app only talks to `TrustRepository`.** Swapping backends means writing one new implementation.
- **Demo mode vs real mode** is chosen at build time: no Supabase defines → an empty in-memory store and login bypassed.
- **Numbers come from the database** (reg no, receipt no, agent code) via locked counters, so two users saving at once never clash. The form only shows a preview.
- **Security lives in the database, not the UI.**
  - Owner and staff use table policies (`is_admin()`, `is_owner()`).
  - Agents and members get **no table access at all**; everything goes through `security definer` RPC functions that filter to their own rows and mask Aadhaar.
- **Server-side paging and SQL aggregates** (`dashboard_stats`, `monthly_collection`, etc.), because Supabase returns at most 1,000 rows per request.
- **Audit log** trigger records who changed what on every table.
- **Totals count Paid only**; pending and cancelled payments are excluded.

---

## 4. Development workflow

### Run locally

```bash
flutter pub get

# Demo mode: in-memory data, no login
flutter run -d chrome
flutter run -d chrome --dart-define=DEMO_ROLE=agent     # preview owner | staff | agent | member screens

# Against a real Supabase project (use staging)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=CLOUDINARY_CLOUD_NAME=... \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=...
```

Never commit keys. Never put the service-role key in the app.

### Test

```bash
flutter analyze
flutter test                       # unit, widget, routing and responsive tests

# Database checks on plain Postgres 17 (empty database)
psql -v ON_ERROR_STOP=1 -f supabase/tests/auth_stub.sql
for f in supabase/migrations/*.sql; do psql -v ON_ERROR_STOP=1 -f "$f"; done
psql -v ON_ERROR_STOP=1 -f supabase/tests/database_test.sql
psql -v ON_ERROR_STOP=1 -f supabase/tests/roles_test.sql
psql -v ON_ERROR_STOP=1 -f supabase/tests/agent_work_test.sql
psql -v ON_ERROR_STOP=1 -f supabase/tests/dues_test.sql
```

Integration tests in `test/integration/` skip locally unless `POSTGREST_URL` and the test JWTs are set; CI runs them.

### Making a change

1. Work on **`main`** (no feature branches for this project).
2. Follow the current phase in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) and tick items off when done.
3. **Database change:** add a *new* file in `supabase/migrations/` (never edit an applied one) plus a SQL test in `supabase/tests/`, and add that test to `ci-deploy.yml`.
4. **App change:** keep new labels in `lib/core/l10n/strings.dart`; add or update tests in `test/`.
5. Run `flutter analyze`, `flutter test` and the SQL checks locally.
6. Commit. **A push to `main` deploys to production**, so push only when it is ready to go live.
7. After a migration is merged: `supabase db push` to **staging**, check, then to **production**.

### UI conventions

- Clean white professional look, Gmail-style fonts (AppSans + Noto Sans Devanagari fallback), blue primary buttons, bold titles, coloured KPI tiles.
- App labels in English; Hindi used for member-facing messages (e.g. WhatsApp texts, emails).
- Must work from 390 px phones to 1920 px desktops, in light and dark themes.

| Width | Layout |
| --- | --- |
| `< 680px` | Drawer, single-column forms, tables become cards |
| `680–1024px` | Drawer, two-column forms |
| `1024–1360px` | Collapsed sidebar rail, three-column forms |
| `> 1360px` | Expanded sidebar, full tables |

---

## 5. CI/CD pipeline

`.github/workflows/ci-deploy.yml` runs on every push to `main` and every pull request:

```
database  ──►  api  ──►  app
```

| Job | What it does |
| --- | --- |
| **database** | Postgres 17: apply all migrations, run database, roles, agent-work and dues checks, concurrent numbering test, `deno check` the Edge Function |
| **api** | Migrations + seed, start PostgREST, sign test JWTs, run `flutter test test/integration/` |
| **app** | `flutter analyze` → `flutter test` → `flutter build web --release` with Supabase + Cloudinary defines → refuse a demo-mode build → `wrangler pages deploy` |

| Trigger | Supabase project | Result |
| --- | --- | --- |
| Push to `main` | production | Live site updated |
| Pull request | staging | Preview URL commented on the PR |
| Missing secrets | — | Tests only, no deploy |

**Rollback:** Cloudflare Pages → Deployments → previous deployment → Rollback. Data is not affected.

### Scheduled jobs

| Workflow | When | Does |
| --- | --- | --- |
| Nightly backup | 02:00 IST daily | `pg_dump` prod → `age` encrypt → R2 `daily/` (30 days), `monthly/` on the 1st (1 year); opens an issue on failure |
| Keep-alive & size check | Every 2 days | Queries prod and staging so free projects never pause; opens an issue above 350 MB (limit 500 MB) |

---

## 6. Environments and configuration

| Environment | Supabase project | Used by |
| --- | --- | --- |
| Local demo | none (in-memory) | Day-to-day UI work |
| Staging | `rudransh-staging` | PR previews, testing migrations, restore drills |
| Production | `rudransh-prod` | `main` deploys, real users |

### Build-time defines (`lib/core/config/env.dart`)

| Define | Purpose |
| --- | --- |
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | Real backend; missing → demo mode |
| `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET` | Certificate uploads |
| `DEMO_ROLE` | Demo mode only: which role's screens to open |

### GitHub secrets and variables

| Name | Used by |
| --- | --- |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | Deploy |
| `SUPABASE_URL_PROD/STAGING`, `SUPABASE_PUBLISHABLE_KEY_PROD/STAGING` | Deploy |
| `SUPABASE_DB_URL_PROD/STAGING` (session pooler URLs) | Backup, keep-alive |
| `AGE_RECIPIENT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ACCOUNT_ID`, `R2_BUCKET` | Backup |
| Variables: `CLOUDFLARE_PAGES_PROJECT`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET` | Deploy |

Auth settings (OTP length 6, expiry 10 min, sign-ups off, redirect URLs, Brevo SMTP, email templates) live in `supabase/config.toml` and are applied with `supabase config push`.

---

## 7. Operations cheat sheet

Full steps are in [docs/RUNBOOK.md](docs/RUNBOOK.md).

| Task | How |
| --- | --- |
| Add an admin | Invite in Supabase Auth → insert a `profiles` row (`owner` or `staff`) → they click **Activate account** |
| Invite an agent | Agents page → ⋯ → **Invite to app** (owners only) |
| Remove access | `update profiles set is_active = false …` or **Deactivate** the agent |
| Deploy invite function | `supabase functions deploy invite_user` (staging, then prod) |
| Apply migrations | `supabase link --project-ref <ref>` → `supabase db push` (staging first; relink to staging afterwards) |
| Project paused | Supabase dashboard → **Restore project** |
| Restore a backup | `scripts/restore_backup.sh <file>.tar.age "<pooler URL>" rudransh-backup.key` |
| Check size / audit | SQL snippets in the runbook, section 4 |

---

## 8. Current status

**Release 1 (admin panel)** — built: schema, security, OTP login, Supabase repository, server paging, CI/CD, backups, keep-alive, responsive and theme tests.
Still open before 5 Oct: `supabase config push` on both projects, one backup restore into staging, Hindi rendering and expired-OTP checks, email deliverability to Gmail/Yahoo, client sign-off, admin invites, training and handover.

**Release 2 (roles)** — progress by phase:

| Phase | Scope | Status |
| --- | --- | --- |
| 10 | Roles schema, access rules, role tests | Built; staging deploy pending |
| 11 | Role login, shells, `invite_user` | Built; staging deploy pending |
| 12 | Agent members and collections, admin approvals | Built; staging deploy pending |
| 13 | Dues per closing group, WhatsApp links, closing requests with certificate upload | **In progress** (uncommitted) |
| 14 | Notifications and announcements | Not started |
| 15 | Member portal and public lookup | Not started |
| 16 | Commission, cash handover, change requests | Not started |
| 17 | QA and launch (5 Nov) | Not started |

**Open client questions** (defaults in use until answered): full Aadhaar or last 4 digits, admin list and owners, whether agents handle cash, approval of agent-added members, how dues are charged, member smartphone/email access, commission payout. See [IMPLEMENTATION_PLAN.md §9](IMPLEMENTATION_PLAN.md).

---

## 9. Rules to remember

- Stay on free tiers; don't change the backend without a new limit forcing it.
- Security is enforced in the database. Agents and members use RPC functions only.
- Agents and members never receive a full Aadhaar number.
- Never edit an applied migration; add a new one.
- Never commit keys; never ship the service-role key.
- Mark Inactive or cancel, don't delete.
- Try changes on staging first; a push to `main` is a production release.
- Keep at least one active owner, and keep the backup private key safe.
- Don't plan bulk email (300/day limit); use in-app announcements and WhatsApp links.

---

## 10. Documentation map

| File | For | Contains |
| --- | --- | --- |
| [README.md](README.md) | Developers | Run commands, routes, layout, backend switch |
| **PROJECT_OVERVIEW.md** | Anyone joining | This page |
| [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) | Developer, project lead | Phases, checklists, database design, risks, client questions |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | Whoever runs production | Setup, deploys, admins, monitoring, restore |
| [docs/GUIDE.md](docs/GUIDE.md) | Trust staff, non-technical readers | Plain-language guide to the software |
| [tool/import/README.md](tool/import/README.md) | Developer | CSV import (not currently needed) |
