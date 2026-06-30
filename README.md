# Teacher Assessment System

Static prototype for middle-school teacher teaching quality assessment.

The current single-page version supports role login, Excel import for teachers
and accounts, grade-based project assignment, leader score entry, and admin/dean
summary views. Teacher score assessment and class assessment are calculated as
parallel totals with separate rankings.

## Files

- `教学质量评价方案.html` - main single-page assessment app
- `assets/xlsx.full.min.js` - local Excel import/export library

## Demo Login

Default demo password for built-in accounts:

```text
123456
```

Roles:

- Admin
- Dean
- Assessment leader
- Assessed teacher

Default leaders include four assessment leaders for each grade from Grade 6 to
Grade 9. Project ownership is assigned in the app, not through the Excel import
template.

## Supabase

Project name: `teacher-assessment-system`

Project URL:

```text
https://qfhkicgfhetcgcvupsxu.supabase.co
```
