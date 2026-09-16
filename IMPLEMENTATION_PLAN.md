# Rudransh CT — Go-Live Plan

Plan to take the Flutter web admin panel (रुद्रांश चैरिटेबल ट्रस्ट) from in-memory demo data and a stubbed OTP login to a production deployment on a free stack.

- **Start:** Mon 14 Sep 2026
- **Go-live:** Mon 5 Oct 2026 (Release 1: admin panel)
- **Release 2:** Thu 5 Nov 2026 (agent and member roles, section 11)
- **Effort:** ~15 working days for Release 1, ~21 working days for Release 2, one full-time developer
- **Running cost:** ₹0/month (a domain name, if used, is about ₹800–1,000/year)

> **Update 17 Sep 2026:** the app will have three roles: **Admin** (owner or staff), **Agent** and **Member**. Release 1 goes live admin-only as planned. Roles come in Release 2 (section 11), so the launch date doesn't move.

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
- [ ] Client answers the Release 2 questions (section 9); update section 11.2
- [ ] Aadhaar approach from section 7 decided
- [ ] `profiles`, helper functions, migrate `admins`
- [ ] New columns and enum values on `members` and `payments`
- [ ] New tables from section 11.4
- [ ] pgTAP tests: for each role, what it can and can't read or write
- [ ] **Done when:** an agent test user can't select any table directly and a member can't see another member

#### Phase 11 — Role login and app shells (9, 12 Oct, Fri–Mon, 2 days)
- [ ] `invite_user` Edge Function and invite email template (agent and member versions)
- [ ] Profile loading, role-based routing, three shells
- [ ] Deactivating an agent signs them out and blocks their login
- [ ] **Done when:** owner invites an agent from the Agents page, the agent logs in and lands on `/agent`

#### Phase 12 — Agent members, collections, admin approval (13–15 Oct, Tue–Thu, 3 days)
- [ ] Agent: my members list and search, add member (Pending), edit contact fields
- [ ] Agent: record payment (Pending), view own receipts, request a cancel
- [ ] Admin: approval queue for members and payments, approve or reject with a reason
- [ ] Dashboard totals count Paid only; Pending shown separately
- [ ] Admin: reassign members between agents
- [ ] **Done when:** an agent's payment appears in the admin queue, and after approval shows in totals with a receipt number

#### Phase 13 — Dues and WhatsApp (16, 19 Oct, Fri–Mon, 2 days)
- [ ] Link contributions to a closing case in the payment forms (admin and agent)
- [ ] `member_dues` view and `agent_dues` function
- [ ] Agent dues screen per closing group: paid, pending and amount due
- [ ] WhatsApp share buttons: receipt, dues reminder (Hindi template)
- [ ] Agent closing request with certificate upload (Cloudinary)
- [ ] **Done when:** for a test closing group, the dues list matches a manual count

**20 Oct (Tue):** Dussehra, holiday.

#### Phase 14 — Notifications and announcements (21–22 Oct, Wed–Thu, 2 days)
- [ ] `notifications` triggers: approved, rejected, new closing, member reassigned, dues overdue
- [ ] Notification bell with unread count in the top bar, for all roles
- [ ] Admin posts announcements (all or per Yojna); agents and members see them
- [ ] **Done when:** approving a payment notifies the agent within one page refresh

#### Phase 15 — Member portal (23, 26–27 Oct, Fri, Mon–Tue, 3 days)
- [ ] Public `/lookup`: reg no + phone + last 4 Aadhaar digits, Cloudflare Turnstile, lock after 5 failures
- [ ] Member email-OTP login for members who have email (invited by an admin)
- [ ] My membership, my payments, my dues, announcements, my family's closing case
- [ ] Pay by UPI: trust QR code + UTR form (Pending)
- [ ] Change request form (phone, address, nominee)
- [ ] **Done when:** a member finds their dues on a phone in under a minute

#### Phase 16 — Commission, cash handover, change requests (28–30 Oct, Wed–Fri, 3 days)
- [ ] Agent declares cash handover; admin confirms; "cash in hand" on the agent dashboard
- [ ] Monthly commission report per agent; owner marks it paid
- [ ] Admin screen for change requests: approve applies the change and writes the audit log
- [ ] Agent dashboard complete: members, collected vs. pending, cash in hand, commission, recent closings
- [ ] **Done when:** one month of test data gives correct commission and handover balances

#### Phase 17 — QA and launch (2–5 Nov, Mon–Thu, 4 days)
- [ ] Access tests for each role, through the API as well as the UI (try to read another agent's members directly)
- [ ] Layout at 390 px for the agent and member shells; Hindi text; light and dark themes
- [ ] Two agents and an admin working at once: no duplicate reg or receipt numbers
- [ ] Update the runbook: invite or deactivate an agent, reassign members, unlock a member lookup
- [ ] Hindi guides: one page for agents, one for members
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
