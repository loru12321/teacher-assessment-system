-- Notifications and score-change annotations.

alter table public.assessment_scores
    add column if not exists change_tag text,
    add column if not exists change_note text,
    add column if not exists previous_score numeric,
    add column if not exists previous_note text,
    add column if not exists change_count integer not null default 0;

create table if not exists public.notifications (
    id uuid primary key default gen_random_uuid(),
    academic_year text not null,
    recipient_id uuid references public.profiles(id) on delete cascade,
    recipient_role text check (recipient_role in ('admin', 'dean', 'leader', 'teacher', 'all')),
    title text not null,
    body text not null,
    event_type text not null default 'system',
    related_teacher_id uuid references public.profiles(id) on delete set null,
    related_project_id text,
    created_by uuid references public.profiles(id) on delete set null,
    read_at timestamptz,
    created_at timestamptz not null default now(),
    check (recipient_id is not null or recipient_role is not null)
);

alter table public.notifications enable row level security;

grant select, insert, update on public.notifications to authenticated;

create index if not exists notifications_academic_year_recipient_idx
on public.notifications (academic_year, recipient_id, recipient_role, created_at desc);

drop policy if exists "Allow users to read their notifications" on public.notifications;
create policy "Allow users to read their notifications"
on public.notifications
for select
to authenticated
using (
    recipient_id = (select auth.uid())
    or recipient_role = 'all'
    or exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.role = notifications.recipient_role
    )
);

drop policy if exists "Allow authenticated users to create notifications" on public.notifications;
create policy "Allow authenticated users to create notifications"
on public.notifications
for insert
to authenticated
with check (
    (select auth.uid()) is not null
    and (created_by is null or created_by = (select auth.uid()))
);

drop policy if exists "Allow users to mark their notifications read" on public.notifications;
create policy "Allow users to mark their notifications read"
on public.notifications
for update
to authenticated
using (
    recipient_id = (select auth.uid())
    or recipient_role = 'all'
    or exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.role = notifications.recipient_role
    )
)
with check (
    recipient_id = (select auth.uid())
    or recipient_role = 'all'
    or exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.role = notifications.recipient_role
    )
);
