-- Scope rosters, assignments, and scores by academic year.
-- The 7/8 month fill window is evaluated in Asia/Shanghai time.

create or replace function public.current_fill_academic_year()
returns text
language sql
stable
as $$
    select (extract(year from timezone('Asia/Shanghai', now()))::int - 1)::text
        || '-'
        || (extract(year from timezone('Asia/Shanghai', now()))::int)::text;
$$;

create or replace function public.is_fill_window_for_year(year_text text)
returns boolean
language sql
stable
as $$
    select extract(month from timezone('Asia/Shanghai', now()))::int in (7, 8)
        and year_text = public.current_fill_academic_year();
$$;

create table if not exists public.year_people (
    id uuid primary key default gen_random_uuid(),
    academic_year text not null,
    user_id uuid not null references public.profiles(id) on delete cascade,
    role text not null check (role in ('admin', 'dean', 'leader', 'teacher')),
    grade text,
    subject text,
    classes text,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (academic_year, user_id)
);

alter table public.year_people enable row level security;

grant select, insert, update, delete on public.year_people to authenticated;
grant execute on function public.current_fill_academic_year() to authenticated;
grant execute on function public.is_fill_window_for_year(text) to authenticated;

drop policy if exists "Allow authenticated users to read year people" on public.year_people;
create policy "Allow authenticated users to read year people"
on public.year_people
for select
to authenticated
using ((select auth.uid()) is not null);

drop policy if exists "Allow admin and dean to manage year people in fill window" on public.year_people;
create policy "Allow admin and dean to manage year people in fill window"
on public.year_people
for all
to authenticated
using (
    public.is_fill_window_for_year(academic_year)
    and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.role in ('admin', 'dean')
    )
)
with check (
    public.is_fill_window_for_year(academic_year)
    and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.role in ('admin', 'dean')
    )
);

alter table public.project_assignments
    add column if not exists academic_year text;

update public.project_assignments
set academic_year = '2025-2026'
where academic_year is null;

alter table public.project_assignments
    alter column academic_year set not null;

alter table public.assessment_scores
    add column if not exists academic_year text;

update public.assessment_scores
set academic_year = '2025-2026'
where academic_year is null;

alter table public.assessment_scores
    alter column academic_year set not null;

alter table public.project_assignments
    drop constraint if exists project_assignments_grade_project_id_key;

alter table public.assessment_scores
    drop constraint if exists assessment_scores_teacher_id_project_id_key;

create unique index if not exists project_assignments_academic_year_grade_project_id_key
on public.project_assignments (academic_year, grade, project_id);

create unique index if not exists assessment_scores_academic_year_teacher_id_project_id_key
on public.assessment_scores (academic_year, teacher_id, project_id);

create index if not exists year_people_academic_year_role_grade_idx
on public.year_people (academic_year, role, grade);

create index if not exists project_assignments_academic_year_leader_idx
on public.project_assignments (academic_year, leader_id);

create index if not exists assessment_scores_academic_year_teacher_idx
on public.assessment_scores (academic_year, teacher_id);

insert into public.year_people (academic_year, user_id, role, grade, subject, classes, is_active)
select '2025-2026', id, role, grade, subject, classes, true
from public.profiles
where role in ('leader', 'teacher')
on conflict (academic_year, user_id) do update
set role = excluded.role,
    grade = excluded.grade,
    subject = excluded.subject,
    classes = excluded.classes,
    is_active = true,
    updated_at = now();

drop policy if exists "Allow admin and dean to manage project_assignments" on public.project_assignments;
create policy "Allow admin and dean to manage project_assignments"
on public.project_assignments
for all
to authenticated
using (
    public.is_fill_window_for_year(academic_year)
    and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.role in ('admin', 'dean')
    )
)
with check (
    public.is_fill_window_for_year(academic_year)
    and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.role in ('admin', 'dean')
    )
);

drop policy if exists "Allow leaders and admins to write scores" on public.assessment_scores;
create policy "Allow leaders and admins to write scores"
on public.assessment_scores
for all
to authenticated
using (
    public.is_fill_window_for_year(academic_year)
    and (
        exists (
            select 1 from public.profiles p
            where p.id = (select auth.uid())
              and p.role in ('admin', 'dean')
        )
        or exists (
            select 1
            from public.project_assignments pa
            where pa.academic_year = assessment_scores.academic_year
              and pa.project_id = assessment_scores.project_id
              and pa.leader_id = (select auth.uid())
        )
    )
)
with check (
    public.is_fill_window_for_year(academic_year)
    and (
        exists (
            select 1 from public.profiles p
            where p.id = (select auth.uid())
              and p.role in ('admin', 'dean')
        )
        or exists (
            select 1
            from public.project_assignments pa
            where pa.academic_year = assessment_scores.academic_year
              and pa.project_id = assessment_scores.project_id
              and pa.leader_id = (select auth.uid())
        )
    )
);
