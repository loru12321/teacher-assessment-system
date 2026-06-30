-- Annual fill controls let admin/dean open or close leader score entry.

create table if not exists public.fill_controls (
    academic_year text primary key,
    is_open boolean not null default false,
    opened_at timestamptz,
    closed_at timestamptz,
    updated_by uuid references public.profiles(id) on delete set null,
    updated_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

alter table public.fill_controls enable row level security;

grant select, insert, update, delete on public.fill_controls to authenticated;

drop policy if exists "Allow authenticated users to read fill controls" on public.fill_controls;
create policy "Allow authenticated users to read fill controls"
on public.fill_controls
for select
to authenticated
using ((select auth.uid()) is not null);

drop policy if exists "Allow admin and dean to manage fill controls" on public.fill_controls;
create policy "Allow admin and dean to manage fill controls"
on public.fill_controls
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

insert into public.fill_controls (academic_year, is_open, updated_at)
values ('2025-2026', false, now())
on conflict (academic_year) do nothing;

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
        or (
            exists (
                select 1
                from public.fill_controls fc
                where fc.academic_year = assessment_scores.academic_year
                  and fc.is_open = true
            )
            and exists (
                select 1
                from public.project_assignments pa
                where pa.academic_year = assessment_scores.academic_year
                  and pa.project_id = assessment_scores.project_id
                  and pa.leader_id = (select auth.uid())
            )
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
        or (
            exists (
                select 1
                from public.fill_controls fc
                where fc.academic_year = assessment_scores.academic_year
                  and fc.is_open = true
            )
            and exists (
                select 1
                from public.project_assignments pa
                where pa.academic_year = assessment_scores.academic_year
                  and pa.project_id = assessment_scores.project_id
                  and pa.leader_id = (select auth.uid())
            )
        )
    )
);
