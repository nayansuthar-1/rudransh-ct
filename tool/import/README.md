# Importing existing records

Loads the trust's existing agents, members and receipts from Excel. The tool
checks every row and writes a SQL script. It never connects to a database.

## 1. Prepare the files

In Excel, use **File → Save As → CSV UTF-8** so Hindi text survives. Start from
the templates in [`templates/`](templates/). The first row must hold these
column names; column order does not matter, and extra columns are reported and
ignored.

### agents.csv

| Column | Required | Notes |
| --- | --- | --- |
| `code` | | `AG-007`. Leave blank to have one assigned. |
| `name` | yes | |
| `phone` | | 10-digit mobile; `+91`, spaces and a leading 0 are removed |
| `email`, `area`, `district` | | |
| `commission_percent` | | 0–100; `5%` is fine |
| `join_date` | | `DD-MM-YYYY`, `DD/MM/YYYY` or `YYYY-MM-DD`; blank = import day |

### members.csv

| Column | Required | Notes |
| --- | --- | --- |
| `reg_no` | | `SSY-2025-0184`. Leave blank to have one assigned (current year). Needed if payments.csv refers to this member. |
| `yojna_code` | yes | Code of a Yojna **already created in the app**, e.g. `SSY` |
| `name` | yes | |
| `father_or_husband_name`, `jati`, `gotra`, `waris_name`, `waris_relation` | | |
| `gender` | | `male` / `female` / `other` or `पुरुष` / `महिला` / `अन्य`; blank = male |
| `primary_phone` | yes | 10-digit mobile |
| `alt_phone` | | 10-digit mobile |
| `aadhaar` | | 12 digits (see the privacy note in IMPLEMENTATION_PLAN.md §7) |
| `village`, `tehsil`, `district` | | |
| `pincode` | | 6 digits |
| `agent_code` | | Must exist in agents.csv or the app |
| `join_date` | | as above |
| `status` | | `active` / `inactive` / `closed` or `सक्रिय` / `निष्क्रिय` / `बंद`; blank = active |

### payments.csv

| Column | Required | Notes |
| --- | --- | --- |
| `receipt_no` | | `RCP-1001`. Leave blank to have one assigned. |
| `reg_no` | yes | Member's registration number (in members.csv or the app) |
| `amount` | yes | More than 0; `₹1,500` is fine |
| `date` | yes | as above |
| `mode` | | `cash` / `upi` / `bank` (NEFT, RTGS, IMPS) / `cheque`; blank = cash |
| `status` | | `paid` / `pending` / `failed`; blank = paid |
| `kind` | | `registration` / `contribution` / `closing payout`; blank = contribution |
| `agent_code` | | Blank = the member's agent |
| `reference`, `note` | | UTR, cheque number, remarks |

> Excel turns long numbers into `9.87654E+09`. Format the phone and Aadhaar
> columns as **Text** before typing or pasting them.

Closing cases are not imported. Enter them in the app after the import.

## 2. Check

```bash
dart run tool/import_data.dart --agents agents.csv --members members.csv --payments payments.csv
```

This writes to `build/import/`:

- `exceptions.csv`: every rejected row, with its line number, column and reason.
  Share it with the client, fix the spreadsheet, and run again until it is
  empty or the remaining rows are knowingly skipped.
- `summary.txt`: valid row counts and the payment total. Compare them with the
  client's spreadsheet.
- `import.sql`: the valid rows.

## 3. Load (staging first)

```bash
psql "<staging session-pooler URL>" -v ON_ERROR_STOP=1 -f build/import/import.sql
```

The script is one transaction. If a Yojna or agent is missing, or a number
already exists, it stops with a plain message and nothing is saved. The last
lines print the row counts and the payment total. After loading, numbering
continues from the highest imported numbers.

Repeat on production only after the client has checked staging.
