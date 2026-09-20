# Rudransh CT — Go-Live Plan

Plan to take the Flutter web admin panel (रुद्रांश चैरिटेबल ट्रस्ट) from in-memory demo data and a stubbed OTP login to a production deployment on a free stack.

- **Start:** Mon 14 Sep 2026
- **Go-live:** Mon 5 Oct 2026 (Release 1: admin panel)
- **Release 2:** Thu 5 Nov 2026 (agent and member roles, section 11)
- **Effort:** ~15 working days for Release 1, ~21 working days for Release 2, one full-time developer
- **Running cost:** ₹0/month (a domain name, if used, is about ₹800–1,000/year)

> **Update 17 Sep 2026:** the app will have three roles: **Admin** (owner or staff), **Agent** and **Member**. Release 1 goes live admin-only as planned. Roles come in Release 2 (section 11), so the launch date doesn't move.

---

## 0. Outstanding setup — must happen before launch

Work that is built and committed but not yet switched on. Each line says what
breaks if it is forgotten. Deferred 18 Sep 2026 to keep building; clear before
Phase 17.

| # | Task | Where | If forgotten |
| --- | --- | --- | --- |
| 1 | GitHub repository **variables** `CLOUDINARY_CLOUD_NAME` = `n9mgnr8s`, `CLOUDINARY_UPLOAD_PRESET` = `rudransh_certificates` | GitHub → Settings → Secrets and variables → Actions → **Variables** (not Secrets) | Production builds fine, but every agent reporting a death is told "Certificate upload is not set up yet". Silent: no build error |
| 2 | ~~`supabase db push` of `20260919000100_dues.sql`~~ **Applied to staging 21 Sep 2026** (verified by RPC probe); still pending on production | Supabase CLI | The Dues tab and death reports fail against a database without the views and RPCs |
| 3 | Confirm on staging that a test closing group's dues match a manual count | Staging | Phase 13's "done when" is unverified; `dues_test.sql` covers the logic but not the deployed data |
| 4 | Rotate the Cloudinary API secret exposed on 18 Sep 2026 (key `728129852553546`) | Cloudinary → Settings → API Keys | Nothing in the app uses it, so nothing breaks — but the pair grants full control of the media account, including deleting every certificate |
| 5 | Delete the test assets left in `rudransh/certificates` (three 1×1 PNGs, two stub PDFs) | Cloudinary → Assets → Media Library | Harmless clutter; would confuse a later audit of uploaded certificates |
| 6 | Schedule the daily overdue-dues sweep with pg_cron (`docs/RUNBOOK.md` §2.1) | Supabase → SQL editor, once per project | Every other notification is a trigger and works on its own; this one never fires, so agents are never told about stale dues |
| 7 | ~~Run `supabase/tests/notifications_test.sql` against a real Postgres~~ **Done 18 Sep 2026** | — | It found a real bug: `my_notifications` sorted only by `created_at`, which is identical for rows written in one transaction. Fixed |
| 8 | Cloudflare Turnstile keys + `supabase functions deploy member_lookup --no-verify-jwt` (`docs/RUNBOOK.md` §1.7) | Cloudflare + Supabase CLI | The public lookup fails closed and returns 503. The page says so, but the feature is simply unavailable until this is done |
| 9 | ~~Render the Turnstile widget in the web build~~ **Done 20 Sep 2026** | `lib/features/portal/turnstile_web.dart`, script in `web/index.html` | The widget renders on the web build and the Check button stays disabled until Cloudflare hands back a token. Compiles into `flutter build web --release`; **not yet exercised against a real site key** — that waits on item 8 |
| 10 | `UPI_ID` and `UPI_PAYEE` repository variables | GitHub → Variables | The Pay by UPI button is hidden; members pay through their agent, which is the current behaviour anyway |
| 11 | ~~`supabase db push` of `20260922000100_commission.sql`~~ **Applied to staging 21 Sep 2026**; still pending on production | Supabase CLI | The agent's cash-in-hand card, the handover button and the Commission page error against a database without them. It also replaces `agent_summary()`, so the agent home breaks until it is applied |
| 12 | **Vault `aadhaar_key` on staging and production, before `20260924000100` is pushed** | Supabase → SQL editor, once per project (`docs/RUNBOOK.md` §6) | The migration **still succeeds** and silently keeps only the last 4 digits. Every full Aadhaar is destroyed, unrecoverably, with nothing but a `raise warning`. Production holds real members |
| 13 | `supabase db push` of the four pending migrations to staging, then about nine to production | Supabase CLI | Staging member and Yojna **saves fail today** — the app sends `dob`, `state` and `start_date` columns the database lacks. Production is missing roles, agent work, dues, notifications, the member portal and commission entirely |
| 14 | Confirm every GitHub secret and variable in `docs/GO_LIVE_CHECKLIST.md` §5 | GitHub → Secrets and variables | If a deploy secret is missing the workflow **skips build and deploy without failing** — a green run that shipped nothing |

> **Order matters.** `docs/GO_LIVE_CHECKLIST.md` is the sequenced version of
> items 12–14 with the exact commands. Item 12 must come before item 13.

---

## 1. Recommended stack

The data is relational: members belong to a Yojna and an agent, and payments and closing cases point at members. The dashboard is mostly sums and counts. Postgres fits this better than a document store. Supabase also has email OTP login built in, which matches the login screens already in the app.

| Service | Job | Free limit (checked Sep 2026) | Catch |
| --- | --- | --- | --- |
| **Supabase** Free | Postgres database, email-OTP login, row-level security | 500 MB database · 1 GB files · 5 GB egress · 50k monthly users · 2 projects | Pauses after 7 idle days; no backups. Both handled by GitHub Actions (section 6). |
| **Brevo** Free | Sends OTP emails via Supabase custom SMTP | 300 emails/day | Supabase's built-in mailer allows only 2 emails/hour and isn't for production. |
| **Cloudflare Pages** Free | Hosts the Flutter web build | Unlimited bandwidth · 500 builds/month · commercial use allowed | None for this app. |
| **Cloudflare R2** Free | Stores encrypted nightly backups | 10 GB, no egress fees | None at this size. |
| **GitHub Actions** | Build, test, deploy, nightly backup, keep-alive | Free minutes on the free plan | A Flutter build takes ~5 min. |

> **Move off Vercel.** The repo has a `vercel.json`, but Vercel's free Hobby plan is non-commercial only, and Vercel counts work by a paid consultant as commercial. Cloudflare Pages allows commercial use for free.

> **About "free for life".** No hosted provider promises its free tier forever (Cloudflare D1 started enforcing new free limits on 1 Sep 2026). The data stays in standard Postgres and the app only talks to `TrustRepository`, so moving is cheap. Paid fallback: Supabase Pro at $25/month.

### Alternatives compared

| Option | Free storage | Login | Fit | Verdict |
| --- | --- | --- | --- | --- |
| **Supabase** (Postgres) | 500 MB | Email OTP built in | SQL sums, atomic numbering, triggers | **Recommended** |
| **Firebase Spark** (Firestore) | 1 GiB | Email link, not 6-digit OTP | Never pauses, but the app loads full lists, so a few thousand members exceed 50k reads/day. Needs a NoSQL redesign; Cloud Functions need the paid plan. | Second choice |
| **Cloudflare D1** + Workers | 5 GB | None, build it yourself | Most storage, but you write the whole REST API and OTP flow. About +1 week. | Only if storage becomes the limit |
| **Neon** (Postgres) | 0.5 GB | None | Same size as Supabase with no login or API. | Skip |
| **PocketBase** on Oracle Always Free VM | ~200 GB disk | Built in | Closest to free forever, but you own patching, uptime and backups. | Not for fast delivery |

---

## 2. Will 500 MB be enough?

> **Update 14 Sep 2026:** real scale is 10–15 admins and at most ~2,000 members, text only (images and PDFs go to Cloudinary). That is a few MB plus at most ~60 MB of receipts a year, so the free 500 MB lasts for years. Decision: stay on Supabase. The estimates below were for a much larger trust.

It depends on the number of payment rows, not members. Rough estimates including index overhead:

| Record | Approx. size/row | Example volume | Space used |
| --- | --- | --- | --- |
| Member | ~1.5 KB | 10,000 members | ~15 MB |
| Payment (receipt) | ~0.6 KB | 10,000 members × 4 closings/month = 40,000 rows/month | ~24 MB/month · ~290 MB/year |
| Closing case, agent, Yojna | < 1 KB | hundreds | < 1 MB |
| Supabase system schemas | — | fixed | ~40–60 MB |

With one receipt per member per closing, 10,000 members fill the free database in about **1.5 years**; 2,000 members last more than 5 years. **Get real numbers from the client.** An alert fires at 350 MB; then archive past financial years to R2 or upgrade to Pro (8 GB).

---

## 3. Delivery timeline

### Phase 1 — Decisions & accounts (14–15 Sep, Mon–Tue, 1.5 days)
- [ ] Get answers to the client questions (section 9), especially Aadhaar storage and volume
- [ ] Create every account under a **client-owned email** (e.g. `rudranshct@gmail.com`): Supabase, Brevo, Cloudflare, GitHub org
- [x] Create Supabase projects in **Mumbai (ap-south-1)**: `rudransh-prod` and `rudransh-staging`
- [x] ~~Verify the Brevo sender domain (SPF/DKIM)~~ No trust domain (16 Sep 2026); Brevo sends from the verified address rudranshct@gmail.com
- [ ] Store every login in a shared password manager
- [ ] **Done when:** client has confirmed scope

### Phase 2 — Database schema, rules, security (15–17 Sep, Tue–Thu, 2.5 days)
- [x] Set up Supabase CLI and `supabase/migrations/`
- [x] Create tables, enums, foreign keys, unique constraints and indexes (section 4)
- [x] Trigger: creating a closing case marks the member closed; deleting it reopens the member
- [x] Foreign key: deleting an agent sets members' `agent_id` to null
- [x] Generate reg numbers (`SSY-2026-0184`) in the database with a locked counter
- [x] Generate receipt numbers (`RCP-1001`) in the database
- [x] Generate agent codes (`AG-007`) in the database
- [x] `admins` table and `is_admin()` function
- [x] Row-level security on every table (admin only)
- [x] `audit_log` trigger (who changed what, when)
- [x] **Done when:** migrations run cleanly on staging and a test shows the anon key can read nothing

### Phase 3 — Real email-OTP login (18 Sep, Fri, 1 day)
- [x] Add `supabase_flutter` to `pubspec.yaml`
- [x] `requestOtp` → `signInWithOtp(email, shouldCreateUser: false)`
- [x] `verifyOtp` → `verifyOTP(type: OtpType.email)`
- [x] Disable public sign-ups; invite admins from the dashboard and add them to `admins`
- [x] OTP length 6, expiry 10 minutes
- [x] Hindi/English OTP email template
- [x] Configure Brevo SMTP (staging) and raise the Supabase SMTP rate limit
- [x] Set `AuthController.bypassLogin = false`
- [x] Redirect guard in `app_router.dart`
- [x] Restore session on page reload
- [x] **Done when:** invited admin logs in, uninvited email is rejected, reload keeps the session

### Phase 4 — `SupabaseTrustRepository` (21–23 Sep, Mon–Wed, 3 days)
- [x] Implement Yojna methods
- [x] Implement member methods (including `findMemberByPhone`, `nextRegNo` as preview only)
- [x] Implement agent methods
- [x] Implement payment methods
- [x] Implement closing case methods
- [x] snake_case ↔ camelCase mapping; dates as `date`/`timestamptz`
- [x] Map Postgres errors to readable messages (e.g. duplicate phone → "यह मोबाइल नंबर पहले से पंजीकृत है")
- [x] Config via `--dart-define` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`); never commit keys
- [x] Switch `repositoryProvider` in `providers.dart`
- [x] Keep `InMemoryTrustRepository` for widget tests
- [x] **Done when:** create/edit/delete works for all five entities on staging

### Phase 5 — Load data safely at real volume (24–25 Sep, Thu–Fri, 2 days)
> **Real bug:** Supabase returns at most **1,000 rows per request** by default. The current `fetchMembers()` / `fetchPayments()` would silently drop rows past 1,000 and dashboard totals would be wrong with no error.
- [x] Server-side paging for members (`.range()`)
- [x] Server-side paging for payments
- [x] Server-side search and filters; `pg_trgm` index on name/phone/reg no
- [x] SQL function `dashboard_stats(yojna_id)`
- [x] SQL function `monthly_collection`
- [x] SQL function `members_per_yojna`
- [x] SQL function `collection_by_agent`
- [x] Update `selectors.dart` to use server stats
- [x] Pagination controls in `responsive_table.dart`
- [x] ~~Load staging with 20,000 fake members and 200,000 payments~~ Not needed at real scale; checked locally with 20,000 members through PostgREST (every call under 0.5 s)
- [ ] **Done when:** totals are correct and pages open in under 2 seconds

### Phase 6 — Import existing records (28 Sep, Mon, 1 day)
- [x] CSV import script (Dart or SQL `copy`)
- [x] Validation: 10-digit phone, 6-digit pincode, valid Yojna code, no duplicate reg numbers
- [x] ~~Run on staging; share an exceptions report with the client~~ No existing data to import (16 Sep 2026)
- [x] Keep demo seed data out of production
- [x] **Done when:** not applicable, records start fresh in the app

### Phase 7 — Hosting, CI, backups (29 Sep, Tue, 1 day)
- [x] GitHub Actions: `flutter analyze` → `flutter test` → `flutter build web --release --dart-define=…` → `wrangler pages deploy`
- [x] `main` deploys to prod; pull requests get preview URLs
- [x] Move headers from `vercel.json` to `web/_headers`
- [x] Delete `vercel.json`
- [x] ~~Connect custom domain~~ No domain; the app lives on `rudransh-ct.pages.dev`
- [x] Set Supabase Auth site URL and redirect URLs to `https://rudransh-ct.pages.dev` in `supabase/config.toml` (17 Sep 2026)
- [ ] Run `supabase config push` for staging and production (docs/RUNBOOK.md 1.2)
- [ ] Restore one backup into staging (docs/RUNBOOK.md 5)
- [x] Nightly backup workflow (section 6)
- [x] Keep-alive + size alert workflow (section 6)
- [ ] **Done when:** push to `main` goes live and one backup has been restored into staging

### Phase 8 — QA & client acceptance (30 Sep – 1 Oct, Wed–Thu, 2 days)
- [x] Layout at 390 px, 768 px, 1440 px: every page, 8 widths, `test/responsive_test.dart` (17 Sep 2026)
- [x] Light and dark themes: same layout test runs in both (17 Sep 2026)
- [ ] Hindi text renders correctly: Noto Sans Devanagari is bundled as the fallback font; check by eye in Chrome and on an Android phone
- [ ] Two admins creating payments at once get no duplicate receipt numbers: `supabase/tests/concurrent_numbering_test.sh` added to CI; passes once CI runs it
- [ ] Logged-out browser cannot read data: covered in `database_test.sql`; API test with no login added to `test/integration/`; passes once CI runs it
- [ ] Expired OTP is rejected: manual on staging (wait 10 minutes, then enter the code)
- [ ] Client runs a real day's work on staging and signs off

> **Deferred 17 Sep 2026:** the open Phase 7 and 8 items (`supabase config push`, backup restore, running the new database tests, Hindi and expired-OTP checks, client sign-off) are postponed. They must all be done before the production launch in Phase 9.

**2 Oct (Fri):** Gandhi Jayanti, national holiday. Buffer day.

### Phase 9 — Launch & handover (5 Oct, Mon)
- [x] ~~Final production import~~ Nothing to import
- [ ] Invite admins
- [ ] 1-hour training session in Hindi
- [ ] Hand over runbook (section 10)
- [ ] Start 2-week support window

### Release 2 — Agent and member roles (6 Oct – 5 Nov)
Phases 10–17 are in section 11.

---

## 4. Database design

Follows the existing Dart models.

| Table | Key columns & constraints | On delete |
| --- | --- | --- |
| `admins` | `user_id → auth.users`, name, role | — |
| `yojnas` | `code` unique (A–Z, 2–6); contribution / claim / registration amounts as `numeric(12,2)` | Blocked if members exist |
| `agents` | `code` unique (`AG-###`), phone, commission %, `yojna_ids uuid[]` | Members' `agent_id` set to null |
| `members` | `reg_no` unique, `yojna_id`, `agent_id`, phone check `^\d{10}$`, waris name/relation, status, closing date/group | Blocked if payments exist (**change**) |
| `payments` | `receipt_no` unique, member, yojna, `amount > 0`, mode, status, kind, reference (UTR/cheque), `created_by` | Soft cancel recommended |
| `closing_cases` | `member_id` unique, claim / collected amounts, pay status, nominee | Member returned to active |
| `counters` | `key` (e.g. `SSY-2026`, `RCP`, `AG`), `value` | — |
| `audit_log` | table, row id, action, old/new JSON, user, time | Append-only |

> **Release 2 adds** `profiles`, `notifications`, `announcements`, `change_requests`, `cash_handovers`, `commission_payouts`, a `closing_case_id` on payments and a pending-approval state for members and payments. See section 11.4.

> **Behavior change to agree with the client:** today, deleting a member leaves its payments orphaned. A member with receipts should be marked *Inactive* instead, and the delete dialog should explain why.

### Excerpt: atomic numbering, sync trigger, admin-only access

```sql
-- One locked counter per key, so two admins never get the same number
create function next_number(k text) returns int language sql as $$
  insert into counters(key, value) values (k, 1)
  on conflict (key) do update set value = counters.value + 1
  returning value;
$$;

create function set_reg_no() returns trigger language plpgsql as $$
declare c text;
begin
  select code into c from yojnas where id = new.yojna_id;
  new.reg_no := c || '-' || extract(year from now()) || '-'
             || lpad(next_number(c || '-' || extract(year from now()))::text, 4, '0');
  return new;
end $$;
create trigger members_reg_no before insert on members
  for each row when (new.reg_no is null) execute function set_reg_no();

-- Closing a case closes the member (was done in InMemoryTrustRepository)
create function sync_member_on_closing() returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    update members set status = 'closed', closing_date = new.closing_date,
           closing_group = new.closing_group where id = new.member_id;
  elsif tg_op = 'DELETE' then
    update members set status = 'active', closing_date = null,
           closing_group = null where id = old.member_id;
  end if;
  return null;
end $$;

-- Only invited admins can see or change anything
create function is_admin() returns boolean language sql stable security definer as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;
alter table members enable row level security;
create policy admin_all on members for all using (is_admin()) with check (is_admin());
```

The app's `nextRegNo()` becomes a form preview only; the real number comes back from the insert.

---

## 5. Code changes in this repo

- [x] `pubspec.yaml` — add `supabase_flutter`; set a real `description`
- [x] `lib/main.dart` — `Supabase.initialize(url, anonKey)` via `String.fromEnvironment`
- [x] `lib/data/repositories/supabase_trust_repository.dart` — new, implements `TrustRepository`
- [x] `lib/data/repositories/trust_repository.dart` — add paged methods (`fetchMembersPage(filter, offset, limit)`, etc.) and `fetchDashboardStats(yojnaId)`
- [x] `lib/state/providers.dart` — switch `repositoryProvider`
- [x] `lib/state/selectors.dart` — server stats providers; filters as query parameters
- [x] `lib/state/auth_controller.dart` — real OTP calls, `bypassLogin = false`, session listener
- [x] `lib/core/router/app_router.dart` — redirect to `/login` when signed out
- [x] `lib/widgets/responsive_table.dart` — pagination controls, server-side search
- [x] New: `supabase/migrations/*.sql`, `.github/workflows/*.yml`, `web/_headers`
- [x] Delete `vercel.json`

---

## 6. Backups & keep-alive

### Nightly backup
- [x] GitHub Actions cron at 02:00 IST (`30 20 * * *` UTC)
- [x] `pg_dump` → encrypt with `age` → upload to R2
- [x] Retain 30 daily and 12 monthly copies
- [ ] Monthly restore drill into staging

### Keep-alive & size alert
- [x] Cron every 2 days runs a small query (prevents the 7-day idle pause during holidays)
- [x] Same job checks `pg_database_size()` and opens a GitHub issue above 350 MB

---

## 7. Aadhaar & privacy

Aadhaar numbers, phones and nominee details are personal data under India's DPDP Act 2023, and UIDAI rules limit who may store full Aadhaar numbers. **The trust's CA or legal advisor should confirm the approach.**

- [ ] **Needed before Release 2:** agents and members must never receive the full number (section 11.4)
- [ ] Store only the last 4 digits for display (`XXXX-XXXX-1234`); if the full number is required, encrypt it (`pgsodium`/Vault) and allow only the admin role to decrypt
- [ ] Consent checkbox in the add-member form
- [ ] Way to export or delete a member's data on request
- [ ] Database in Mumbai region
- [ ] No personal data in logs or audit JSON

---

## 8. Risks

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| Supabase changes its free tier | Medium | Standard Postgres + nightly dumps; move in a day, or Pro at $25/month |
| Project pauses during a quiet period | Low | Keep-alive cron; one-click restore in dashboard |
| Database grows past 500 MB | Depends on volume | Alert at 350 MB; archive old years or upgrade |
| OTP emails go to spam | Medium | SPF/DKIM verified domain; test Gmail and Yahoo in QA |
| Wrong totals past 1,000 rows | Certain if not fixed | Server-side paging and SQL aggregates (Phase 5) |
| Import data is messy | High | Validated import with exceptions report before production |
| Agent sees another agent's members or full Aadhaar | Medium if done in UI only | Agents and members get no table policies; all access goes through database functions that filter and mask (section 11.4); pgTAP tests for each role |
| Agent records cash that never reaches the trust | Medium | Agent payments start as Pending; admin approval and cash handover tracking (Phases 12, 16) |
| Closing announcement exceeds Brevo's 300 emails/day | Certain at ~2,000 members | In-app announcements and agent WhatsApp reminders; email only for logins |
| Member lookup page gets guessed | Low | Needs reg no + phone + last 4 Aadhaar digits; lock after 5 failed tries; Cloudflare Turnstile |

---

## 9. Questions for the client (needed by 15 Sep)

- [ ] How many members today, and expected in 3 years? How many closings per month?
- [ ] Is one receipt recorded per member per closing, or one entry per agent/batch?
- [ ] Is the full Aadhaar number needed, or are the last 4 digits enough?
- [x] Is there existing data (Excel or register) to import? **No.**
- [ ] How many admins, and their emails? Should any be limited to certain Yojnas?
- [ ] Are printable/PDF receipts, Excel export, or SMS/WhatsApp needed? (Not in the current build.)
- [x] Which domain name, and who owns the DNS? **None; use the free pages.dev address.**
- [ ] Should a closing case's "collected amount" come automatically from linked receipts, or stay manual?

**Release 2 (roles), needed by 6 Oct.** Defaults in section 11.2 apply until the client answers.
- [ ] Do agents handle cash?
- [ ] Does an agent's new member become active straight away, or only after admin approval?
- [ ] Are dues charged per closing group, or monthly or yearly?
- [ ] Do most members have a smartphone? An email address?
- [ ] Do members pay only through their agent, or also directly by UPI to the trust?
- [ ] Who are the owner-level admins?
- [ ] How and when is agent commission paid out?

---

## 10. Handover checklist

- [ ] All accounts (Supabase, Brevo, Cloudflare, GitHub, domain) owned by a client email; developer added as a member only
- [ ] Credentials in a shared password manager, not chat or email
- [ ] Production and staging URLs shared; at least 2 admins can log in
- [ ] Latest backup restored successfully; restore steps written down
- [x] Runbook: add/remove admin, check database size, unpause, restore, deploy
- [ ] Training done; short Hindi user guide for common tasks
- [ ] Scope sign-off; support window start and end dates agreed

---

## 11. Release 2 — Agent and member roles

Added 17 Sep 2026. Right now only invited admins can use the app. Release 2 gives agents and members their own logins, each limited to their own data.

### 11.1 Roles

| Role | Who | Scope | Main jobs |
| --- | --- | --- | --- |
| **Owner** | Trustees (1–2 people) | Everything | Admins, Yojnas, claim amounts, cancel receipts, closing payouts, full Aadhaar, audit log |
| **Staff admin** | Office staff | All members and payments | Daily work; approves agent submissions; can't delete or cancel |
| **Agent** | Field agents | Members where `agent_id` is theirs, in their `yojna_ids` | Add members, collect money, chase dues, report closings |
| **Member** | Enrolled members | Their own record | See status, dues, receipts, announcements; ask for changes |

**Rules**
- Agents and members **submit**; admins **approve**. Money and nominee details never change without an admin.
- Nothing is hard-deleted. Payments are cancelled with a reason, and members are marked Inactive.
- Access is enforced in the database (section 11.4), not only by hiding screens in the app.

### 11.2 Decisions (defaults until the client answers section 9)

| Question | Default |
| --- | --- |
| Agent's new member | Saved as **Pending approval**; reg number issued when an admin approves |
| Agent's payment | Saved as **Pending**; counts toward totals only after an admin marks it Paid |
| What "dues" means | One contribution per member per closing group, at the Yojna's `contributionAmount` |
| Member login | **Lookup page** (reg no + phone + last 4 Aadhaar digits) for everyone; **email OTP** for members who have email |
| Notifications | In-app bell and announcements, plus WhatsApp share links (`wa.me`). No SMS, no WhatsApp Business API, no bulk email |
| Direct member payments | Trust UPI QR code; member enters the UTR; saved as Pending |
| Commission | `commissionPercent` × approved payments collected by that agent, reported monthly |

### 11.3 Permissions

| Action | Owner | Staff admin | Agent | Member |
| --- | --- | --- | --- | --- |
| Manage Yojnas, claim amounts | ✅ | View | View (own Yojnas) | View (own) |
| Add member | ✅ | ✅ | ✅ Pending approval | ❌ |
| Approve new member | ✅ | ✅ | ❌ | ❌ |
| Edit member | ✅ | ✅ | Phone, alt phone, address | Change request |
| Change nominee, name, Aadhaar | ✅ | ✅ | Change request | Change request |
| Mark member inactive | ✅ | ❌ | ❌ | ❌ |
| View members | All | All | Own | Self |
| Full Aadhaar | ✅ | ❌ (masked) | ❌ (masked) | Last 4 digits |
| Record payment | ✅ Paid | ✅ Paid | ✅ Pending | UTR only, Pending |
| Approve or reject payment | ✅ | ✅ | ❌ | ❌ |
| Cancel payment | ✅ | Request | Request | ❌ |
| Create closing case | ✅ | ✅ | Closing request + certificate | ❌ |
| Mark closing payout paid | ✅ | ❌ | ❌ | View (own family) |
| Manage agents, send invites | ✅ | View | ❌ | ❌ |
| Post announcements | ✅ | ✅ | ❌ | View |
| Cash handover | Confirm | Confirm | Declare | ❌ |
| Commission | Mark paid | View | View own | ❌ |
| Reports and exports | All | All | Own members | Own receipts |
| Audit log | ✅ | ❌ | ❌ | ❌ |

### 11.4 Database changes

**How access works.** Row-level security decides which rows a user sees, not which columns, so it can't hide Aadhaar from an agent who can read `members`. Instead:
- Owner and staff admin keep today's table policies. `is_admin()` stays; `is_owner()` is added for owner-only actions.
- **Agents and members get no table policies at all.** Everything they do goes through `security definer` functions that check the role, filter rows to their own, mask Aadhaar and force safe values (for example `status = 'pending'`, `agent_id = my_agent_id()`).
- The existing stats functions already follow each user's access rules (`security invoker`). Agent dashboards use separate `agent_*` functions.

**Schema**
- [ ] `profiles` (`user_id` → `auth.users`, `role` enum `owner | staff | agent | member`, `agent_id`, `member_id`, `is_active`). Move `admins` into it and keep `is_admin()` working.
- [ ] Helpers `current_role()`, `is_owner()`, `my_agent_id()`, `my_member_id()`; each returns null or false for inactive profiles
- [ ] `member_status` gets `pending`. Reg number is issued on approval, not on insert, so rejected sign-ups don't use up numbers.
- [ ] `payments`: add `closing_case_id` (which closing this contribution is for), `approved_by`, `approved_at`, `reject_reason`, `cancelled_at`, `cancel_reason`, `source` (`admin | agent | member`)
- [ ] View `member_dues`: closing cases × active members of that Yojna who joined before the closing date, minus Paid contributions linked to that case
- [ ] `closing_requests` (member, reported by, date of death, nominee, certificate Cloudinary URL, status)
- [ ] `change_requests` (member, requested by, field, old value, new value, status, decided by)
- [ ] `notifications` (user, type, title, body, link, `read_at`), filled by triggers on approve, reject, new closing and reassignment
- [ ] `announcements` (Yojna or all, title, body, posted by, `published_at`)
- [ ] `cash_handovers` (agent, amount, payment ids, declared at, confirmed by, confirmed at)
- [ ] `commission_payouts` (agent, month, amount, paid at, reference)
- [ ] `lookup_attempts` (reg no, time, success) to lock the member lookup after 5 failures per hour
- [ ] Audit log covers every new table

**Functions (RPC)**
- [ ] Agent: `agent_dashboard()`, `agent_members(query, offset, limit)`, `agent_add_member(...)`, `agent_update_contact(member_id, ...)`, `agent_record_payment(...)`, `agent_dues(closing_case_id)`, `agent_request_closing(...)`, `agent_declare_handover(payment_ids)`, `agent_commission(month)`
- [ ] Member: `member_profile()`, `member_payments()`, `member_dues()`, `member_submit_utr(...)`, `member_request_change(...)`, `public_member_lookup(reg_no, phone, aadhaar_last4, turnstile_token)` (Edge Function, returns a read-only summary)
- [ ] Admin: `approve_member`, `approve_payment`, `reject_payment`, `cancel_payment` (owner), `decide_change_request`, `confirm_handover`, `reassign_members(from_agent, to_agent)`
- [ ] Edge Function `invite_user(email, role, agent_id | member_id)`, owner only. It creates the auth user and profile and sends the invite email, so owners no longer invite people from the Supabase dashboard.

### 11.5 App changes

- [ ] `AuthController`: load the profile after login; unknown or inactive profile → signed out with a message
- [ ] Router: three shells by role — `/admin/*` (today's app), `/agent/*`, `/me/*` — plus a public `/lookup` page. The redirect guard blocks routes for other roles.

- [ ] `AdminUser` becomes `AppUser` with a `role` enum
- [ ] `TrustRepository` split into `AdminRepository`, `AgentRepository`, `MemberRepository`, with Supabase and in-memory versions of each for tests
- [ ] Agent and member screens designed for phones first (390 px), with a bottom navigation bar
- [ ] Admin additions: approval queue with a badge count, agent invite button, reassign members, handovers, commission, announcements, change requests
- [ ] Hindi and English strings for every new screen

### 11.6 Timeline

Release 1 support window (5–19 Oct) overlaps with this. Support fixes come first.

#### Phase 10 — Decisions, roles schema, access rules (6–8 Oct, Tue–Thu, 3 days)
- [ ] Client answers the Release 2 questions (section 9); update section 11.2 (building on the 11.2 defaults meanwhile)
- [ ] Aadhaar approach from section 7 decided
- [x] `profiles`, helper functions (`my_role`, `is_owner`, `my_agent_id`, `my_member_id`, `my_profile`), `admins` kept as a view; existing admins became `owner` (`supabase/migrations/20260917000200_roles.sql`, 17 Sep 2026)
- [x] New columns and enum values on `members` and `payments`: member `pending` with the reg number issued on approval; payment source, approval, cancel, closing and handover links
- [x] New tables from section 11.4, with audit triggers and access rules: staff can't delete or change schemes, agents or commission
- [x] Role tests: `supabase/tests/roles_test.sql` (owner, staff, agent, inactive agent, member, pending member, no profile, anon), run in CI
- [ ] **Done when:** an agent test user can't select any table directly and a member can't see another member. Checked by `roles_test.sql`; passes once CI runs it green
- [ ] Apply to staging with `supabase db push`, then production (only after CI is green)

#### Phase 11 — Role login and app shells (9, 12 Oct, Fri–Mon, 2 days)
- [x] `invite_user` Edge Function (owner only; agents, members, staff, owners) and a Hindi/English invite email shared by all roles (17 Sep 2026)
- [x] Owner action on the Agents page: **Invite to app**, plus an **App access** status in agent details
- [x] Profile loading (`my_profile`, falls back to `admins` before the migration), role-based routing (`redirectFor`), admin shell plus the agent and member shell (`RoleShell`) with placeholder sections; admin paths stay at `/dashboard` etc., agents use `/agent`, members `/me`; reload waits on an access check
- [x] Deactivating an agent blocks their login and data at once; an open session is signed out at the next hourly token refresh or on reload
- [x] Tests: `test/role_access_test.dart` (routing per role, shells, access check, invite shown only to owners); `deno check` of the function in CI
- [ ] Deploy to staging: `supabase db push`, `supabase functions deploy invite_user`, `supabase config push` (invite subject)
- [ ] **Done when:** owner invites an agent from the Agents page, the agent logs in and lands on `/agent` (manual check on staging)

#### Phase 12 — Agent members, collections, admin approval (13–15 Oct, Tue–Thu, 3 days)
> Built 18 Sep 2026: `supabase/migrations/20260918000100_agent_work.sql`, Approvals page, agent screens in `lib/features/agent/`.
> Decisions: agent receipts get their receipt number when recorded (the agent hands it to the member) and count in totals only after approval; a rejected sign-up stays as an Inactive member without a reg number, so money recorded for it keeps its member; office-entered Pending payments are unpaid dues and stay out of the approval queue.

- [x] Agent: my members list and search, add member (Pending), edit contact fields (phones and address only; Aadhaar never sent to agents)
- [x] Agent: record payment (Pending; only the registration fee before approval), view own receipts, request a cancel
- [x] Agent home: members, amount waiting for approval, approved this month
- [x] Admin: Approvals page (the top-bar bell opens it) for new members, agent payments and cancel requests; approve, or reject with a reason
- [x] Owners cancel receipts (Approvals or Payments page); cancelled receipts stay listed but leave every total
- [x] Dashboard totals count Paid only; pending payments are in the approval queue and the Payments page
- [x] `pending` in the Dart `MemberStatus` enum; pending members left out of `dashboard_stats`, `members_per_yojna`, `member_count_by_agent`
- [x] Payment totals leave out cancelled payments (`cancelled_at`)
- [x] Admin: move all of an agent's members to another agent (Agents page → Move members)
- [x] Tests: `supabase/tests/agent_work_test.sql` (CI), `test/approvals_test.dart`, `test/agent_screens_test.dart`
- [ ] Deploy to staging: `supabase db push`
- [ ] **Done when:** an agent's payment appears in the admin queue, and after approval shows in totals with a receipt number (covered by the SQL and app tests; check once on staging)

#### Phase 13 — Dues and WhatsApp (16, 19 Oct, Fri–Mon, 2 days)
> Built 17 Sep 2026: `supabase/migrations/20260919000100_dues.sql`, agent Dues tab in `lib/features/agent/agent_dues.dart`, WhatsApp messages in `lib/core/utils/whatsapp.dart`.
> Decisions: dues are per closing **group** (§11.2). A contribution linked to any case in the group counts; forms link to the group's first case. Members owe for a group when they are Active and joined before its first closing date; cases without a group label raise no dues. Agents can't collect twice for the same group; the office form allows it (for corrections). Death reports also got the admin side (approve into a closing case, or reject), so a report doesn't wait for Phase 16.

- [x] Link contributions to a closing in the payment forms: agent form picks the oldest open closing; office form offers every closing the member owes for (optional). A database trigger checks the link (contribution only, same Yojna, not the member's own case)
- [x] `closing_groups` and `member_dues` views (admins, under their access rules); agent functions `agent_closing_groups`, `agent_dues(yojna, group)`, `agent_member_dues(member)`; `agent_payments` also returns the member's phone and the closing group
- [x] Agent Dues tab: closing groups with paid count and amount to collect; per group, members still due, waiting for approval, or paid, with **Collect** and **Send reminder**
- [x] WhatsApp `wa.me` links with Hindi messages: receipt (after saving and from a receipt) and dues reminder
- [x] Agent reports a death from the member's details, with the certificate uploaded to Cloudinary (unsigned preset, JPG/PNG/PDF up to 10 MB; setup in `docs/RUNBOOK.md` §1.6). Office: Approvals page → **Create closing** (group and claim amount) or reject with a reason; agents see the outcome on the Dues tab
- [x] Tests: `supabase/tests/dues_test.sql` (CI) counts a closing group by hand; `test/dues_test.dart` (same count in memory, WhatsApp messages, screens at 390 and 1440 px)
- [x] Cloudinary preset `rudransh_certificates` (cloud `n9mgnr8s`): unsigned, folder `rudransh/certificates`, formats jpg/jpeg/png/pdf, unguessable public IDs, PDF delivery on. Verified 18 Sep 2026: PNG and PDF land in the folder, a PDF opens (HTTP 200), a `.txt` is refused
- [ ] GitHub variables `CLOUDINARY_CLOUD_NAME` = `n9mgnr8s`, `CLOUDINARY_UPLOAD_PRESET` = `rudransh_certificates` (repository **Variables**, not Secrets — `docs/RUNBOOK.md` §1.6)
- [ ] Deploy to staging: `supabase db push`
- [ ] **Done when:** for a test closing group, the dues list matches a manual count (covered by `dues_test.sql`; check once on staging)

**20 Oct (Tue):** Dussehra, holiday.

#### Phase 14 — Notifications and announcements (21–22 Oct, Wed–Thu, 2 days)
> Built 18 Sep 2026: `supabase/migrations/20260920000100_notifications.sql`, `lib/widgets/notifications_button.dart`, `lib/features/announcements/announcements_page.dart`.
> Decisions: the `notifications` and `announcements` tables already existed (Phase 11), so this phase only fills and serves them. Overdue dues are **not** a trigger — nothing happens at the moment a payment becomes late — so they come from `notify_overdue_dues(days)`, run daily by pg_cron (`docs/RUNBOOK.md` §2.1). The bell and the admin Requests inbox are separate: Requests is a work queue, the bell is what the office decided. On a phone the header has no room for the bell, so it moves into the avatar menu.

- [x] Triggers write notifications: payment approved / rejected (with the reason), death report approved / rejected, a new closing (every agent with an active member in that Yojna), members moved between agents (both sides). Re-saving a decided record does not notify again
- [x] `notify_overdue_dues(p_days)` for the daily sweep: one notice per agent per closing group, and never twice to the same agent for the same group on one day
- [x] RPCs `my_notifications`, `my_unread_count`, `mark_notification_read`, `mark_all_notifications_read`; the helpers (`notify`, `agent_user_id`, the sweep) are revoked from `authenticated`
- [x] Notification bell with an unread badge for all roles, opening a panel that marks one or all read and follows the link; on a phone it lives in the avatar menu
- [x] Admin posts announcements (all Yojnas or one) and deletes them; `my_announcements` shows an agent the Yojnas their members are in, a member their own, and trust-wide notices to everyone
- [x] Tests: `supabase/tests/notifications_test.sql` (CI), `test/notifications_test.dart` (18 checks: the same events in memory, both screens at 390 and 1440 px, the phone avatar-menu path)
- [ ] Schedule the daily job: `docs/RUNBOOK.md` §2.1, once per Supabase project
- [ ] **Done when:** approving a payment notifies the agent within one page refresh (covered by both test files; check once on staging)

#### Phase 15 — Member portal (23, 26–27 Oct, Fri, Mon–Tue, 3 days)
> Built 18 Sep 2026: `supabase/migrations/20260921000100_member_portal.sql`, `supabase/functions/member_lookup/`, `lib/features/portal/`.
> Decisions: the public lookup is granted to **`service_role` only** and fronted by the `member_lookup` Edge Function, which checks Turnstile first — so `anon` reaches no member data and a leaked publishable key is worthless here. Turnstile **fails closed**: without the secret the function returns 503 rather than serving records unprotected. The five-try lock counts per registration number, not per IP, because the database cannot see an IP and the number is what gets guessed. A member whose Aadhaar was never recorded (§7 leaves the column optional) is matched on registration number and phone alone. Members never write to `members`; every correction is an admin decision.

- [x] Public `/lookup`, reachable signed out: reg no + phone + last 4 Aadhaar digits, five wrong tries lock that number for 15 minutes. Returns a summary only — no Aadhaar, no address, no agent
- [x] `member_lookup` Edge Function: verifies Cloudflare Turnstile, then calls the database function as the service role
- [x] Member screens: membership, dues, receipts, announcements (Phase 14), the member's own closing case
- [x] Pay by UPI: the member pays in their own app and enters the UTR; it lands as a **pending** receipt an admin approves, and the same UTR twice is refused
- [x] Change requests for phone, address, nominee and name: one pending change per field, applied by an admin, and the member is told either way
- [x] Admin side: corrections join the Approvals queue beside members, payments and death reports
- [x] Tests: `supabase/tests/member_portal_test.sql` (CI, 9 check groups, run against real Postgres), `test/member_portal_test.dart` (25 checks: the lookup rules including the lock, the portal rules, both screens at 390 and 1440 px, the signed-out route)
- [ ] Member email-OTP login for the few members who have email — the invite path exists (`invite_user`, role `member`); not yet exercised end to end
- [ ] Turnstile keys and the Edge Function deploy (`docs/RUNBOOK.md` §1.7); `UPI_ID` / `UPI_PAYEE` variables
- [x] Render the Turnstile widget on the web build (20 Sep 2026): `lib/features/portal/turnstile_web.dart` with a stub for tests and non-web builds, script in `web/index.html`, and **Check** disabled until Cloudflare returns a token. Still needs a real site key (item above) to be exercised end to end
- [ ] **Done when:** a member finds their dues on a phone in under a minute

#### Phase 16 — Commission, cash handover, change requests (28–30 Oct, Wed–Fri, 3 days)
> Built 20 Sep 2026: `supabase/migrations/20260922000100_commission.sql`, `lib/features/commission/commission_page.dart`, `lib/features/agent/agent_cash.dart`. The tables (`cash_handovers`, `commission_payouts`, `payments.cash_handover_id`) already existed from Phase 10, so this phase fills them.
> Decisions: **cash in hand** counts approved (`paid`), uncancelled, `cash` receipts not yet linked to a handover — UPI, bank and cheque never reach the agent's hand, and pending receipts stay out so a rejected one can never sit inside a declared handover. A handover is declared for **whole receipts**, not a typed amount, so the office can check the total against what it holds; the agent hands over everything (the default) or picks receipts. An admin who does not receive the money **rejects** the handover and its receipts unlink, putting the amount back in the agent's hand. **Commission** = `commission_percent` × approved, uncancelled registration and contribution receipts dated in that IST calendar month; claim payouts are money going out and never count. A month is recalculated on every read, and marking it paid stores what was actually paid, so a later correction shows as a difference rather than silently rewriting history.

- [x] Agent declares cash handover (pick receipts or all, with a note); admin confirms or rejects with a reason; "cash in hand" and "waiting to be confirmed" on the agent home and Collections page
- [x] Monthly commission report per agent (`/commission`, month switcher, owner-only **Mark paid**); agents see their own last six months on the Collections page
- [x] Handovers join the Approvals queue beside members, payments, death reports and corrections
- [x] ~~Admin screen for change requests~~ Built in Phase 15: corrections are already in the Approvals queue and `approve_change_request` writes the member row, which the audit trigger records
- [x] Agent dashboard complete: members, waiting for approval, approved this month, cash in hand, this month's commission, and the three newest closing groups
- [x] Agents are told when a handover is confirmed or refused and when commission is paid (Phase 14 bell); `NotificationKind` gains `handover_confirmed`, `handover_rejected`, `commission_paid`
- [x] Tests: `supabase/tests/commission_test.sql` (CI, 7 check groups, run against real Postgres 18 on 20 Sep 2026), `test/commission_test.dart` (16 checks: the same money in memory, role limits, both screens at 390 and 1440 px)
- [ ] Deploy to staging: `supabase db push`
- [ ] **Done when:** one month of test data gives correct commission and handover balances (covered by both test files; check once on staging)

#### Phase 16b — Membership certificate (20 Sep 2026, added after the client showed a printed sample)
> Built 20 Sep 2026: `supabase/migrations/20260923000100_member_certificate.sql`, `lib/core/config/trust_info.dart`, `lib/features/certificate/`. Plan and decisions: `docs/MEMBERSHIP_CERTIFICATE_PLAN.md`.
> Decisions: the sheet is **rendered as HTML and printed by the browser**, not built with the Dart `pdf` package — `pdf` does not shape Devanagari, and the certificate is entirely Hindi. Save-as-PDF is the browser's own. The **photo box is left blank** to paste a photo into, as the trust already does. The trust's fixed details (registration number, establishment date, president, head office) are **constants in `TrustInfo`**, not a settings table: they change once a year at most and cost nothing in the database.

- [x] `members.dob` and `members.state`, the two certificate fields the record was missing; optional, so existing members are unaffected
- [x] A4 landscape certificate, branded Rudransh, bundled Noto Sans Devanagari so it prints the same on a machine with no Hindi font
- [x] **Print certificate** on the admin member details and the agent member details; refused while a member has no registration number
- [x] Date of birth and state on the admin member form and the agent sign-up form; agents may correct the state with the rest of the address, date of birth stays with the office
- [x] Tests: `test/certificate_test.dart` (19 checks: field mapping, Hindi branding, the three invocations, the two states, office and phones, asset-loaded logo, both font URLs, the arched SVG heading, nothing outside the frame, HTML escaping, blanks instead of `null`), plus new asserts in `supabase/tests/agent_work_test.sql`
- [x] **Branding round, same day** (`20260923000200_yojna_start_date.sql`, `docs/MEMBERSHIP_CERTIFICATE_PLAN.md` §8): the client supplied the trust's own सदस्यता प्रपत्र and logo and asked for the reference sheet to be matched exactly
  - [x] Real branding in `TrustInfo`: रुद्रांश चेरीटेबल ट्रस्ट – लाखणी, three invocations, गुजरात and राजस्थान, the Lakhani office address and the three chosen phone numbers
  - [x] Logo as an asset (`assets/brand/rudransh_logo.jpg`), named once in `TrustInfo` and never embedded in code; blended with `mix-blend-mode` because the supplied file is a JPEG on white
  - [x] Arched, outlined heading in Yatra One (`assets/fonts/`, SIL OFL 1.1), drawn as SVG because CSS cannot curve a baseline; the arc is shallow so Devanagari matras stay on their consonants
  - [x] Row order corrected to the reference: `सम्बन्ध` closes the `पता` row, `मोबाईल नं.` shares a row with `वारिसदार`, the amount comes before `रु`, and `कार्यकर्ता`/`नोंध`/`अध्यक्ष` share one row
  - [x] Corner flourishes, double crimson border, cream wash
  - [x] `योजना प्रारंभ` became a real `yojnas.start_date` instead of the day the record was typed in; `agent_yojnas()` rebuilt to return it and the description, so agents can print a complete sheet
  - [x] `flutter test tool/certificate_preview/preview_test.dart` writes `build/certificate_preview.html` for checking the design without starting the app
- [x] President named (शैलेषभाई वी.लुहार); the establishment date and registration number filled with placeholders at the client's request — the registration number is deliberately shaped rather than plausible (`docs/MEMBERSHIP_CERTIFICATE_PLAN.md` §8)
- [x] **Second review, 21 Sep 2026** (`docs/MEMBERSHIP_CERTIFICATE_PLAN.md` §9): महाराष्ट्र and the `Since` line dropped, the **tear-off receipt slip removed** so the frame fills the page, and the logo replaced with a tighter crop. `slipNote`, `slipAmount`, `agentArea` and the registration-payment plumbing went with it
- [ ] **Replace the placeholder `संस्था रजीस्टर नं.` with the real number before any certificate reaches a member**, plus the real establishment date; a signature image and a transparent PNG logo are optional extras
- [ ] Office types the real scheme name, start date and `नोंध` wording into the Yojna screen — they are data, not code
- [ ] Deploy to staging: `supabase db push`
- [ ] **Done when:** a printed certificate matches the reference sheet and the Hindi reads correctly on paper

#### Phase 17 — QA and launch (2–5 Nov, Mon–Thu, 4 days)
> QA work done 20 Sep 2026. Everything below that is still open needs either an account nobody but the client holds (GitHub, Supabase, Cloudflare, Cloudinary) or people in a room, so it cannot be finished from the repo.
> Found while sweeping: `test/integration/supabase_repository_test.dart` had its Hindi string literals **double-encoded through CP1252** (13 places, committed that way). Every Hindi assertion in the API job compared mojibake against real Devanagari, so those tests could never have passed. Fixed and verified against real PostgREST. Both concurrency scripts also compared psql output without stripping `\r`, which made them fail on Windows while passing in CI.

- [ ] **Clear section 0, "Outstanding setup"** — deferred switch-on work, including the Cloudinary GitHub variables and the dues migration. Do this first: item 1 fails silently in production. Item 9 is now done; 1–6, 8, 10 and 11 need the client's accounts
- [x] Access tests for each role, through the API as well as the UI: `test/integration/role_api_test.dart` (13 checks) runs every table and RPC as owner, both agents, a member, a signed-in user with no profile, and signed out. An agent reading `/members` directly gets `[]`, the two agents' member sets never intersect, and Aadhaar is absent from `agent_members`. Run against real PostgREST 16.3 + Postgres 18 on 20 Sep 2026
- [x] Layout at 390 px for the agent and member shells; Hindi text; light and dark themes: `test/role_layout_test.dart` (15 checks) walks every agent and member page at 390 / 768 / 1440 px in both themes, plus the signed-out lookup, the Devanagari fallback font, and Hindi names actually rendering in an agent's list
- [x] Two agents and an admin working at once: no duplicate reg or receipt numbers — `supabase/tests/concurrent_roles_test.sh` (in CI) runs both agents through `agent_add_member` / `agent_record_payment` as `authenticated` while an admin inserts directly, then approves every pending member in one statement, which is when an agent's member is given its number
- [x] Update the runbook: invite or deactivate an agent (already there), move an agent's members, unlock a member lookup, confirm or reject a cash handover, pay commission (`docs/RUNBOOK.md` §3)
- [x] Hindi guides: one page for agents, one for members (`docs/AGENT_GUIDE_HI.md`, `docs/MEMBER_GUIDE_HI.md`)
- [ ] Train agents (1 hour); client signs off on staging
- [ ] **Launch Thu 5 Nov**, before Diwali (8 Nov)

### 11.7 Staying on the free tier

| Need | Free option | Limit to watch |
| --- | --- | --- |
| Agent and member logins | Supabase Auth, email OTP | 50k monthly users; Brevo 300 emails/day |
| Server logic (invite, lookup) | Supabase Edge Functions | 500k calls/month |
| Bot protection on lookup | Cloudflare Turnstile | Free |
| Reminders and receipts | WhatsApp `wa.me` links sent from the agent's phone | Manual send, no API |
| Certificates and photos | Cloudinary (already used) | Existing free quota |
| Push notifications (later) | Firebase Cloud Messaging | Free; needs another account, so not in Release 2 |

Extra database size is small: notifications and requests are a few KB per row. Clear read notifications after 90 days.

---

## Sources for free-tier limits (checked 14 Sep 2026)

- [Supabase free tier limits 2026](https://automationatlas.io/answers/supabase-free-tier-limits-2026/)
- [Supabase pricing guide](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/)
- [Supabase: custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
- [Supabase default mailer 2/hour limit](https://dreamlit.ai/blog/how-to-send-emails-supabase)
- [SMTP providers compared](https://codenote.net/en/posts/supabase-auth-custom-smtp-comparison/)
- [Firebase pricing](https://firebase.google.com/pricing)
- [Spark vs Blaze](https://dev.to/androve2k/spark-vs-blaze-the-firebase-pricing-guide-i-wish-id-read-sooner-onb)
- [Cloudflare D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/)
- [D1 free-tier enforcement (1 Sep 2026)](https://developers.cloudflare.com/changelog/post/2026-09-01-d1-free-tier-limit-enforcement/)
- [Cloudflare Pages free tier 2026](https://temps.sh/blog/cloudflare-pages-free-tier-limits-2026)
- [Vercel Hobby plan](https://vercel.com/docs/plans/hobby)
- [Vercel fair use guidelines](https://vercel.com/docs/limits/fair-use-guidelines)
