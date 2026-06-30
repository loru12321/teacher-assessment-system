# Teacher Assessment System

GitHub 直达网址链接: [https://github.com/loru12321/teacher-assessment-system](https://github.com/loru12321/teacher-assessment-system)

Cloud-ready static app for middle-school teacher teaching quality assessment.

The current single-page version supports role login, Excel import for teachers
and accounts, grade-based project assignment, leader score entry, and
admin/research-leader summary views. Teacher score assessment and class
assessment are calculated as parallel totals with separate rankings.

## Files

- `教学质量评价方案.html` - redirect entry
- `sign-in.html` - login and default account initialization portal
- `index.html` - main Vue 3 + Tailwind + Supabase assessment app
- `supabase/migrations/20260630000000_init_schema.sql` - Supabase schema and RPC setup
- `walkthrough.md` - setup and testing walkthrough
- `assets/xlsx.full.min.js` - local Excel import/export library

## Demo Login

Default demo password for initialized accounts:

```text
123456
```

Roles:

- Admin
- Research leader
- Assessment leader
- Assessed teacher

Default admin:

```text
account: admin
email: admin@school.com
password: 123456
```

Default accounts include one admin, one research leader, and four assessment
leaders for each grade from Grade 6 to Grade 9. Each grade starts with a
different project assignment plan. Project ownership is assigned in the app, not
through the Excel import template.

## Supabase

Project name: `teacher-assessment-system`

Project URL:

```text
https://qfhkicgfhetcgcvupsxu.supabase.co
```

Run `supabase/migrations/20260630000000_init_schema.sql` in the Supabase SQL
Editor first, then initialize default accounts from `sign-in.html`.
