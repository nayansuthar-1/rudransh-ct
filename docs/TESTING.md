# Manual testing guide

How to walk through every built feature by hand, role by role. Written against
the code as of 18 Sep 2026 (Release 2, Phase 14 in progress).

---

## 1. Where to test

| | Demo build (no Supabase defines) | Staging Supabase |
| --- | --- | --- |
| Login | bypassed | real email OTP |
| Role | fixed at build time by `DEMO_ROLE` | comes from `public.profiles` |
| Data | in memory, **gone on every reload** | real, survives |
| Access rules | not enforced | enforced by the database |

**Test on staging.** The demo build cannot test roles honestly: the role is a
build-time flag, nothing is enforced, and a page refresh throws your data away.
It is only useful for a quick look at layout, dark mode and the 390 px phone
width.

```bash
# Staging, locally
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://gyzxvtqmzrabjyexqeno.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=CLOUDINARY_CLOUD_NAME=n9mgnr8s \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=rudransh_certificates

# Demo build, layout only
flutter run -d chrome                        # opens as owner
flutter run -d chrome --dart-define=DEMO_ROLE=staff
```

Everything starts empty now — the app ships no sample records. To empty a
Supabase project too, run [`scripts/reset_data.sql`](../scripts/reset_data.sql)
(**staging only**; it is not reversible).

---

## 2. Before the first run

1. **Push the migrations to staging.** Phase 14 (`20260920000100_notifications.sql`)
   and Phase 13 (`20260919000100_dues.sql`) are in the repo; check they are on
   the project, or the bell and the dues tab will error.
   ```bash
   supabase link --project-ref gyzxvtqmzrabjyexqeno
   supabase db push
   supabase functions deploy invite_user
   ```
2. **Cloudinary defines.** Without them the agent's death-certificate upload is
   disabled and the app says so. Not a bug — check the message, then set them.
3. **Four test logins.** Create them once and keep them (docs/RUNBOOK.md §3):
   - **owner** — you; already an owner if you were an admin before the roles migration
   - **staff** — invite in Supabase → Authentication → Users, then
     `insert into public.profiles (user_id, role, name, email) select id, 'staff', 'Test Staff', email from auth.users where email = '…';`
   - **agent** — created from inside the app (see §5, step 1)
   - **member** — no UI for this yet; see §6
4. Use four browser profiles or windows, one per role. Signing in as another
   role in the same window replaces the session.

Each invited person must click **Activate account** in the invite email once
before a 6-digit code will ever be sent to them.

---

## 3. Build the data in this order

An empty database means some screens can only be tested after earlier ones.
Follow this order the first time:

```
Yojna → Agent → Member → Payment → Closing case → Dues → Approvals
```

You need at least **2 Yojnas** and **2 agents** to test scoping and filters
properly, and **5–6 members** to make dues and closing groups interesting.

---

## 4. Owner (trustee) — full access

Sign in as the owner. You land on `/dashboard`.

### 4.1 Yojna
- **Yojna** → create a scheme. Set contribution, claim and registration amounts.
  These three numbers drive every later calculation, so write down what you set.
- Create a second scheme so the **Yojna scope selector** in the top bar has
  something to switch between.
- Edit a scheme; confirm the change shows on the cards.
- Try to delete a scheme that has members → must be refused with a message.
  Delete an empty one → works.

### 4.2 Agents
- **Agents** → Add agent. Leave the code blank: the database assigns `AG-001`.
  The form only shows a preview.
- Give one agent an email address — you need it for the invite.
- Set a commission percent and pick which Yojnas the agent works on.
- **⋯ → Invite to app** (owners only; the menu item should not appear for
  staff). The agent's details then show **App access: Invited**.
- **⋯ → Move members** — test it after you have members: pick a target agent,
  confirm every member moves and the member counts on both rows update.
- **Deactivate** an agent → their login stops working (they are signed out on
  reload or within the hour).

### 4.3 Members
- **Members** → Add Member. Reg number is assigned by the database on save.
- Check the Hinglish fields are all there: Jati, Gotra, Waris name and relation,
  village/tehsil/district, Aadhaar, two phone numbers.
- Search by name, reg no and phone. Filter by status, agent and district.
  Combine a filter with the top-bar Yojna scope — the list must respect both.
- Open a member's detail sheet. **As owner you see the full Aadhaar.**
- Edit a member, including nominee and Aadhaar (owner-only fields).
- Mark a member **Inactive** (owner only — staff must not be able to).
- Try to delete a member who has receipts → must be refused, with the advice to
  mark them Inactive instead.

### 4.4 Payments
- **Add Payment** from the top bar. Pick a member; the Yojna and amount should
  follow from the scheme. Save as **Paid**.
- Receipt number comes from the database.
- Record both a **registration** payment and a **contribution**.
- **Payments** page: filter by date range, mode, type and status. Check the
  totals change with the filters.
- **Cancel receipt** (owner only) with a reason. The receipt stays listed,
  marked Cancelled, and **leaves every total** — check the dashboard tile and
  the agent's collection figure both drop.

### 4.5 Closing payments
- **Closing Payments** → raise a claim for a member. Set a closing group label
  (e.g. `Group-1`) — dues are calculated per group, so this label matters.
- Watch collected vs pending as contributions linked to that closing come in.
- **Mark settled / paid** — owner only; staff must not see it.

### 4.6 Approvals
- The bell in the top bar opens **Approvals**. Three sections: new members,
  payments to approve, cancel requests.
- Approve an agent's member → a reg number is issued at that moment, and the
  member turns Active.
- Reject one with a reason → the member stays **Inactive with no reg number**,
  and money already recorded against them keeps its member.
- Approve an agent payment → it gets counted in the dashboard and agent totals.
- **Create closing** from a death report: set the group and claim amount, or
  reject with a reason.

### 4.7 Announcements and the bell
- **Announcements** → post one for every Yojna, and one scoped to a single
  Yojna. Check an agent only sees the ones that apply to them.
- The bell should show an unread count and clear with **Mark all read**.
- Notifications are written by database triggers, so they only appear if
  `20260920000100_notifications.sql` is on the project.

### 4.8 Dashboard
Do this last, once there is data. Check each tile against what you entered:
total members, closing members, agents, this month's collection, members by
Yojna, top agents, recent payments, closed cases. **Pending payments and
pending members must not be counted** — only Paid and Active.

---

## 5. Staff admin — daily work, no deletes

Sign in as staff. Same screens as the owner, minus the owner-only powers.
The point of this pass is what staff **cannot** do:

| Check | Expected |
| --- | --- |
| Yojna page | view only — no create, edit or delete |
| Agents page | view only — no add, no **Invite to app**, no commission change |
| Member's Aadhaar | **masked** |
| Mark member inactive | not available |
| Cancel a receipt | only **request** a cancel; an owner approves it |
| Mark a closing payout paid | not available |
| Audit log | not available |
| Add member, add payment, approve agent submissions, post announcements | all work |

Then try the same things **through the API, not the UI** — this is the part the
screens cannot prove. From the browser console on a staff session, or with
`curl` and the staff token, attempt `delete` on `yojnas` and `update` on
`agents`. Both must be refused by row-level security. `supabase/tests/roles_test.sql`
covers this in CI, but check it once by hand on staging before launch.

---

## 6. Agent — their own members only

Invite an agent from the Agents page, accept the email, sign in. You land on
`/agent` with its own five-section shell.

### 6.1 Home
- Members, amount waiting for approval, approved this month. All three should
  read zero for a brand-new agent.

### 6.2 My Members
- Only this agent's members. Confirm a member belonging to the other agent is
  **not** listed and cannot be opened.
- **Add member** → saves as **Pending approval**, with no reg number. Check it
  lands in the owner's Approvals queue.
- **Edit contact** → phones and address only. Name, Aadhaar, nominee and Yojna
  must not be editable. Aadhaar should never be visible to an agent.

### 6.3 Record payment
- Before the member is approved, only the **registration fee** can be recorded.
- The receipt gets its number immediately (the agent hands it over on the spot),
  but the payment is **Pending** and counts in no total until an admin approves.
- **Send receipt** opens WhatsApp with a Hindi message. Check `wa.me` opens with
  the right number and text. A member with no valid phone → clear error.
- **Request cancel** on a receipt → appears in the admin's cancel-request list.

### 6.4 Dues
- Needs a closing case with a group label to exist. The tab lists closing groups
  with a paid count and an amount still to collect.
- Open a group: members still due, waiting for approval, and paid.
- **Collect** records a contribution linked to that closing.
- **Send reminder** opens WhatsApp with the Hindi dues message.
- Try to collect twice for the same group as an agent → must be refused. The
  office form allows it (that is deliberate, for corrections).
- Sanity-check the list by hand: a member owes for a group when they are Active
  and joined **before** the group's first closing date. Cases with no group
  label raise no dues.

### 6.5 Report a death
- From a member's details → **Report death**: date of death plus a certificate.
- Upload a JPG, a PNG and a PDF (up to 10 MB) — all three should go to
  Cloudinary. A `.txt` must be refused.
- The outcome (closing created, or rejected with a reason) shows back on the
  Dues tab.

### 6.6 Collections
- Receipts this agent issued, with their approval state.

### 6.7 Access
- Type `/dashboard` or `/members` into the address bar as an agent → you must be
  bounced back to `/agent`.
- Ask the API directly for another agent's members. Must come back empty or
  refused, not filtered in the browser.

---

## 7. Member — mostly not built yet

Be clear about this before you spend time on it: **Phase 15 is not built.**
What exists today is the shell, the home page and announcements.

| Screen | State |
| --- | --- |
| `/me` home | built — greeting and section links |
| `/me/payments` | **placeholder** ("being prepared") |
| `/me/announcements` | built |
| `/lookup` (reg no + phone + last 4 of Aadhaar) | not built |
| UPI payment with UTR | not built |
| Change requests | table exists, no screen |

There is also **no invite-a-member button** in the app. To get a member login
for testing you have to call the edge function yourself:

```bash
curl -X POST https://gyzxvtqmzrabjyexqeno.supabase.co/functions/v1/invite_user \
  -H "Authorization: Bearer <owner access token>" \
  -H "Content-Type: application/json" \
  -d '{"role":"member","email":"test.member@example.com","member_id":"<members.id>"}'
```

What is worth testing today: the member lands on `/me` and not on `/dashboard`,
sees only their own announcements, and is bounced out of `/agent` and `/members`.

---

## 8. Cross-cutting checks

Run these for each role, at least once:

- **390 px phone width.** Drawer navigation, single-column forms, tables become
  cards. The agent shell matters most here — agents work on phones.
- **1024 px** (sidebar starts as an icon rail) and **1440 px** (full columns).
- **Dark mode** via the top-bar toggle, on every page.
- **Reload on a deep link** — e.g. refresh on `/agent/dues`. The session must
  survive and the role check must not flash the wrong screen.
- **Two people at once.** Two browsers adding members at the same second must
  get different reg numbers. Same for receipts. This is the one bug that would
  be expensive to find after launch.
- **Empty states.** With no data at all, every page should say something useful
  rather than show a broken table.
- **Hindi text** in WhatsApp messages and the invite email renders correctly.

---

## 9. What to write down

For each issue: the role, the screen, the width, what you did, what you
expected, what happened. A screenshot of the browser console helps — most
database refusals surface there with the real error.
