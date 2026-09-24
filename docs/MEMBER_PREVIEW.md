# Member portal: preview and test checklist

## Run the preview

The preview opens the member screens on sample data, already signed in as a member. No login or Supabase is needed. Nothing is saved, and reloading the page starts over.

```sh
flutter run -d chrome -t tool/member_preview/main.dart \
  --dart-define=UPI_ID=trust@upi --dart-define=UPI_PAYEE="Rudransh CT"
```

To get a plain link instead, build it once and serve the `build/member_preview` folder:

```sh
flutter build web -t tool/member_preview/main.dart -o build/member_preview \
  --dart-define=UPI_ID=trust@upi "--dart-define=UPI_PAYEE=Rudransh CT"
```

The sample member is the active member with the most unpaid closings. Two announcements are added at start-up.

Chrome DevTools (F12 → phone icon) lets you check the phone layout.

## Checklist

| Screen | Address | Try |
|---|---|---|
| Home | `/me` | Greeting changes with the time of day (सुप्रभात / नमस्ते / शुभ संध्या) |
| | | Blue membership card: photo or initials, name, reg no, yojna, member since, status |
| | | Standing banner: amber "₹… बकाया है" with **अभी जमा करें**, blue when only waiting for approval, green "सब जमा है" when nothing is owed |
| | | Five shortcuts: Dues, Receipts, Certificate (prints), Announcements, Correction (opens the form) |
| | | Four coloured tiles: total contributed (counts up), receipts, member for, per closing |
| | | Latest notice with a **नई** badge, the last 3 payments, then *My details* and *My corrections* |
| My dues | `/me/dues` | Total due in large type, then one card per closing with a calendar date. The oldest one is marked **सबसे पुराना** |
| | | **Pay by UPI**: enter a reference. The card then shows the payment as waiting for approval, and the Home banner turns blue |
| | | With nothing owed, the page shows a green "सब जमा है" thank-you |
| My payments | `/me/payments` | Four tiles: total, receipts, this year, pending |
| | | Filter chips (सभी / स्वीकृत / लंबित). Receipts are grouped by year, each with a status icon |
| | | Print icon: the receipt opens for printing |
| Announcements | `/me/announcements` | A general announcement, and one for the member's yojna. Both show **नई** for a week, and the "all yojnas" pill is in Hindi |
| Everywhere | top bar | **English / हिन्दी** switch. Every label changes language |
| | top bar | Dark mode, and sign out (sign-out goes to the login page, which is where the preview ends) |
| | address bar | Type `/dashboard` or `/members`. You are sent back to `/me` |

## Not in the preview

- **Pay online (Razorpay).** It needs the real Razorpay key, so test it on the live site.
- **Email + code sign-in.** Test it on the live site, as described below.
- **Office side of a correction or UPI payment** (approving it). The preview has only the member login.

## Testing on the live site

1. Sign in to `rudransh-green.vercel.app` as the office. Add a member with **your own email**, then approve the member.
2. In a private window, open the same address, enter that email and type in the 6-digit code you receive. You land on `/me`.
3. Afterwards, deactivate the test member. It is a real record and counts toward reg numbers and closing dues.

Until the fixed `invite_user` function is deployed (docs/APP_ACCESS.md §1), **do not** press *Invite to app* for this member. An invite made now leaves the login unconfirmed, and no code can be sent to it.
