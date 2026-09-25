# Rudransh CT: what the software does and how it works

**रुद्रांश चैरिटेबल ट्रस्ट** · Plain-language guide

The trust's register, receipt book and claim file in one website. Staff open it in a browser, sign in with a code sent to their email, and every entry is saved safely online.

- **Website:** rudransh-green.vercel.app. Office login: `/login`. Members: `/m` (the bare address opens it too). Agents: `/a`.
- **Launch:** Mon 5 Oct 2026
- **Running cost:** ₹0 a month
- **Status as of:** 17 Sep 2026

**Contents:** [Big picture](#the-big-picture) · [How money flows](#how-the-money-flows-step-by-step) · [The screens](#the-screens-one-by-one) · [Signing in](#signing-in-no-password-to-remember) · [Safety](#how-the-data-is-kept-safe) · [Cost](#what-it-costs-and-what-it-runs-on) · [Timeline](#timeline) · [Coming in November](#coming-in-november-agents-and-members-get-their-own-login) · [Things that help you](#things-that-help-you) · [Questions](#common-questions) · [Word list](#word-list)

---

## The big picture

Today the trust keeps members, receipts and claims on paper or in Excel. This software replaces that with one shared online register that everyone in the office sees at the same time.

| Area | Replaces | What it does |
| --- | --- | --- |
| **Members** | The register | Every member's details, nominee (Waris), agent and scheme in one searchable list. |
| **Payments** | The receipt book | Each rupee received gets a receipt number automatically. No two receipts can share a number. |
| **Closing cases** | The claim file | When a member's claim falls due (such as their wedding in Shadi Sahyog Yojna), the claim is raised, the collection is tracked and the payout is marked. |
| **Dashboard** | Adding up by hand | Totals, this month's collection and top agents are calculated for you, always up to date. |

### Who uses it

| Person | From 5 October | From 5 November |
| --- | --- | --- |
| **Owner** (trustees) | Full access | Full access, plus approvals, invites and the change history |
| **Staff admin** (office) | Full access | Daily work, but cannot delete or cancel |
| **Agent** (field) | No login yet | Sees only their own members; entries wait for office approval |
| **Member** | No login yet | Sees own membership, receipts and dues |

Expected size: 10 to 15 office users and up to about 2,000 members.

---

## How the money flows, step by step

This is the real order of work. Each step names the screen where it happens.

1. **Set up a scheme (Yojna)** — *Yojna screen*
   Give it a name and a short code such as `SSY`. Enter three amounts: the joining fee, what each member gives for every closing (contribution), and what the family receives (claim amount).

2. **Add the agents** — *Agents screen*
   Name, phone, area, which schemes they work in and their commission %. The software gives each a code such as `AG-007`.

3. **Enrol a member** — *Members screen*
   Fill in name, father or husband name, Jati, Gotra, Waris, phone, Aadhaar and address, and pick the scheme and agent. A registration number like `SSY-2026-0184` is created automatically. The same phone number cannot be registered twice.

4. **Record money received** — *Payments screen*
   Choose the member, the amount, the type (joining fee, contribution or closing payout) and how it was paid (cash, UPI, bank transfer or cheque, with the UTR or cheque number). A receipt number like `RCP-1001` is given.

5. **A member's claim falls due: open a closing case** — *Closing Payments screen*
   For example a wedding in Shadi Sahyog Yojna. Enter the closing date, group (for example `Group-14`), claim amount and nominee. The member stays **Active** and keeps paying for other members' closings.

6. **Collect contributions and pay the family** — *Closing Payments + Payments*
   Other members pay their contribution. The case shows collected against pending, and moves from **Unpaid** to **Partial** to **Paid** when the family is settled.

> **Example with made-up numbers**
> 500 active members × **₹100** contribution = **₹50,000** collected for the nominee.
> The real amounts are whatever the trust sets on the Yojna screen.

---

## The screens, one by one

A menu on the left (or behind the ☰ button on a phone) opens each screen. At the top, a scheme selector filters every screen to one Yojna or shows all of them.

### Dashboard (the first page)
A quick health check of the trust.
- Coloured tiles: Total Members, Closing Members, Total Agents, This Month's collection
- Closed Cases list, Members by Yojna, Top Agents, Recent Payments

### Members
The member register.
- Search by name, registration number or phone; filter by status, agent or district
- Add, edit, or open a member's full details
- A member who already has receipts cannot be deleted; mark them **Inactive** instead so the money history stays correct

### Agents
The field team.
- Each agent's members, money collected and commission
- If an agent is removed, their members stay; they just have no agent until one is assigned

### Yojna
The schemes and their amounts.
- Create or edit contribution, claim and joining-fee amounts
- A scheme with members cannot be deleted, only switched off

### Closing Payments (claim settlements)
Every claim from start to payout.
- Totals for all claims, collected and still pending
- Deleting a case by mistake clears it from the member

### Dues
Who still owes for closings, member by member, for the Yojna picked in the top bar.
- Tiles: members owing, total due, money waiting for approval, and every contribution received
- Each member's total due across all closings and what they have contributed so far
- Tap a member to see each closing they owe for and their past receipts
- **Pay** opens the payment form with the oldest unpaid closing and its amount already filled in
- **Who owes:** for every closing, each active member of the Yojna who was added to the app before the closing was created. The member whose closing it is doesn't pay for their own, but keeps paying for others'
- **One contribution per closing**, even when several closings share a closing group

### Payments
The receipt book.
- Filter by dates, payment mode, type and status (Paid, Pending, Failed)

> **Works on any device.** The same website fits a phone, a tablet and an office computer. On a phone, tables turn into easy-to-read cards. There is also a light and dark mode.

---

## Signing in: no password to remember

Like getting an OTP from a bank, but by email.

1. **Enter your email.** Only emails the owner has invited are accepted. Anyone else is refused.
2. **Check your inbox.** A 6-digit code arrives from rudranshct@gmail.com. Look in Spam if it's not there.
3. **Type the code.** It works for 10 minutes. After that, ask for a new one. You stay signed in when the page reloads.

A new person must first click **Activate account** in their invite email, once. Until they do, the site says the email is not registered.

---

## How the data is kept safe

What protects the trust's records, in plain words.

| Protection | What it means |
| --- | --- |
| **Locked to invited people** | The database itself refuses anyone who is not signed in and invited, even if someone finds the website's address. |
| **Stored in India** | The records sit on servers in Mumbai. |
| **Nightly backup** | Every night at 2:00 AM a locked (encrypted) copy is saved elsewhere. Daily copies are kept 30 days, monthly copies for a year. |
| **Change history** | Every add, edit and delete records who did it and when. Mistakes can be traced. |
| **No duplicate numbers** | Even if two staff save at the same second, registration and receipt numbers never repeat. |
| **Kept awake** | Free databases sleep after 7 quiet days. A small automatic check every 2 days stops that, even over Diwali holidays. |

---

## What it costs and what it runs on

Everything uses free plans. All accounts belong to the trust's own email, rudranshct@gmail.com, so the trust owns everything.

| Service | Think of it as | Free limit | Monthly cost |
| --- | --- | --- | --- |
| **Supabase** | The locked cupboard holding the register, plus the sign-in desk | 500 MB of data (years of room at this size) | ₹0 |
| **Brevo** | The postman delivering sign-in codes | 300 emails a day | ₹0 |
| **Cloudflare Pages** | The shop front: the website address people open | No practical limit | ₹0 |
| **Cloudflare R2** | A bank locker for the nightly backup copies | 10 GB | ₹0 |
| **GitHub** | The workshop where the software is built, checked and sent live | Free minutes | ₹0 |
| **Cloudinary** | The album for photos and PDFs (for example certificates) | Existing free quota | ₹0 |

> **Honest note:** no company promises its free plan forever. If Supabase ever changes its terms, the data can be moved in about a day, or the trust can pay about $25 (roughly ₹2,100) a month for the paid plan.

---

## Timeline

| When | Milestone | Details |
| --- | --- | --- |
| 14 Sep 2026 | **Work started** | Database, sign-in, backups and website set up. |
| 30 Sep – 1 Oct | **Testing** | The trust tries a real day's work on the test copy and approves it. |
| **Mon 5 Oct** | **Launch: office** | Staff invited, 1-hour training in Hindi, 2 weeks of support. |
| Thu 5 Nov | **Launch: agents and members** | Before Diwali (8 Nov). |

---

## Coming in November: agents and members get their own login

The main rule: **agents and members suggest, the office approves.** Money and nominee details never change without an admin.

- **Agents — work from the field on a phone.** Add new members and record collections (both wait for approval), see who still owes money for each closing, send WhatsApp reminders and receipts, report a closing with a proof document, see cash in hand and commission.
- **Members — check their own account.** Look up their membership with their phone number and the last 4 digits of their Aadhaar. See receipts, dues and announcements, pay by the trust's UPI QR code and enter the UTR, and ask for corrections.
- **Office — stays in control.** An approval list with a count, an Invite to app button for agents, moving members between agents, cash handover and commission tracking, announcements, and a bell for alerts.
- **Privacy — Aadhaar stays hidden.** Agents and members never see a full Aadhaar number. This is enforced inside the database, not just hidden on screen.

---

## Things that help you

Practical points for whoever looks after the project: what's still open, what to ask the trust, and what to watch.

### 1. Still to do before the 5 October launch

- [ ] Send the sign-in and email settings to the live system (Runbook section 1.2)
- [ ] Restore one backup into the test copy to prove backups really work. A backup that was never restored is only a hope. (Runbook section 5)
- [ ] Let the automatic checks run once and pass (duplicate numbers, logged-out access)
- [ ] Check Hindi names show correctly in Chrome and on an Android phone
- [ ] Check an old code (more than 10 minutes) is refused
- [ ] Test that code emails reach Gmail and Yahoo inboxes, not spam
- [ ] Trust runs a real day's work on the test copy and signs off
- [ ] Invite the admins, do the Hindi training, hand over the runbook
- [x] Database, sign-in, paging, backups, keep-alive, website hosting, phone layouts, light and dark mode

### 2. Questions the trust still has to answer

Until they answer, the software uses the sensible default shown.

| Question | Why it matters | Default for now |
| --- | --- | --- |
| Is the full Aadhaar number needed? | Indian law limits who may store full Aadhaar. Ask the trust's CA or lawyer. | Stored today; plan is last 4 digits only |
| How many admins, and their emails? | Needed to send invites on launch day | — |
| Who are the owners (trustees)? | Owners can delete, cancel and see everything | Existing admins are owners |
| Do agents handle cash? | Decides whether cash handover tracking is needed | Yes, tracked |
| Does an agent's new member become active straight away? | Controls fraud and mistakes | Waits for office approval |
| Are dues per closing, monthly or yearly? | Changes how "who still owes" is counted | One contribution per closing |
| Do most members have a smartphone or email? | Decides how members sign in | Lookup page for all; email code if they have email |
| How is agent commission paid? | Shapes the commission report | % of approved collections, monthly |
| Printable receipts, Excel export, SMS? | Not in the software today; extra work if wanted | Not included |
| Should "collected" on a claim add up by itself from receipts? | Saves manual typing | Typed by hand |

### 3. Limits to keep an eye on

- **300 emails a day.** Fine for sign-in codes. Don't plan to email all 2,000 members about a closing; use in-app announcements and WhatsApp links instead.
- **500 MB of data.** Years of room. An automatic warning appears in GitHub at 350 MB.
- **Aadhaar and privacy.** Add a consent checkbox to the member form and a way to export or delete a member's data on request.
- **Nothing yet for agents.** Until 5 November, agents give details to the office and staff enter them.

### 4. Good habits

- **Mark Inactive, don't delete.** Keeps the receipt history correct.
- **One email per person.** Never share a login; the change history then shows exactly who did what.
- **Keep passwords in one shared password manager**, not in WhatsApp or email.
- **Keep at least one active owner**, or nobody can invite or change roles.
- **Keep the backup key safe.** Without it, backups cannot be opened by anyone.
- **Try changes on the test copy first.** Anything sent to the live version reaches staff straight away.
- **Do a restore test once a month.** It takes a few minutes and proves the backups are good.

---

## Common questions

Quick answers for when something looks wrong.

**The code email didn't arrive**
Check Spam and Promotions. Wait a minute and ask again. If it still fails, the person may not be invited, or may not have clicked Activate account yet.

**"This email is not registered"**
The owner must invite them first. If already invited, they need to open the invite email once and click Activate account.

**The site shows no data or seems asleep**
The database may have paused. The owner opens the Supabase dashboard and clicks Restore project. It takes a few minutes and no data is lost.

**A new version broke something**
In Cloudflare Pages, the previous version can be brought back with one Rollback click. Data is not affected.

**Someone left the office**
Switch their access off. Their name stays on old records, but they can no longer sign in.

**Why can't I delete this member or scheme?**
It has receipts or members attached. Deleting would break the money history, so mark it Inactive instead.

**Two people saved at the same time; will numbers clash?**
No. The database hands out numbers one at a time, so every registration and receipt number is unique.

**Who changed this member's phone number?**
An owner can look it up in the change history, which shows the old value, new value, person and time.

---

## Word list

Terms you'll see on screen or hear from the developer.

| Term | Meaning |
| --- | --- |
| **Yojna** | A scheme the trust runs, with its own amounts and code. |
| **Waris / Nominee** | The family member who receives the claim. |
| **Closing** | A claim a Yojna pays out, such as a member's wedding in Shadi Sahyog Yojna. Every other active member pays one contribution for it. |
| **Closing group** | A batch label for closings collected together, such as Group-14. |
| **Contribution** | What each member pays towards a closing. |
| **Claim amount** | What the family receives. |
| **Reg no** | A member's registration number, for example SSY-2026-0184. |
| **UTR** | The reference number of a UPI or bank transfer, used to prove a payment. |
| **OTP / code** | The 6-digit number emailed at sign-in. |
| **Staging / test copy** | A separate practice version where changes are tried before going live. |
| **Production / live** | The real version staff use every day. |
| **Backup** | A saved copy of all data, made every night. |
| **Runbook** | The step-by-step instruction book for the person looking after the system ([docs/RUNBOOK.md](RUNBOOK.md)). |
| **Pending** | Entered but not yet approved or confirmed; not counted in totals. |

---

*Based on the project plan and code as of 17 September 2026. Dates and defaults may change once the trust answers the open questions.*
