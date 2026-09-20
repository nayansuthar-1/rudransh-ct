# Go-live checklist

Written 21 Sep 2026. Run these in order. Every command is meant to be pasted as
written; where a value is yours to choose it says so.

**Read section 1 before anything else.** One migration destroys data if it runs
out of order, and production holds real member records.

State when this was written:

| | staging `gyzxvtqmzrabjyexqeno` | production `escdwwlznrhdebvvcawe` |
| --- | --- | --- |
| Applied through | `20260922000100` | about `20260915000300` |
| Pending migrations | 4 | about 9 |
| Edge functions | `invite_user`, `member_lookup` both ACTIVE | not verified |
| Vault `aadhaar_key` | unknown | unknown |

The Supabase CLI on this machine is linked to **staging**. Check any time with:

```bash
supabase projects list
```

---

## 1. The one step that can destroy data

`supabase/migrations/20260924000100_aadhaar_encryption.sql` encrypts every
existing Aadhaar number. It looks for a Supabase Vault secret called
**`aadhaar_key`**.

If that key is missing, **the migration still succeeds**. It keeps only the last
four digits, blanks the column, and prints a `raise warning` that is easy to
miss in the push output. The full numbers are gone and cannot be recovered,
because no ciphertext was ever written.

So on **each project**, before pushing:

Supabase dashboard → SQL Editor → check whether the key is already there:

```sql
select name, created_at from vault.decrypted_secrets where name = 'aadhaar_key';
```

If it returns no rows, create it. **Use a different key for staging and
production**, and put both in the password manager — losing a key makes that
project's stored Aadhaar numbers unreadable for good:

```sql
select vault.create_secret(
  encode(extensions.gen_random_bytes(32), 'base64'),
  'aadhaar_key',
  'Encrypts members.aadhaar_enc — see docs/RUNBOOK.md section 6'
);
```

Run the `select ... from vault.decrypted_secrets` check again and confirm one
row comes back before moving on.

---

## 2. Staging: apply the four pending migrations

Staging writes are broken right now — the app sends `members.dob`,
`members.state` and `yojnas.start_date`, which the database does not have yet,
so saving a member or a Yojna fails. This fixes that.

```bash
cd d:/Nayan/rudransh
supabase db push --dry-run
```

Expect exactly these four, in this order:

```
20260923000100_member_certificate.sql
20260923000200_yojna_start_date.sql
20260924000100_aadhaar_encryption.sql
20260924000200_privacy.sql
```

If the list differs, stop and check the link. Otherwise:

```bash
supabase db push
```

Read the output. If you see `No Aadhaar key configured: kept only the last 4
digits`, the key from section 1 was missing — on staging that is survivable, on
production it is not.

---

## 3. Staging: verify before touching production

```bash
./scripts/run_staging.ps1
```

Sign in as the trust's own address and check each of these. They cover the
things the four migrations changed:

- [ ] **Members → Add Member** saves. This is the one that fails today; it
      exercises the new `dob` and `state` columns.
- [ ] **Edit** an existing member and save.
- [ ] **Yojna → add or edit a scheme**, including the new **Scheme start date**.
- [ ] Open a member → **Print certificate**. A new tab opens and prints.
      Confirm `योजना प्रारंभ` shows the scheme's start date, not today's.
- [ ] As owner, open a member and confirm the **full Aadhaar** is still visible
      (that is `member_aadhaar()` decrypting through the Vault key).
- [ ] Agent screens load: dues, collections, cash in hand, commission.

Do not continue until member add/edit works.

---

## 4. Production: the same, carefully

Production holds real members. Redo **section 1 against the production project**
with a *different* key, and confirm the `select` returns a row.

Then point the CLI at production:

```bash
supabase link --project-ref escdwwlznrhdebvvcawe
supabase db push --dry-run
```

This will list roughly nine migrations — production never received roles, agent
work, dues, notifications, the member portal or commission. Read the list. When
it looks right:

```bash
supabase db push
```

Watch for the Aadhaar warning. If it appears, stop and tell me: it means the key
was not set and the real numbers were just discarded.

Then the Edge Functions and the auth/email config:

```bash
supabase functions deploy invite_user
supabase functions deploy member_lookup --no-verify-jwt
supabase config push
```

Point the CLI back at staging so later work does not land on production by
accident:

```bash
supabase link --project-ref gyzxvtqmzrabjyexqeno
```

---

## 5. GitHub secrets and variables

I could not check these — the `gh` CLI is not installed on this machine — so
confirm each one in **GitHub → Settings → Secrets and variables → Actions**.

If any of the deploy secrets are missing the workflow **skips the build and
deploy entirely** rather than failing, so a push to `main` would look like it
succeeded while shipping nothing.

**Secrets:**

| Name | Value |
| --- | --- |
| `SUPABASE_URL_PROD` | `https://escdwwlznrhdebvvcawe.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY_PROD` | `sb_publishable_ZXNlVUg6WkGm2lwlGt1Jjw_v3tVwPjR` |
| `SUPABASE_URL_STAGING` | `https://gyzxvtqmzrabjyexqeno.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY_STAGING` | `sb_publishable_iv7gqnWjqE9oZud3fRpwbA_Hqxhvkhe` |
| `CLOUDFLARE_API_TOKEN` | from Cloudflare |
| `CLOUDFLARE_ACCOUNT_ID` | from Cloudflare |

The publishable keys are public by design — they ship in every browser build,
and row-level security is what actually guards the data. The **secret** and
**service_role** keys must never go in here or in the repo.

**Variables** (all public, they end up in the browser):

| Name | Value |
| --- | --- |
| `CLOUDINARY_CLOUD_NAME` | `n9mgnr8s` |
| `CLOUDINARY_UPLOAD_PRESET` | `rudransh_certificates` |
| `TURNSTILE_SITE_KEY` | from Cloudflare Turnstile |
| `UPI_ID`, `UPI_PAYEE` | optional; empty hides the UPI button |
| `CLOUDFLARE_PAGES_PROJECT` | optional, defaults to `rudransh-ct` |

---

## 6. Deploy the frontend

Only after sections 2–5. Pushing to `main` is what deploys production.

```bash
git push origin main
```

`rudransh-ct.pages.dev` did not resolve on 21 Sep 2026, so this is likely the
first real deploy — or the Pages project has a different name, set in
`CLOUDFLARE_PAGES_PROJECT`.

Watch the run in GitHub → Actions. If it logs `Deploy secrets missing; skipping
build and deploy`, go back to section 5.

---

## 7. After it is live

- [ ] Open the site, sign in, and repeat the section 3 checks against production
- [ ] Public lookup at `/lookup` — needs the Turnstile keys, or it fails closed
      with a 503 and says so
- [ ] Schedule the daily overdue-dues sweep with pg_cron (`docs/RUNBOOK.md`
      §2.1), once per project. Every other notification is a trigger and works
      on its own; this one never fires until scheduled
- [ ] Confirm the nightly backup workflow ran

---

## 8. Still outstanding, not blocking

- **`संस्था रजीस्टर नं.` on the certificate is a placeholder**
  (`F/0000/B.K., GJ/0000/B.K.`) and `संस्था स्थापना` stands in at 01-07-2026.
  Replace both in `lib/core/config/trust_info.dart` before certificates are
  handed to members. See `docs/MEMBERSHIP_CERTIFICATE_PLAN.md` §8.
- The office must type the real **scheme name**, **start date** and
  **description** (the `नोंध` line) into the Yojna screen — they are data, not
  code.
- Rotate the Cloudinary API secret exposed on 18 Sep 2026 and delete the test
  assets (`IMPLEMENTATION_PLAN` section 0, items 4 and 5).
