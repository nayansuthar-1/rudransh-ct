# Rudransh CT — Runbook

Setup and day-to-day operations for the production admin panel. Stack: Supabase
(database + login), Brevo (OTP emails), Cloudflare Pages (hosting), Cloudflare R2
(backups), GitHub Actions (deploys and scheduled jobs).

All accounts belong to the trust's email (`rudranshct@gmail.com`). Developers are
added as members only. Credentials live in the shared password manager.

---

## 1. One-time setup

### 1.1 Supabase projects

1. Create two projects in region **Mumbai (ap-south-1)**: `rudransh-prod` and `rudransh-staging`.
2. Apply the migrations to each project (staging first):
   ```bash
   supabase login
   supabase link --project-ref <staging-ref>
   supabase db push
   ```
3. Run the database checks against staging. They run in a transaction that is rolled back:
   ```bash
   psql "<staging session-pooler URL>" -v ON_ERROR_STOP=1 -f supabase/tests/database_test.sql
   ```
   Expect `admin checks passed`, `non-admin checks passed` and `anon checks passed`.
   Do **not** run `auth_stub.sql` against Supabase.
4. Repeat steps 2–3 for `rudransh-prod` once staging is signed off.
   Relink to staging afterwards so a stray `db push` never hits production.

### 1.2 Authentication settings (both projects)

These live in `supabase/config.toml`. Push them to the linked project with:

```powershell
$env:BREVO_SMTP_USER = "<login>@smtp-brevo.com"
$env:BREVO_SMTP_KEY = "<smtp key>"
$env:BREVO_SENDER_EMAIL = "<verified sender>"
supabase config push
Remove-Item Env:BREVO_SMTP_KEY
```

Free projects reject custom email templates unless SMTP is configured in the
same push. In `config.toml`, `[auth.email] enable_signup` switches email login
itself and must stay `true`; `[auth] enable_signup = false` is what blocks new
sign-ups. `site_url` and `additional_redirect_urls` point at
`rudransh-ct.pages.dev` (there is no custom domain). What the push sets, for
reference (Dashboard → **Authentication**):

| Setting | Value |
| --- | --- |
| Sign In / Providers → Allow new users to sign up | **Off** |
| Email provider → Email OTP length | 6 |
| Email provider → Email OTP expiration | 600 seconds |
| URL Configuration → Site URL | `https://rudransh-ct.pages.dev` |
| URL Configuration → Redirect URLs | `https://rudransh-ct.pages.dev`, `https://*.rudransh-ct.pages.dev`, `http://localhost:8080` |
| Emails → SMTP Settings | Brevo: host `smtp-relay.brevo.com`, port 587, user and SMTP key from Brevo, sender `rudranshct@gmail.com` (verified sender address) |
| Rate Limits → emails per hour | 100 (possible only after custom SMTP is on) |
| Emails → Templates → **Magic Link** | subject and body from `supabase/templates/otp.html` |
| Emails → Templates → **Invite user** | body from `supabase/templates/invite.html` |

The Magic Link template is the one used for OTP sign-in; `{{ .Token }}` prints the 6-digit code.

There is no trust domain, so Brevo sends from the verified sender address
`rudranshct@gmail.com` (no SPF/DKIM records to set). Before going live, test
delivery to Gmail and Yahoo inboxes and check the spam folder.

### 1.3 Cloudflare Pages

```bash
npx wrangler pages project create rudransh-ct --production-branch main
```

After the first deploy: Pages project → **Custom domains** → add the domain.
Response headers come from `web/_headers`. Pages serves `index.html` for unknown
paths, which the app's clean URLs need.

### 1.4 Backups (R2 + age)

1. Create an R2 bucket, e.g. `rudransh-backups`.
2. Bucket → Settings → **Object lifecycle rules**:
   - prefix `daily/`: delete after 30 days
   - prefix `monthly/`: delete after 365 days
3. Create an R2 API token with Object Read & Write on that bucket only.
4. Create an encryption key pair on a trusted machine:
   ```bash
   age-keygen -o rudransh-backup.key
   ```
   Store `rudransh-backup.key` (the private key) in the password manager and
   **nowhere else**; without it backups cannot be read. The `age1…` public key
   printed by the command becomes the `AGE_RECIPIENT` secret.

### 1.5 GitHub repository secrets

Settings → Secrets and variables → Actions.

| Secret | Used by | Value |
| --- | --- | --- |
| `CLOUDFLARE_API_TOKEN` | deploy | token with *Cloudflare Pages: Edit* |
| `CLOUDFLARE_ACCOUNT_ID` | deploy | Cloudflare account id |
| `SUPABASE_URL_PROD` / `SUPABASE_URL_STAGING` | deploy | `https://<ref>.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY_PROD` / `_STAGING` | deploy | Project Settings → API keys → publishable key |
| `SUPABASE_DB_URL_PROD` / `SUPABASE_DB_URL_STAGING` | backup, keep-alive | Connect → **Session pooler** URL (GitHub runners have no IPv6, so the direct URL fails) |
| `AGE_RECIPIENT` | backup | `age1…` public key |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ACCOUNT_ID`, `R2_BUCKET` | backup | from step 1.4 |

Optional variable `CLOUDFLARE_PAGES_PROJECT` if the Pages project has another name.

Variables (not secrets; they end up in the browser): `CLOUDINARY_CLOUD_NAME` and
`CLOUDINARY_UPLOAD_PRESET` from step 1.6. Without them agents can't upload a
death certificate, and the app says so.

The publishable key is safe in the browser: row-level security allows nothing
unless the signed-in user has an active profile in `public.profiles`. Never put the secret or
service-role key in the app or in `--dart-define`.

### 1.6 Cloudinary (death certificates)

Agents upload a photo or PDF of the death certificate when they report a death.
The app uploads straight to Cloudinary with an **unsigned upload preset**; the
database stores only the `https://res.cloudinary.com/…` link.

1. Cloudinary console → Settings → **Upload** → Upload presets → **Add upload preset**:
   - Signing mode: **Unsigned**
   - Asset folder: `rudransh/certificates`
   - Use filename / unique filename: off / on
   - Allowed formats: `jpg,jpeg,png,pdf`
   - Max file size: leave it. The console drops `max_file_size` on a preset, but
     the free plan already caps uploads at 10 MB, and `allowed_formats` keeps
     everything to image types, so that cap applies. The app checks 10 MB too,
     in the browser, to give a clear message before the upload starts.
   - Incoming transformation (optional, keeps photos small): limit to 2000 px, quality auto
2. Settings → **Security** → turn on **Allow delivery of PDF and ZIP files**,
   or admins can't open PDF certificates.
3. Set the GitHub repository **variables** (Settings → Secrets and variables →
   Actions → Variables, *not* Secrets; the workflow reads them with `vars.`):
   `CLOUDINARY_CLOUD_NAME` = `n9mgnr8s`, `CLOUDINARY_UPLOAD_PRESET` =
   `rudransh_certificates`. Local runs:
   `--dart-define=CLOUDINARY_CLOUD_NAME=… --dart-define=CLOUDINARY_UPLOAD_PRESET=…`

Editing the preset through the Admin API **replaces** its settings instead of
merging them, so a call that sets one field clears the others — send the asset
folder and allowed formats every time, then read the preset back and check.
The console UI merges, so prefer it for one-off changes.

Anyone who reads the app's code can see the preset name and upload files within
these limits; they can't read, change or delete existing files. If abused,
rename the preset and update the variable.

### 1.7 Public member lookup (Turnstile) and UPI

Most members have no email and never will, so `/lookup` answers without a
login: registration number + phone + the last four Aadhaar digits. Cloudflare
Turnstile keeps bots from walking through registration numbers, and the
database locks a number after five wrong tries in fifteen minutes.

1. Cloudflare dashboard → **Turnstile** → Add site:
   - Domain: the Pages domain (`rudransh-ct.pages.dev`)
   - Widget mode: **Managed**
   - You get a **site key** (public) and a **secret key** (never in the app)
2. Set the repository **variable** `TURNSTILE_SITE_KEY` to the site key.
3. Give the Edge Function the secret, then deploy it:
   ```sh
   supabase secrets set TURNSTILE_SECRET_KEY=0x...
   supabase functions deploy member_lookup --no-verify-jwt
   ```
   `--no-verify-jwt` is required: the caller is signed out by definition.

**The lookup fails closed.** Without `TURNSTILE_SECRET_KEY` the function
returns 503 and the page says the check is not switched on. That is deliberate
— the alternative is serving member records to anything that can send a POST —
but it does mean the lookup looks broken until step 3 is done.

For UPI payments from the member portal, set the variables `UPI_ID` (the
trust's UPI address) and `UPI_PAYEE` (the name shown in a payment app). Leaving
`UPI_ID` empty hides the option, and members pay through their agent as before.
A member enters the UTR after paying; it lands as a **pending** receipt that an
admin approves, so nothing counts until the office has seen the money.

---

## 2. Deploying

| Action | Result |
| --- | --- |
| Pull request | Migrations checked, `flutter analyze` + `flutter test`, preview built against **staging** and its URL posted on the PR |
| Merge to `main` | Same checks, then deploy to **production** |
| Bad release | Cloudflare Pages → Deployments → pick the previous one → **Rollback** |

Database changes: add a new file in `supabase/migrations/` (never edit an applied
one), merge, then `supabase db push` to staging, test, and push to prod.

### 2.1 Overdue dues (daily job)

Most notifications come from triggers and need no setup. Overdue dues are the
exception: nothing happens at the moment a payment becomes late, so a sweep has
to run on a schedule. Without it agents are never told about stale dues, and
nothing else in the app reports it.

In the Supabase dashboard → SQL editor, once per project:

```sql
create extension if not exists pg_cron;
select cron.schedule(
  'overdue-dues', '30 3 * * *',           -- 09:00 IST
  $$select public.notify_overdue_dues(30)$$
);
```

It writes one notification per agent per closing group older than 30 days that
still has unpaid members, and it will not repeat a group to the same agent on
the same day, so a retry after a failed run is safe. Change the `30` to move
the threshold. To check it: `select * from cron.job_run_details order by
start_time desc limit 5;`.

---

## 3. Admins

Access comes from `public.profiles` (one row per user). Roles:

| Role | Can do |
| --- | --- |
| `owner` | Everything: schemes, agents, commission, deletes, audit log |
| `staff` | Daily work: members, payments, closing cases, announcements. No deletes, no scheme or agent changes |
| `agent`, `member` | Nothing in the admin panel. They sign in to their own screens (`/agent`, `/me`) |

Admins who existed before the roles migration became `owner`. `public.admins`
is now a read-only view of active owner and staff profiles.

**Add an admin**

1. Dashboard → Authentication → Users → **Invite user** → their email.
2. SQL Editor (use `'staff'` for office staff, `'owner'` for trustees):
   ```sql
   insert into public.profiles (user_id, role, name, email)
   select id, 'staff', 'Full Name', email from auth.users where email = 'person@example.com';
   ```
3. They click **Activate account** in the invite email once. Until then Supabase
   treats them as a new sign-up and refuses to send a code (the app says the email
   is not registered). If the link cannot be used, confirm them by hand:
   ```sql
   update auth.users set email_confirmed_at = now()
   where email = 'person@example.com' and email_confirmed_at is null;
   ```
4. They open the site, enter their email and type the 6-digit code from the email.

An invited user without an active owner or staff profile is signed straight back
out, and an email that was never invited cannot request a code.

**Change a role**

```sql
update public.profiles set role = 'owner' where email = 'person@example.com';
```

Keep at least one active `owner`.

**Remove an admin**

```sql
update public.profiles set is_active = false where email = 'person@example.com';
```

Deactivating keeps their name on past records. To remove them completely, also go
to Authentication → Users → delete the user, which ends their sessions and
deletes the profile.

**Give an agent app access** (needs the roles migration and the `invite_user`
function on the project, see below)

1. Agents page → the agent's **⋯** menu → **Invite to app**. Only owners see it,
   and the agent needs an email address and must be active.
2. The agent clicks **Activate account** in the email once, then signs in with
   the 6-digit code like admins do. They see only the agent screens.

The agent's details show **App access**: *Not invited*, *Invited*, or
*Turned off*.

**Turn off an agent's access**

Agents page → **Deactivate**. The database refuses their data straight away and
the app signs them out within an hour (at the next token refresh) or on reload.
To keep the agent record active but remove only the login:

```sql
update public.profiles set is_active = false
 where agent_id = (select id from public.agents where code = 'AG-007');
```

**Deploy the invite function** (once per project, and after changing
`supabase/functions/invite_user`)

```powershell
supabase link --project-ref <staging-ref>
supabase functions deploy invite_user
# then the same for production
```

Supabase provides `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to the
function. Only if the site moves: `supabase secrets set SITE_URL=https://…`.

**List admins**

```sql
select p.name, p.email, p.role, p.is_active, u.last_sign_in_at
  from public.profiles p join auth.users u on u.id = p.user_id
 where p.role in ('owner', 'staff') order by p.role, p.name;
```

**Move an agent's members to someone else**

Do this before deactivating an agent who is leaving, otherwise their members
have nobody collecting from them.

Agents page → the agent's **⋯** menu → **Move members** → pick the agent to
move them to. Both sides get a notification. The receiving agent must be
active, and the two agents must be different.

By hand, if the screen is unavailable:

```sql
select public.reassign_members(
  (select id from public.agents where code = 'AG-007'),   -- from
  (select id from public.agents where code = 'AG-003'));  -- to
```

It returns how many members moved. Pass a third argument — an array of member
ids — to move only some of them. Money already collected keeps the agent who
collected it, so past commission and receipts are unaffected.

**Unlock a member who is locked out of the public lookup**

Five wrong tries for one registration number inside 15 minutes lock that
number. The lock is counted per registration number, not per person or device,
so it clears itself after 15 minutes — usually the right answer is to wait.

To clear it immediately (a member on the phone to the office, for example):

```sql
delete from public.lookup_attempts
 where reg_no = 'SSY-2026-0042' and not succeeded;
```

Check first whether the tries look like a member mistyping or like someone
guessing:

```sql
select reg_no, succeeded, created_at
  from public.lookup_attempts
 where created_at > now() - interval '1 hour'
 order by created_at desc limit 50;
```

Many failures spread across different registration numbers is guessing, not a
confused member. Leave those locked and tell the trustees.

**Cash handovers** (Phase 16)

An agent declares the cash they handed to the office; an admin confirms it on
the Approvals page. Confirm only once the money is actually in hand — the
receipts stay linked to the handover and leave the agent's "cash in hand".

Rejecting one (with a reason) unlinks its receipts, so the amount goes back to
that agent's cash in hand and they can declare it again. Use that rather than
deleting anything.

**Commission**

Commission page → pick the month → **Mark paid** (owners only). Leaving the
amount as it stands pays the calculated figure. Marking a month that was
already paid corrects it instead of failing, and the agent is told either way.

The calculated figure is recomputed on every read, so cancelling an old receipt
changes what is owed for that month. The page then shows what was actually paid
next to what is now owed, rather than quietly rewriting the record — settle the
difference in the next month's payment.

---

## 3.1 Email (Brevo) — switching it on and checking it

Every email the app sends is sent by **Supabase Auth**, not by the app: the
sign-in code and the invite. Supabase hands the message to Brevo over SMTP.
The app never talks to Brevo and holds no email credentials.

```
app  →  Supabase Auth  →  Brevo SMTP  →  the person's inbox
        (templates, OTP)   (relay, 300/day free)
```

**Switch it on** (once per project — staging and production are separate):

1. Brevo → **Senders, Domains & Dedicated IPs → Senders** → add
   `rudranshct@gmail.com` and click the confirmation link Brevo emails there.
   Sending from an unverified sender fails.
2. Brevo → **SMTP & API → SMTP** → note the login (`…@smtp-brevo.com`) and
   generate an SMTP key. The key is not the API key.
3. New Brevo accounts are often held for review before they may send. Check
   the dashboard for a "pending activation" banner; if it is there, no amount
   of correct configuration will deliver anything.
4. Push the config from this repo. It carries the SMTP settings **and** both
   email templates in one go — free projects reject custom templates unless
   SMTP is pushed in the same call:
   ```powershell
   supabase link --project-ref <staging-ref>
   $env:BREVO_SMTP_USER    = "<login>@smtp-brevo.com"
   $env:BREVO_SMTP_KEY     = "<smtp key>"
   $env:BREVO_SENDER_EMAIL = "rudranshct@gmail.com"
   supabase config push
   Remove-Item Env:BREVO_SMTP_KEY
   ```
5. Confirm in Dashboard → Authentication → **Emails → SMTP Settings** that the
   host reads `smtp-relay.brevo.com`. If it is off, the push did not land.
6. Repeat for production with its own `--project-ref`.

**Until this is done**, Supabase uses its built-in mailer, which delivers only
to addresses belonging to members of the Supabase organisation and allows
about 2 emails an hour. Invites to an agent's own Gmail address simply never
arrive, with no error in the app.

**Nothing arrives — where to look, in order**

| # | Where | What it tells you |
| --- | --- | --- |
| 1 | Dashboard → **Logs → Auth logs**, filtered to the time you clicked | Decisive. Shows whether a send was attempted and what SMTP replied |
| 2 | Dashboard → **Authentication → Users** | Is the address there? If yes the account exists, so a repeat invite takes the "already exists" path and sends no email by design |
| 3 | Brevo → **Transactional → Logs** | Whether Brevo received the message, and whether it was delivered, bounced or blocked |
| 4 | The inbox's **Spam** and **Promotions** tabs | Likeliest place for a first message. There is no trust domain, so there is no SPF/DKIM for the sender and Gmail is suspicious of it |
| 5 | The agent record's email address | A typo here looks exactly like a delivery failure |

**Rate limits to keep in mind:** Brevo free is 300 emails/day. Supabase's own
`emails per hour` (Authentication → Rate Limits) can only be raised above the
default once custom SMTP is on; §1.2 sets it to 100.

**Why an invite can legitimately send no email.** If the address already has a
Supabase account, `invite_user` reuses it and returns `email_sent: false`. That
person does not need an invite — they can type their email on the login page
and get a code immediately. A genuine send failure is a **502** with the SMTP
error in the message, never a success.

---

## 4. Monitoring

- **Keep-alive** runs every 2 days. It queries both projects so free projects never
  hit the 7-day idle pause, and opens a GitHub issue when a database passes 350 MB
  (the free limit is 500 MB).
- **Nightly backup** runs at 02:00 IST and opens an issue if it fails.

Check the size by hand:

```sql
select pg_size_pretty(pg_database_size(current_database()));
select relname, pg_size_pretty(pg_total_relation_size(relid))
  from pg_catalog.pg_statio_user_tables order by pg_total_relation_size(relid) desc limit 10;
```

Who changed a record:

```sql
select created_at, action, user_id, old_data, new_data
  from public.audit_log where table_name = 'members' and row_id = '<member id>'
 order by created_at desc;
```

**Project paused?** Dashboard → project → **Restore project**. It takes a few
minutes; data is kept.

---

## 5. Restore

Monthly drill: restore last night's production backup into **staging** and
compare the counts.

```bash
aws s3 cp "s3://$R2_BUCKET/daily/rudransh-YYYY-MM-DD.tar.age" . \
  --endpoint-url "https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com"

scripts/restore_backup.sh rudransh-YYYY-MM-DD.tar.age "<staging session-pooler URL>" rudransh-backup.key
```

The script needs `psql`/`pg_restore` 17 or newer and `age`. It asks you to type
`RESTORE`, replaces all app data in the target (the target must already have
the migrations applied), and prints row counts and the paid total. Compare
those with production:

```sql
select count(*) from public.members;
select count(*), sum(amount) filter (where status = 'paid') from public.payments;
```

For a real disaster, create a new project, run `supabase db push`, and run the
same script against it. Then update the Supabase secrets and redeploy.

---

## 6. Aadhaar encryption key

The full Aadhaar number is encrypted at rest (IMPLEMENTATION_PLAN §7).
`pgcrypto` does the encryption and **Supabase Vault** holds the key.

> Not pgsodium: Supabase documents its Transparent Column Encryption but does
> not recommend it, and the extension is being deprecated. Vault keeps its API.

### Set the key, once per project

Supabase → SQL Editor. Use a long random value and use **a different one for
staging and production**:

```sql
select vault.create_secret(
  encode(extensions.gen_random_bytes(32), 'base64'),
  'aadhaar_key',
  'Encrypts members.aadhaar_enc — see docs/RUNBOOK.md section 6'
);
```

Check it is there (this prints the key, so do it in a private window):

```sql
select name, created_at from vault.decrypted_secrets where name = 'aadhaar_key';
```

**Keep a copy in the password manager.** The key is not in the repo and not in
the nightly backup's reach — lose it and every stored Aadhaar is unreadable.
Nothing else breaks: members keep working, and the last four digits survive
because they are stored separately.

### If the key is missing

The database **refuses to store an Aadhaar** rather than writing it in the
clear. Saving a member with an Aadhaar fails with a message pointing here;
saving one without an Aadhaar works normally. That is the intended behaviour.

### Who can read it

| Role | Sees |
| --- | --- |
| Owner | The full number, on demand — **Show** on the member detail sheet |
| Staff admin | `XXXX XXXX 9012`. They may *change* it, never read it |
| Agent | `XXXX XXXX 9012` |
| Member | Nothing; the public lookup only *checks* the last four digits |

Reading the number goes through `member_aadhaar(member_id)`, which is owner
only. `clear_member_aadhaar(member_id)` removes one outright, also owner only.
Neither the plain number nor the ciphertext ever reaches the audit log.

### Rotating the key

There is no rotation helper yet. Rotating means decrypting with the old key and
re-encrypting with the new one in a single transaction, so write one before you
need it — the number of members is small, but the statement must not be
interrupted:

```sql
-- Staging first. Replace <old> and <new>.
update public.members
   set aadhaar_enc = extensions.pgp_sym_encrypt(
         extensions.pgp_sym_decrypt(aadhaar_enc, '<old>'), '<new>')
 where aadhaar_enc is not null;
```

Then update the Vault secret. Take a backup first (section 5).
