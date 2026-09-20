# Manual testing guide

How to walk through every built feature by hand, role by role. Written against
the code as of 20 Sep 2026 (Release 2, Phases 10-16 built and not yet deployed).

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
  --dart-define=SUPABASE_URL=https://<staging-ref>.supabase.co \
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

1. **Push the migrations to staging.** Phases 13 to 16 (`20260919000100_dues.sql`
   through `20260922000100_commission.sql`) are in the repo but not yet on any
   project (IMPLEMENTATION_PLAN section 0). Without them the dues tab, the bell,
   the member portal and the agent's cash card all error — and the Phase 16
   migration replaces `agent_summary()`, so the agent home breaks until it is
   applied.
   ```bash
   supabase link --project-ref <staging-ref>
   supabase db push
   supabase functions deploy invite_user
   supabase functions deploy member_lookup --no-verify-jwt
   ```
2. **Cloudinary defines.** Without them the agent's death-certificate upload is
   disabled and the app says so. Not a bug — check the message, then set them.
3. **Four test logins.** Create them once and keep them (docs/RUNBOOK.md §3):
   - **owner** — you; already an owner if you were an admin before the roles migration
   - **staff** — invite in Supabase → Authentication → Users, then
     `insert into public.profiles (user_id, role, name, email) select id, 'staff', 'Test Staff', email from auth.users where email = '…';`
   - **agent** — create the agent record in the app, then invite them (§4.2)
   - **member** — no invite button in the app yet; see §7
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
- Three fields on this form are printed on the membership certificate and
  nowhere else, so fill them as the trust writes them: the **scheme name** in
  Hindi, the **scheme start date** (`योजना प्रारंभ`) and the **description**,
  which becomes the `नोंध` payout line. Leaving the start date empty falls back
  to the day the record was created, which is not the same date.
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
  date of birth, village/tehsil/district/state, Aadhaar, two phone numbers.
- Search by name, reg no and phone. Filter by status, agent and district.
  Combine a filter with the top-bar Yojna scope — the list must respect both.
- Open a member's detail sheet. **As owner you see the full Aadhaar.**
- Edit a member, including nominee and Aadhaar (owner-only fields).
- Mark a member **Inactive** (owner only — staff must not be able to).
- Try to delete a member who has receipts → must be refused, with the advice to
  mark them Inactive instead.
- **Print certificate** on the detail sheet opens a new tab and the print dialog.
  Check on paper: Hindi renders with matras joined, it fits **one A4 landscape**
  page, the reg number, name, gotra, jati, date of birth, village, district,
  state, address, phone, nominee and karyakarta are all filled. The certificate
  frame is the **whole page** — nothing prints outside it. Blank dotted lines
  are expected wherever the client has not sent the trust's own details yet
  (`docs/MEMBERSHIP_CERTIFICATE_PLAN.md` §8).
- ⚠️ `संस्था रजीस्टर नं.` currently reads **`F/0000/B.K., GJ/0000/B.K.`**. That
  is a placeholder, not the trust's number. It must be replaced in `TrustInfo`
  before any certificate is handed to a member. Same for `संस्था स्थापना`,
  which stands in at 01-07-2026.
- Against the reference sheet the client supplied, check the branding: the
  **arched heading** reads रुद्रांश चेरीटेबल ट्रस्ट – लाखणी and is not clipped
  at either end, the **logo** shows with no white box around it, the three
  invocations sit across the top, गुजरात and राजस्थान flank the heading, and
  the footer carries the Lakhani office address and three phone numbers.
- In the print dialog, **Background graphics must be on**, or the border,
  the crimson slogan bar and the corner flourishes are dropped.

To look at the design without starting the app:

```bash
flutter test tool/certificate_preview/preview_test.dart
```

That writes `build/certificate_preview.html` with the fonts and logo inlined,
so it renders correctly opened straight off the disk. It uses made-up data and
does not print itself; the real page loads its assets from the app.

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
- The bell in the top bar opens **Approvals**. Six sections: new members,
  payments to approve, death reports, cancel requests, cash handovers and
  corrections.
- Approve an agent's member → a reg number is issued at that moment, and the
  member turns Active.
- Reject one with a reason → the member stays **Inactive with no reg number**,
  and money already recorded against them keeps its member.
- Approve an agent payment → it gets counted in the dashboard and agent totals.
- **Create closing** from a death report: set the group and claim amount, or
  reject with a reason.
- **Confirm received** on a cash handover, or reject it with a reason. A
  rejected handover puts the money straight back into that agent's cash in hand
  — check the agent's Collections page afterwards.

### 4.6a Commission (owner)
- **Commission** in the sidebar, one month at a time. The month switcher does
  not go past the current month.
- Every active agent is listed, even one who collected nothing.
- Check the numbers by hand for one agent: approved, uncancelled registration
  and contribution receipts dated in that month, times their percentage. A
  cancelled receipt and a claim payout must **not** count.
- **Mark paid** — leaving the amount as it is pays the calculated commission.
  Mark the same month again with a different amount: it corrects rather than
  fails, and the row then shows what was actually paid.
- Sign in as **staff** and open the page: the numbers are there, the Mark paid
  button is not.

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
The point of this pass is what staff **cannot** do. The table below is the
agreed permission set from IMPLEMENTATION_PLAN §11.3, i.e. what *should*
happen. Access is enforced in the database first, so a gap here is usually a
screen that still shows a button the database will refuse — worth reporting,
but not the same class of bug as data actually changing.

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
- Members, amount waiting for approval, approved this month, cash in hand and
  this month's commission. All five should read zero for a brand-new agent.
- Once there are closing groups, the three newest appear below the buttons with
  the amount still to collect; tapping one opens that group's dues.

### 6.2 My Members
- Only this agent's members. Confirm a member belonging to the other agent is
  **not** listed and cannot be opened.
- **Add member** → saves as **Pending approval**, with no reg number. Check it
  lands in the owner's Approvals queue.
- **Edit contact** → phones, address and state only. Name, date of birth,
  Aadhaar, nominee and Yojna must not be editable. Aadhaar should never be
  visible to an agent.
- **Print certificate** on an approved member prints the same sheet with this
  agent's name as the karyakarta. On a member still waiting for approval the
  button is hidden — there is no reg number to print yet.

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

### 6.6a Cash in hand and commission
- The card at the top of Collections counts only **approved cash** receipts
  that are not in a handover yet. Record a cash payment and leave it pending:
  the figure must not move until the office approves it. A UPI receipt must
  never appear there at all.
- **Hand over cash** → everything is ticked to start with. Untick a receipt and
  the total follows. Declare it: cash in hand drops, "waiting to be confirmed"
  rises, and the handover shows in the office's Approvals queue.
- Ask the office to reject it. The agent gets a bell notice with the reason, and
  the money is back in cash in hand.
- Ask the office to confirm the next one. The agent gets a bell notice and the
  money stays out.
- **My commission** lists the last six months with what was collected, the
  percentage and whether the office has paid it.

### 6.7 Access
- Type `/dashboard` or `/members` into the address bar as an agent → you must be
  bounced back to `/agent`.
- Ask the API directly for another agent's members. Must come back empty or
  refused, not filtered in the browser.

---

## 7. Member — the portal (Phase 15)

The portal is built, and so is the Turnstile widget on the web build. What is
still missing is the **keys**: set them and run
`supabase functions deploy member_lookup --no-verify-jwt`
(IMPLEMENTATION_PLAN section 0, item 8). Until then `/lookup` **fails closed**
and says so — that is the designed behaviour, not a bug.

With the keys set, check on a real browser that the Cloudflare checkbox appears
on `/lookup` and that **Check** stays greyed out until it is ticked. This is the
one part of the portal no test covers: the widget needs a real site key and a
real browser.

| Screen | What to check |
| --- | --- |
| `/lookup`, signed out | reg no + phone + last 4 of Aadhaar returns a summary only — no Aadhaar, no address, no agent. Five wrong tries lock that number for 15 minutes |
| `/me` home | the member's own membership |
| `/me/dues` | what they owe, and their family's closing case if there is one |
| `/me/payments` | their receipts; **Pay by UPI** needs the `UPI_ID` / `UPI_PAYEE` variables, and the same UTR twice must be refused |
| `/me/announcements` | only notices that apply to them |
| Corrections | one pending change per field; it lands in the office's Approvals queue and the member hears the outcome |

There is **no invite-a-member button** in the app. To get a member login for
testing you have to call the edge function yourself:

```bash
curl -X POST https://<staging-ref>.supabase.co/functions/v1/invite_user \
  -H "Authorization: Bearer <owner access token>" \
  -H "Content-Type: application/json" \
  -d '{"role":"member","email":"test.member@example.com","member_id":"<members.id>"}'
```

Also check the access rules: the member lands on `/me` and not on `/dashboard`,
sees only their own announcements, cannot see another member's record, and is
bounced out of `/agent` and `/members`.

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

### What the test suite already covers

Do not spend a session by hand on these — they run in CI on every push, and
repeating them wastes the time better spent on the real database:

| Check | Where |
| --- | --- |
| Every role against every table and RPC, through the API | `test/integration/role_api_test.dart` |
| Agent and member pages at 390 / 768 / 1440 px, both themes, Hindi names | `test/role_layout_test.dart` |
| Admin pages at 8 widths, both themes | `test/responsive_test.dart` |
| Two agents + an admin saving at once | `supabase/tests/concurrent_roles_test.sh` |
| Four sessions hammering the counter | `supabase/tests/concurrent_numbering_test.sh` |

What is left for a person is everything the tests cannot reach: real email
delivery, the Turnstile checkbox, WhatsApp opening on a real phone, Hindi on
paper and on an Android screen, and whether the day's work actually makes
sense to the office.

---

## 9. What to write down

For each issue: the role, the screen, the width, what you did, what you
expected, what happened. A screenshot of the browser console helps — most
database refusals surface there with the real error.
