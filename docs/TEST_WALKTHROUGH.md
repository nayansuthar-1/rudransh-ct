# Testing all three dashboards, start to finish

Written 25 Sep 2026, for the live site `rudransh-green.vercel.app`. Follow it top to bottom: the office creates the data, the member uses it, the office approves what the member sent, and then the agent side.

Most sections end with **✅ Pass if**. When a check fails, write down the role, the page address, what you did, what you expected and what happened, and take a screenshot.

For more detail on any single screen, see [TESTING.md](TESTING.md). Parts of that older guide are out of date: there is no "Activate account" step any more, members can be invited from the app, and `DEMO_ROLE` no longer does anything.

---

## 0. Before you start (10 minutes)

### 0.1 Check that the latest version is live
- [ ] **Vercel:** the latest deployment is from your last push. Open `rudransh-green.vercel.app/m`: you should see **सदस्य लॉगिन**, not the office sign-in.
- [x] **Supabase functions:** `invite_user` (v4) and `member_sign_in` (v2) were redeployed on 25 Sep at 01:02 IST, after the fix was committed. Nothing to do.
- [ ] **Invite email template:** Supabase Dashboard → Authentication → Emails → **Invite user** must contain the text of `supabase/templates/invite.html`. You will see in step 2.3 whether it does: the email must say **Open the app / ऐप खोलें**, not "Activate account".

### 0.2 One inbox for every role
Gmail delivers `name+anything@gmail.com` to `name@gmail.com`, and the app treats each one as a different person. So all the codes arrive in the trust's one inbox:

| Role | Email to use |
|---|---|
| Office | `rudranshct@gmail.com` (the only office login) |
| Member 1 (signs in with the email on their record) | `rudranshct+m1@gmail.com` |
| Member 2 (invited from the app) | `rudranshct+m2@gmail.com` |
| Agent | `rudranshct+agent@gmail.com` |

### 0.3 One browser window per role
Signing in to a second role in the same window replaces the first sign-in. Use:
- **Office:** normal Chrome window
- **Member:** Chrome **Incognito** window
- **Agent:** Microsoft Edge, or a second Chrome profile

### 0.4 Test data on the live site
Launch is 5 Oct and the live database is still empty, so testing there is fine. Keep all test records under one Yojna named **TEST**. Every test record uses up a reg number and a receipt number. To start numbering from 1 at launch, wipe the data before 5 Oct (see §8).

### 0.5 Agents sign in on the live site
Since 25 Sep, agents sign in on **`/login`** (the same page as the office) or on their own page **`/a`**, and they land on the agent panel. The office invites them from the Agents page (§2.2). To switch agent sign-in off again, set the Vercel environment variable `AGENTS_MAY_SIGN_IN` to `false` and redeploy.

---

## 1. Office: sign in and check the separation (window 1)

1. Open `rudransh-green.vercel.app` → you land on **सदस्य लॉगिन** (the member page). This is right: the bare address is what members are given.
2. Open `rudransh-green.vercel.app/login` → **Sign in**, *Rudransh Charitable Trust · Trust office and agents*, with the trust logo above it. **Bookmark this address.**
3. Type `rudranshct@gmail.com` → Send OTP → enter the 6-digit code → **Verify**.
   ✅ Pass if you land on `/dashboard`.
4. Check the browser tab: it says **Rudransh CT**, and the tab icon is the trust logo (not the blue Flutter mark). The sidebar and top bar show the logo, not an "R".
5. A member's login is refused here, but only after the code (the page can't tell a member from an agent until then). Check this in §3.2, once M1 exists: on `/login`, M1's code must end with *"This sign-in is for the trust office and agents. Members: use the member login."*

## 2. Office: build the test data

Do these in order, because each one needs the one before it.

### 2.1 Yojna
- **Yojna → Add:** name **TEST**, with contribution, claim and registration amounts (for example ₹100 / ₹50,000 / ₹500). Write the amounts down.
- ✅ Pass if the TEST card appears, and the Yojna switcher in the top bar lists it.

### 2.2 Agent
- **Agents → Add agent:** name *Test Agent*, email `rudranshct+agent@gmail.com`, commission 10%, Yojna TEST. Leave the code blank.
- ✅ Pass if the code is filled in as `AG-001` (or the next free number).
- ⋯ menu → **Invite to app** → `rudranshct+agent@gmail.com` → **Send invite**. ✅ Pass if it says *"Invite email sent"*, and the email's **Open the app** button opens `…/a`.

### 2.3 Members
Add three members under Yojna TEST, all with agent *Test Agent*:

| Member | Email on the form | Phone | Aadhaar | Used for |
|---|---|---|---|---|
| **M1** | `rudranshct+m1@gmail.com` | any 10 digits | any 12 digits | signing in with their own email (§3.2) |
| **M2** | leave empty | different phone | different Aadhaar | invited from the app (§3.3) |
| **M3** | leave empty | different phone | different Aadhaar | lookup with no login (§3.1) |

- ✅ Pass if each member gets a reg number on save and shows as **Active**.
- Open M1 → **Print certificate** → a new tab opens with an A4 landscape certificate. Turn **Background graphics** on in the print dialog.
- **Invite M2:** Members → M2 ⋯ → **Invite to app** → `rudranshct+m2@gmail.com` → **Send invite**.
  - ✅ Pass if it shows *"Invite email sent"* and M2's **App access** shows as invited.
  - Open the email in the inbox. ✅ Pass if it has the three sign-in steps in English and Hindi, and an **Open the app / ऐप खोलें** button that opens `…/m`. If it says **Activate account**, the template from §0.1 was not updated. Signing in still works, but fix the template.
- **Export CSV** on the Members page downloads a file with the three members.

### 2.4 Payments
- Top bar → **Add Payment**: M1, **registration**, cash, Paid. Then M1, **contribution**, UPI, Paid, with any UTR.
- Add a registration payment for M3 as well.
- ✅ Pass if each gets a receipt number, and the **Payments** page filters and totals change as you filter.
- **Export CSV** on Payments downloads them.

### 2.5 A closing, so there are dues
- **Closing Payments → raise a claim** for a member of TEST. For the test, use M3, or add a fourth member. Set the closing group to `Group-1`.
- ✅ Pass if the other active TEST members now owe one contribution each for Group-1. You'll see this on the member's Dues page and the agent's Dues page.

### 2.6 Announcement
- **Announcements:** post one for **all Yojnas** and one for **TEST** only.

### 2.7 Dashboard
- ✅ Pass if the tiles match what you entered: members, agents, this month's collection, recent payments. Anything pending must **not** be counted.

---

## 3. Member (Incognito window)

### 3.1 No login: the phone lookup (M3)
1. Open `rudransh-green.vercel.app` → member page → **ईमेल नहीं है? मोबाइल नंबर से सदस्यता जाँचें** (No email? Check your membership by phone).
2. Enter M3's phone and the **last 4 digits** of the Aadhaar → tick the Cloudflare box → **Check**.
   - ✅ Pass if M3's membership shows with receipts and the certificate to print, and no full Aadhaar, no address and no agent are shown.
   - Wrong digits five times → that number is locked for 15 minutes.
3. At the bottom, the link goes to the **member login** (`/m`), never to the office's.

### 3.2 Sign in with the email on record (M1)
1. `rudransh-green.vercel.app/m` → the page is in **Hindi**. The **English** button switches it, and the choice is remembered in this browser.
2. Type `rudranshct@gmail.com` (the office's email) → **कोड भेजें** (Send code).
   ✅ Pass if it says *"इस ईमेल से सदस्य लॉगिन नहीं है…"* (this email has no member login) and **no code arrives**. The member page must never let the office in.
3. Type `rudranshct+m1@gmail.com` → **कोड भेजें** → enter the code from the inbox → **लॉगिन करें** (Sign in).
   ✅ Pass if you land on `/me`, the member home. M1 never had an invite: the email on their record was enough.
4. Sign out, then try M1 on the office page `/login`: the code arrives, but after **Verify** it says *"This sign-in is for the trust office and agents. Members: use the member login."* and nothing opens.

### 3.3 The invited member (M2)
Sign out of M1 first (you land back on `/m`). Then sign in as `rudranshct+m2@gmail.com` the same way.
✅ Pass if the code arrives straight away, with no link to click first. This is the bug that was fixed.

### 3.4 The member's screens (as M1)
| Page | Check |
|---|---|
| **Home** | Membership card with name and reg no, a banner saying what is owed, shortcuts, stat tiles, the latest notice and recent payments |
| **My dues (मेरा बकाया)** | The Group-1 contribution with the right amount and closing date |
| **My payments (मेरे भुगतान)** | Both of M1's receipts, grouped by year. **Print receipt** and **print certificate** both work |
| **Announcements (सूचनाएँ)** | Both notices, marked **New** |
| **Correction** | Request a change to a phone number. It must go to the office (§4) and must not change the record yet |
| **Pay by UPI** (only if `UPI_ID` is set in Vercel) | On the Group-1 due: pay, enter the amount and a UTR → **pending**. Sending the same UTR again must be refused |
| **Pay online** | Hidden until the trust's Razorpay account is set up. This is correct |
| **Hindi / English** | Every page switches, and the choice stays after a reload |

### 3.5 The member cannot reach anything else
While signed in as M1, type these addresses:

| Address | ✅ Expected |
|---|---|
| `/dashboard`, `/members`, `/payments` | back to `/me` |
| `/agent` | back to `/me` |
| `/login`, `/m`, `/a` | back to `/me` |

Then sign out → you are on `/m`, not `/login`.

---

## 4. Office: handle what the member sent (window 1)

1. The bell shows new items. Open **Approvals**.
2. **Correction:** approve M1's phone change → the member record shows the new number.
3. **UPI payment** (if you did §3.4 Pay by UPI): approve it → it gets a receipt and now counts in the totals.
4. Back in the **member window**, reload:
   ✅ Pass if the bell shows the outcomes, the due is paid, and the receipt is in **My payments**.

---

## 5. Office: the rest of the office features

- **Payments → Cancel receipt** on one test receipt, with a reason. It stays in the list marked Cancelled, and leaves every total.
- **Commission:** this month. Test Agent is listed. Check the figure by hand: approved receipts × 10%. **Mark paid.**
- **Agents ⋯ Move members:** only if you created a second agent.
- **Members ⋯ Export data** (the member's data as JSON). **Erase data** is permanent, so try it only on a throwaway member.
- **Dark mode** (top-bar toggle) on every page.

---

## 6. Agent

### 6A. Look at the screens (sample data, 5 minutes)
In a terminal in the project folder:
```sh
flutter build web --release -t tool/agent_preview/main.dart -o build/agent_preview
npx http-server build/agent_preview -p 8095 --proxy http://localhost:8095?
```
Then open `http://localhost:8095/agent`. The quick `flutter run` server cannot start this preview, because it can't reach the sample data. Nothing you do there is saved.

### 6B. Test for real (live site)
Test Agent was invited in §2.2. In the agent window (Edge):
1. `rudransh-green.vercel.app/login` → `rudranshct+agent@gmail.com` → **Send OTP** → enter the code → **Verify**.
   ✅ Pass if you land on the **agent panel** (`/agent`), not the office dashboard.
2. Sign out, then do the same on `rudransh-green.vercel.app/a`. ✅ Pass if it also lands on `/agent`.
3. Walk the screens:

| Page | Check |
|---|---|
| **Home** | Tiles: my members (3), waiting approval, approved this month, cash in hand, commission. Buttons: Record payment, Add member. Newest closing groups below |
| **My members** | Only M1, M2 and M3. **No Aadhaar anywhere.** Add member → saved as **Pending** with no reg no. Each row's ⋯ menu: View, Edit contact (with the member's email), Add Payment, Print certificate, Invite to app, Report death. **No** Edit, Export data, Erase data or Delete: those stay with the office. Invite M3 → *"Invite email sent"*, and M3's email now shows on the office's Members page |
| **Dues** | Group-1 → who owes, who paid → **Collect** from one member (cash). **Send reminder** opens WhatsApp in Hindi. Collecting twice for the same group must be refused |
| **Record payment** | Gets a receipt number at once but stays **Pending**. **Send receipt** opens WhatsApp |
| **Report a death** | From a member: date and certificate (JPG, PNG or PDF). A `.txt` file is refused |
| **Collections** | Receipts with Waiting, Approved or Rejected. Cash in hand counts only **approved** cash |
| **Hand over cash** | Tick receipts → declare → waiting for the office |

4. Office window → **Approvals**: approve the new member (gets a reg no), the agent's payment, and the handover. Create a closing from the death report. Reject one item with a reason.
   ✅ Pass if the agent's bell shows each outcome, cash in hand goes down after the confirmed handover, and a rejected handover puts the money back.
5. Access: as the agent, type `/dashboard`, `/members` and `/me` → back to `/agent`. Sign out → `/a`.

---

## 7. On a real phone (Android, Chrome)

- Open `rudransh-green.vercel.app` → member login in Hindi, readable, with no sideways scrolling.
- Chrome menu → **Add to Home screen** → the icon is named **Rudransh CT**, and opens full screen.
- Sign in as M1 on the phone. Check the WhatsApp buttons (receipt, reminder) open WhatsApp with Hindi text.
- Print or share a receipt from the phone.

---

## 8. After testing

- To keep the data: mark the TEST members **Inactive**, and deactivate Test Agent.
- To launch clean on 5 Oct, with reg and receipt numbers starting from 1: run [`scripts/reset_data.sql`](../scripts/reset_data.sql) in the Supabase SQL Editor. It deletes **every** record, including the counters, but keeps the office login. **It cannot be undone:** take a backup first (RUNBOOK §5), and run it only when you are sure. It also removes the member and agent logins. Their leftover accounts are under Authentication → Users and can be deleted there.
