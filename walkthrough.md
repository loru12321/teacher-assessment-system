# Teacher Assessment System Setup Walkthrough

This project is a static Vue 3 + Tailwind + Supabase app for teacher teaching
quality assessment.

## 1. GitHub

Repository:

```text
https://github.com/loru12321/teacher-assessment-system
```

The current app entry is:

```text
index.html -> sign-in.html -> app.html
```

## 2. Supabase Project

Project URL:

```text
https://qfhkicgfhetcgcvupsxu.supabase.co
```

The browser app uses this publishable key in `sign-in.html` and `app.html`:

```text
sb_publishable_a2e5g0OkKOPmZbollq1iOA_mSOZxDzc
```

## 3. Run Database SQL

Open the Supabase Dashboard SQL Editor for the project, paste the full contents
of this file, and run it:

```text
supabase/migrations/20260630000000_init_schema.sql
```

The SQL creates:

- `profiles`
- `project_assignments`
- `assessment_scores`
- RLS policies
- `admin_create_user(...)`
- `admin_delete_user(...)`

## 4. Initialize Default Accounts

After the SQL runs successfully, open:

```text
sign-in.html
```

Expand `快捷测试与系统初始化`, then click:

```text
初始化云端默认账号
```

Default password for every demo account:

```text
123456
```

## 5. Default Accounts

Admin:

```text
account: admin
email: admin@school.com
password: 123456
```

Research leader:

```text
account: research_leader
email: research_leader@school.com
password: 123456
```

Example assessment leaders:

```text
g6_leader_1
g9_leader_1
```

Example teacher:

```text
zhang
```

All default accounts use password `123456`.

## 6. Verification

After initialization:

1. Log in with `admin / 123456`.
2. Confirm the admin dashboard opens.
3. Confirm `导入与分发`, `组长填报`, `管理员汇总`, and `教师个人端` render by role.
4. Confirm Supabase contains rows in `profiles`.
5. Assign projects, enter scores as a leader, and verify totals/rankings in the
   admin summary view.

## Current Note

If `admin / 123456` fails with `Invalid login credentials`, the Supabase SQL has
not been run yet or the default accounts have not been initialized.
