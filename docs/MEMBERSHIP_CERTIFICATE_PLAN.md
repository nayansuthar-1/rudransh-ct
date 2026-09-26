# Membership certificate (प्रमाण पत्र) — plan

Goal: print a one-page membership certificate for a member, laid out like the
Shubham Charitable Trust sample the client showed, but branded
**रुद्रांश चेरीटेबल ट्रस्ट – लाखणी**. Everything else on the sample — the field
list and the Hindi wording — stays as it is.

Approved 20 Sep 2026. Section 4 is settled: blank photo box, trust details as constants in code, build now with placeholders for the material the client has not sent yet.

## 1. What the certificate shows, and where each value comes from

| Line on the certificate | Source | Ready? |
| --- | --- | --- |
| Trust name, logo | `TrustInfo` + `assets/brand/` (see §8) | yes |
| ~~`Since : ____`~~ | — | removed (§9) |
| `गुजरात` / `राजस्थान` | constant | yes (महाराष्ट्र removed, §9) |
| `संस्था स्थापना` (date) | constant | placeholder (§8) |
| `संस्था रजीस्टर नं.` | constant | **placeholder — replace before printing (§8)** |
| Scheme name (`परिवार सहयोग योजना`) | `Yojna.name` | yes |
| `योजना प्रारंभ` (date) | `Yojna.startDate` (§8) | yes |
| `सदस्यता क्रमांक` | `Member.regNo` | yes |
| `दिनांक` | the member's joining date, as typed on their record (was the print date until 26 Sep 2026) | yes |
| Photo box | — | one blank frame (§4a) |
| `नाम` | `Member.name` + `fatherOrHusbandName` | yes |
| `गौत्र` / `जाति` | `Member.gotra` / `Member.jati` | yes |
| `जन्म दि` | — | **new field needed** |
| `गांव / सिटी` / `जिला` | `Member.village` / `district` | yes |
| `राज्य` | — | **new field needed** |
| `पता` | village + tehsil + district + pincode | yes |
| `मोबाइल नं` | `Member.primaryPhone` | yes |
| `वारिसदार` / `सम्बन्ध` | `Member.warisName` / `warisRelation` | yes |
| `प्रत्येक <Yojna> सहयोग राशि: ___ रुपये` | `Member.contributionAmount`; the word from `Yojna.shortName`, else the Yojna name | yes (26 Sep 2026) |
| `नोंध` (payout terms line) | `Yojna.description` | yes |
| `कार्यकर्ता` | agent name via `Member.agentId` | yes |
| `अध्यक्ष` name + signature | constant + signature image | name yes (§8), image still needed |
| Head office address + phone numbers | constant | yes (§8) |
| ~~Slip: `Total Amount Rs. ___`~~ | — | removed (§9) |
| ~~Slip: non-refundable note, karyakarta line~~ | — | removed (§9) |

Two member fields do not exist yet: **date of birth** and **state**. Both get
added to the member form, the database, and the agent sign-up form.

## 2. How it gets printed (recommended approach)

Build the certificate as a **self-contained HTML page**, open it in a new
browser tab, and let the browser's own print dialog print it or save it as PDF.

Why not the Flutter `pdf` / `printing` packages: they do not shape Devanagari
correctly — matras and conjuncts come out broken. The whole certificate is in
Hindi, so that rules them out. The browser renders Hindi correctly, costs no new
dependency, and "Save as PDF" is built into Chrome on both desktop and Android.

Details:

- ~~A4 landscape, fixed one page.~~ **Changed 26 Sep 2026:** one certificate
  in the **top half** of an A4 portrait sheet,
  `@page { size: A4 portrait; margin: 0 }`. It is about 199 × 140mm, with
  the same 5.5mm of white above it and at either side. The bottom half stays
  blank: turn the paper round, feed it back in and print the next member,
  whose certificate lands there with the same 5.5mm between the two. Print at
  **Scale 100% / Actual size**; any "fit" setting shrinks the page and widens
  every gap.
- The trust's name, रुद्रांश चैरिटेबल ट्रस्ट, prints over the अध्यक्ष line, as
  the agent's name does over कार्यकर्ता.
- The bundled `NotoSansDevanagari` font is referenced from the app's own asset
  URL, so the page looks the same on a machine with no Hindi font installed.
- Decorative double border, centred logo, maroon/red ink on cream — matching the
  sample. Dotted underlines for each filled value.
- Tear-off receipt slip below the main certificate, as on the sample. **Removed
  21 Sep 2026 at the client's request — see §9.**
- No network calls in the page, so it prints offline once open.

**Sharing on WhatsApp:** `wa.me` links cannot attach a file. The flow is print →
Save as PDF → attach in WhatsApp manually. A public certificate link is possible
later but exposes member data, so it is out of scope here.

## 3. Where the button appears

- Admin → Members → member details → **Print certificate**
- ~~Admin → Payments → a registration payment row~~ — not built; the sheet no
  longer carries a payment (§9)
- Agent → member details / just after enrolling a member → **Print certificate**
- Member portal (`/me`): left out for now, can be added later.

Button label stays English, per the app's existing rule; the printed page is
entirely Hindi.

## 4. Decisions (settled)

**a) Member photo — a blank framed box.** The certificate prints an empty photo
frame and the office glues the photo on, the way the sample is actually
produced. No upload control, no storage, no privacy question on the portal.
Photo upload stays available as a later change if the client wants it.

**b) The trust's fixed details — constants in code.** The registration number,
establishment date, president's name, head office address and phone numbers live
in `lib/core/config/trust_info.dart`. Free, nothing in the database. Changing one
needs a redeploy, which is fine for values that rarely move. Promoting them to an
editable Settings screen is a good Release 2 candidate.

## 5. Work involved

| Step | What | Est. |
| --- | --- | --- |
| 1 | Branding constants (`lib/core/config/trust_info.dart`) + logo and signature assets | 0.25 d |
| 2 | Member `dob` + `state`: model, forms, migration, repositories, RPCs | 0.5 d |
| 3 | HTML certificate template + Hindi labels (`lib/features/certificate/`) | 0.75 d |
| 4 | Open-and-print helper, web + stub (same pattern as `turnstile_web.dart`) | 0.25 d |
| 5 | Buttons on the admin and agent screens | 0.25 d |
| 6 | Tests: every field renders, HTML is escaped, missing data degrades safely | 0.25 d |
|   | **Total** | **~2 days** |

Files touched: `lib/data/models/member.dart`, `lib/data/repositories/*`,
`lib/features/members/members_page.dart`, `lib/features/agent/agent_*.dart`,
`lib/core/l10n/strings.dart`, plus new files under `lib/features/certificate/`
and a new migration in `supabase/migrations/`.

## 6. Needed from the client before step 1 (superseded by §8)

1. Rudransh trust **logo** (PNG or SVG, transparent background if possible).
2. **Registration number** and **establishment date** of the trust.
3. **President's name** and a **signature image**, if the signature should be
   printed rather than signed by hand.
4. **Head office address** and the phone numbers to print at the bottom.
5. The exact `नोंध` payout-terms wording for the scheme.

Missing items can be left blank on the certificate and filled in later — the
template will not break — but the logo is needed for it to look finished.

## 7. Constraints kept

- No new paid service; Cloudinary only if the photo option is chosen.
- `supabase db push` is blocked from this machine, so the migration is written
  here and applied by hand in the Supabase dashboard, as with earlier phases.

---

## 8. Branding round — 20 Sep 2026

The client reviewed the first print, supplied the trust's own `सदस्यता प्रपत्र`
and logo, and asked for the reference sheet's layout to be matched exactly with
Rudransh branding. What changed:

### Branding now in `TrustInfo`

| Field | Value |
| --- | --- |
| Heading | रुद्रांश चेरीटेबल ट्रस्ट – लाखणी (the trust's own spelling of चेरीटेबल) |
| States | गुजरात and राजस्थान at the shoulders of the heading, महाराष्ट्र below it |
| Invocations | ॥ श्री गणेशाय नमः ॥ · ॥ श्री हनुमते नमः ॥ · ॥ श्री कुलदेवी मातायै नमः ॥ |
| Head office | ठी.दक्ष कोम्प्लेक्ष, लाखणी, तह.लाखणी, जि.वाव–थराद (गुजरात) |
| Phones | Shaileshbhai, Ganeshbhai, Kalpeshbhai — the other three on the form are left off to keep the footer to one line |

### Layout corrections against the reference sheet

- The heading is **arched, crimson, outlined in cream**, drawn as SVG because
  CSS cannot curve a baseline. The arc is shallow on purpose: Chrome shapes the
  Devanagari first and then walks glyphs along the path, and a steep curve pulls
  matras off their consonants.
- `सम्बन्ध` closes the `पता` row, and `मोबाईल नं.` shares its row with
  `वारिसदार` — the reference order, not the one first built.
- The contribution amount comes **before** `रु`: `..200.. रु प्रत्येक सहयोग पर लागु ।`
- `कार्यकर्ता`, `नोंध` and the `अध्यक्ष` signature share one row.
- Curly corner flourishes, a double crimson border and a cream wash, matching
  the printed sheet.
- The slip names the agent's **area** as well as their name.

### Assets

The logo lives at `assets/brand/rudransh_logo.jpg`, declared in `pubspec.yaml`
and named once in `TrustInfo.logoAsset`. It is never embedded in code, so
replacing it means dropping in a new file. The supplied file is a JPEG on white,
so the page blends it with `mix-blend-mode: multiply`; a transparent PNG would
be cleaner.

The heading uses **Yatra One** (`assets/fonts/YatraOne-Regular.ttf`, SIL OFL
1.1), bundled as an asset rather than a Flutter font family because only the
printed page uses it.

### `योजना प्रारंभ` is now a real field

It was printing `yojnas.created_at`, the day the record was typed in. Schemes
now carry their own **start date** (`20260923000200_yojna_start_date.sql`),
editable on the Yojna form. `agent_yojnas()` was rebuilt to return it along with
the description, which is the `नोंध` payout line — agents print certificates
too, and both were missing from what they could read.

### Checking the design

```bash
flutter test tool/certificate_preview/preview_test.dart
```

Writes `build/certificate_preview.html` with the fonts and logo inlined, so it
renders correctly straight off the disk. The shipped page loads them from the
app's asset URLs instead.

### Placeholders standing in for the client's details

The client asked (20 Sep 2026) for something to be filled in now and corrected
later, so the sheet prints complete. All four are one-line edits in
`TrustInfo`:

| Field | Standing in | Replace with |
| --- | --- | --- |
| `अध्यक्ष का नाम` | शैलेषभाई वी.लुहार | — given by the client; spelled as the सदस्यता प्रपत्र writes it |
| `संस्था स्थापना` | 01-07-2026 | the real establishment date — this is the day the scheme opened, not the day the trust was founded |
| `Since :` | 2026 | the year the trust was founded |
| `संस्था रजीस्टर नं.` | `F/0000/B.K., GJ/0000/B.K.` | **the real number, before any certificate reaches a member** |

The registration number is deliberately a placeholder with the right *shape*
rather than a plausible number. A certificate is a document the member keeps,
and an invented number that looked real would be taken for the trust's actual
registration. The zeros read as "not filled in" at a glance, which a realistic
number would not.

### Still outstanding from the client

1. **संस्था रजीस्टर नं.** and **संस्था स्थापना** — the real values for the two
   placeholders above
2. A **signature image**, if the अध्यक्ष's signature should be printed rather
   than signed by hand
3. A **transparent PNG** of the logo, if one exists

Separately, these are data the office types in, not code: the **scheme name**
(currently typed in English), its **start date**, and its **description**,
which is the `नोंध` line.

---

## 9. Second review — 21 Sep 2026

After looking at a real print the client asked for three changes:

- **महाराष्ट्र removed.** Only गुजरात and राजस्थान print, at the shoulders of
  the heading, as the reference sheet has it. The सदस्यता प्रपत्र still names
  all three; the constant is gone from `TrustInfo`.
- **`Since : ____` removed** from under the logo, along with its constant.
- **The tear-off receipt slip removed.** The certificate frame is now the whole
  page — nothing prints outside it. The cut line, the Total Amount box, the
  signature line, the karyakarta line and the non-refundable note are all gone,
  and with them `TrustInfo.slipNote`, `CertificateData.slipAmount` and
  `CertificateData.agentArea`. `printMemberCertificate` no longer takes a
  registration payment, so the admin button dropped the `Consumer` that existed
  only to look one up. The photo box grew to 32 × 40 mm to suit the taller
  frame.

The **logo file was also replaced** with a tighter crop (980 × 791 rather than
1157 × 1600, which was mostly empty space and made the crest print small). Same
path, `assets/brand/rudransh_logo.jpg`, so nothing else changed.
