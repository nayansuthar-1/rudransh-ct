# Delivery checklist — 26 Sep 2026

What is left before the trust takes over Rudransh CT, in the order to do it.
Checked on 25 Sep 2026 against production (`escdwwlznrhdebvvcawe`):

- All 21 migrations applied; all 6 Edge Functions active and deployed after the last code change
- `rudransh-green.vercel.app` built from the latest commit
- `flutter analyze` clean; `flutter test` 238 passed
- Vault `aadhaar_key` present on production
- **Nightly backup has failed every night since 18 Sep** (open issues on
  GitHub, one per night): the repository secrets it needs were never added.
  Fixed in §2 below; it is the one item that must not slip past launch

So nothing is left to *build*. What remains is data only the trust has,
switches in the dashboards, and the handover itself.

---

## 1. Get from the trust (needed before any certificate is printed)

| What | Goes in | Today it prints |
| --- | --- | --- |
| Registration number(s) | `TrustInfo.registrationNo` in `lib/core/config/trust_info.dart` | `F/0000/B.K., GJ/0000/B.K.` (placeholder) |
| Establishment date (DD-MM-YYYY) | `TrustInfo.establishedOn` | `01-07-2026` (stand-in) |
| President's signature, PNG on a white or clear background | `assets/brand/signature.png`, then `TrustInfo.signatureAsset = 'assets/brand/signature.png'` | nothing on the receipt |
| Each Yojna's name, start date and description | Typed by the office on the **Yojna** screen | whatever was entered |

After the code edits: `flutter test`, commit, `git push origin main`. Vercel
redeploys on its own in a few minutes.

## 2. Production dashboard checks

- [ ] **Members who lost their full Aadhaar on 24 Sep.** Supabase → SQL
      editor:
      ```sql
      select reg_no, name from members
      where aadhaar_last4 <> '' and aadhaar_enc is null;
      ```
      Re-enter each one's Aadhaar from the paper form (open the member → Edit).
      An empty result means nobody was affected.
- [ ] **Invite email.** Supabase → Authentication → Emails → *Invite user*.
      Body must match `supabase/templates/invite.html`, subject
      `Your Rudransh CT app invite`. The old template has a one-time link that
      expires.
- [ ] **Backups and keep-alive (failing today).** Only two GitHub secrets
      are needed now; R2 is optional (`docs/RUNBOOK.md` §1.4):
      1. `winget install FiloSottile.age`, then `age-keygen -o rudransh-backup.key`.
         The private key file goes in the password manager; the printed
         `age1…` line is the secret **`AGE_RECIPIENT`**.
      2. Supabase → production → **Connect** → **Session pooler** URI, with
         the database password filled in → secret **`SUPABASE_DB_URL_PROD`**.
      3. GitHub → Settings → Secrets and variables → Actions → add both.
      4. Actions → **Nightly backup** → Run workflow → green, with one
         artifact. Actions → **Keep-alive & size check** → Run workflow →
         green, and the summary shows the member count.
      5. Close the old "Nightly backup failed" issues.

## 3. Test the live site

On `rudransh-green.vercel.app`, on a phone and a laptop:

- [ ] `/login` as the office: add a member, edit them, record a payment,
      print the receipt, print the certificate (check the values from step 1)
- [ ] Members → **Invite to app** for a real member email; that member signs
      in at `/m` with the emailed code and sees their dues and receipts
- [ ] `/lookup` with that member's phone + last 4 Aadhaar digits: receipts and
      certificate open
- [ ] Members and Payments → **Export CSV** downloads
- [ ] Delete or mark any test member/payment made during this check

## 4. Handover

- [ ] Every account owned by the trust's email (`rudranshct@gmail.com`), you
      added as a member: Supabase, Vercel, GitHub, Cloudinary, Brevo,
      Cloudflare (Turnstile)
- [ ] Credentials in a password manager, **including the Vault
      `aadhaar_key`** — if it is lost, stored Aadhaar numbers can never be read
      again
- [ ] Give them `docs/GUIDE.md` (office), `docs/MEMBER_GUIDE_HI.md`
      (members), `docs/RUNBOOK.md` (admin tasks, restore, deploy)
- [ ] Training for the office: add member, payment + receipt, certificate,
      invite, lookup, export
- [ ] Written sign-off on scope, and the support window's start and end dates

### Message to send with the link

> The Rudransh CT app is live at **https://rudransh-green.vercel.app**
>
> - Office: open `/login`, enter the trust email, type the 6-digit code from the email.
> - Members: open the site (or `/m`) and sign in with the email the office saved for them.
> - Anyone can check a membership at `/lookup` with their phone number and the last 4 digits of their Aadhaar.
>
> Guides are attached. Agents get their own login in November.

---

## 5. After delivery (not blocking)

| Item | When | How |
| --- | --- | --- |
| Razorpay online payments | After the trust's Razorpay KYC is approved | Supabase function secrets `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`; Vercel env `RAZORPAY_KEY_ID`; Razorpay webhook → the `razorpay_webhook` function URL; redeploy |
| Pay by UPI button | When the trust gives a UPI ID | Vercel env `UPI_ID`, `UPI_PAYEE`; redeploy |
| Agents (Release 2) | 6 Oct – 5 Nov | Vercel env `AGENTS_MAY_SIGN_IN` = `true`, redeploy (no code change); enable pg_cron and schedule the overdue-dues sweep (`docs/RUNBOOK.md` §2.1) |
| Cloudinary clean-up | Any time | Rotate the API secret exposed on 18 Sep; delete the test files in `rudransh/certificates` |
