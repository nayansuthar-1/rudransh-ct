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

The publishable key is safe in the browser: row-level security allows nothing
unless the signed-in user has an active profile in `public.profiles`. Never put the secret or
service-role key in the app or in `--dart-define`.

---

## 2. Deploying

| Action | Result |
| --- | --- |
| Pull request | Migrations checked, `flutter analyze` + `flutter test`, preview built against **staging** and its URL posted on the PR |
| Merge to `main` | Same checks, then deploy to **production** |
| Bad release | Cloudflare Pages → Deployments → pick the previous one → **Rollback** |

Database changes: add a new file in `supabase/migrations/` (never edit an applied
one), merge, then `supabase db push` to staging, test, and push to prod.

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
