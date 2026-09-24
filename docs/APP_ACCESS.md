# App access for agents and members

Status on 25 Sep 2026: what each role gets today, what was broken with invites, and ideas for separating the apps.

## 1. Why "Invite to app" gave people nothing (fixed 25 Sep)

There were two separate problems.

**Members.** The invite created a Supabase login that stays *unconfirmed* until the person clicks **Activate account** in the email. This project has sign-ups switched off, and Supabase will not send a 6-digit code to an unconfirmed login. So a member who typed their email on the login page instead of clicking the link got *"This email does not have access"*. The link also expires after 24 hours, and mail scanners (Gmail, Outlook) sometimes open it first and use it up.

Fix:
- `invite_user` confirms the login as soon as it is created. The member can sign in with email + code straight away, whether or not they open the email.
- `member_sign_in` confirms any login already stuck in that state the next time that person asks for a code. Members invited before the fix do **not** need a new invite.
- The invite email (`supabase/templates/invite.html`) is now a welcome note. It has an **Open the app** button that goes to the login page, plus the three sign-in steps in English and Hindi. It no longer has a one-time link that can expire.

**Agents.** Agents have logins and their own screens, but by the client decision of 24 Sep they are signed out straight away until Release 2. Inviting an agent therefore sent an email for an app they could not use. **Invite to app** is now hidden on the Agents page until `AuthController.agentsMaySignIn` is set to `true`. That one flag switches agents on everywhere.

### To put the fix live

1. Deploy the two functions:
   ```sh
   supabase functions deploy invite_user
   supabase functions deploy member_sign_in --no-verify-jwt
   ```
2. Update the invite email template, using one of these:
   - **Dashboard:** Authentication → Emails → *Invite user*. Paste the contents of `supabase/templates/invite.html`. Subject: `Your Rudransh CT app invite`.
   - **CLI:** `supabase config push`, with `BREVO_SMTP_USER`, `BREVO_SMTP_KEY` and `BREVO_SENDER_EMAIL` set in the shell. Without them the SMTP password is pushed empty and every email stops.
3. Push to `main` so Vercel deploys the app changes: the hidden agent invite and the separate login pages.

`config.toml` now has `site_url` set to `https://rudransh-green.vercel.app`, matching prod. Before this change, a `config push` would have switched prod back to the dead `pages.dev` address.

## 2. What exists today

There is one web app at one address, `rudransh-green.vercel.app`. Since 25 Sep, each role has its own login page:

| Login page | For | Refuses |
|---|---|---|
| `/m` (the bare address opens it too) | Members. Hindi first, with the English switch, and a link to the phone + Aadhaar lookup | The office email (no code is sent), agents |
| `/a` | Agents. Says "not open yet" until `agentsMaySignIn` is on | Everyone until then; after that, members and the office |
| `/login` | The trust office | Every email except the office's, before any code is sent |

Nothing a member can reach links to `/login`. The lookup page and the "page not found" screen both lead to `/m`. A signed-out visit to a member screen goes to `/m`, to an agent screen goes to `/a`, and to an office screen goes to `/login`. The invite email's button opens the invited person's own page. The browser tab and the installed app are called "Rudransh CT", without "Admin Panel".

After sign-in, the login's role decides which screens open:

| Role | Lands on | Screens | Can sign in today? |
|---|---|---|---|
| Office (owner) | `/dashboard` | Dashboard, Members, Agents, Yojna, Closing, Payments, Approvals, Commission, Announcements | Yes, `rudranshct@gmail.com` only |
| Staff | `/dashboard` | Same as office, fewer actions | No, waits for Release 2 |
| Agent | `/agent` | Home, My members, Dues, Collections, Announcements | No, waits for Release 2 |
| Member | `/me` | Home, My dues, My payments (receipts, certificate, pay online), Announcements (Hindi/English switch) | Yes, by invite or by the email on their record |
| Anyone | `/lookup` | Receipts and certificate by phone + Aadhaar last 4 | No login needed |

What is already enforced:
- A member cannot open `/dashboard` or `/agent/...`. An agent cannot open `/me` or the office pages. The office cannot open the member or agent screens. A wrong address sends the person back to their own home (`RoleRoutes.canOpen`).
- The database is the real guard. Agents and members get no direct table access. They read only through RPCs that filter to *their own* records and hide Aadhaar. Even a doctored app could not show a member another member's data.

What is **not** separate yet:
- The app can be installed from Chrome ("Add to Home screen"), but everyone gets the same "Rudransh CT" app, and it opens at the address it was installed from. There is no member or agent app of its own, and nothing in the Play Store.
- `/login` is not secret: someone who types it sees the office page. It sends no code to anyone but the office, though.

## 3. Ideas, cheapest first

All of these stay on the free tier.

### A. Separate login pages per role: done 25 Sep (see §2)

### B. Separate installable apps (about 2 days, builds on A)
- Give each login page its own manifest, so it installs as **"Rudransh Member"** or **"Rudransh Agent"** with its own icon and start page.
- Add an **Install app** button on the member and agent login pages. It works on Android Chrome and desktop, and on iPhone through Share → Add to Home Screen.
- No store fees, and every update reaches everyone as soon as it is deployed.

### C. Separate web addresses (about 1 day, the strongest separation without a domain)
- Build the same code three ways (`APP_FLAVOR=admin|member|agent`), for example `rudransh-green.vercel.app` for the office and `rudransh-member.vercel.app` for members. Vercel's free plan allows this.
- The member build does not contain the office screens at all, so a member cannot find the admin login even by typing addresses.
- The office address is never shared outside the trust.

### D. A real Android app (optional, later)
- Flutter can build an Android APK from the same code. The office can share the APK directly for free (people must allow installs from unknown sources).
- The Play Store costs a one-time US $25 for the developer account. An iPhone App Store app costs US $99 a year. The PWA from idea B covers iPhones for free.

### E. Smaller polish
- Add a **Resend invite** action for people who lost the email. It would resend the welcome note without creating a second login.
- Show "Invited on …" and "Last signed in …" under **App access** in member and agent details.
- Add **Switch agents on** as an owner setting in the app, instead of the code flag, once Release 2 is ready.

**Recommendation:** A is done. B is next: members and agents each get their own installable app for about 2 days of work, with no new services. Add C if the office wants the admin panel's address kept private.
