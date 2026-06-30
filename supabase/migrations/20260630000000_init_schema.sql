-- Enable pgcrypto for password hashing
create extension if not exists pgcrypto;

-- Create profiles table
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  full_name text not null,
  role text not null check (role in ('admin', 'dean', 'leader', 'teacher')),
  grade text,
  subject text,
  classes text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS for profiles
alter table public.profiles enable row level security;

-- Create project_assignments table
create table if not exists public.project_assignments (
  id uuid default gen_random_uuid() primary key,
  grade text not null,
  project_id text not null,
  leader_id uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (grade, project_id)
);

-- Enable RLS for project_assignments
alter table public.project_assignments enable row level security;

-- Create assessment_scores table
create table if not exists public.assessment_scores (
  id uuid default gen_random_uuid() primary key,
  teacher_id uuid references public.profiles(id) on delete cascade not null,
  project_id text not null,
  score numeric check (score >= 0),
  note text,
  status text not null default 'draft' check (status in ('draft', 'submitted')),
  scorer_id uuid references public.profiles(id) on delete set null,
  scorer_name text,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (teacher_id, project_id)
);

-- Enable RLS for assessment_scores
alter table public.assessment_scores enable row level security;

-- -------------------------------------------------------------
-- ROW LEVEL SECURITY POLICIES
-- -------------------------------------------------------------

-- Profiles Policies
create policy "Allow profiles reading to authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Allow admin and dean to update profiles"
  on public.profiles for update
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('admin', 'dean')
    )
  );

-- Project Assignments Policies
create policy "Allow project_assignments reading to authenticated users"
  on public.project_assignments for select
  to authenticated
  using (true);

create policy "Allow admin and dean to manage project_assignments"
  on public.project_assignments for all
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('admin', 'dean')
    )
  );

-- Assessment Scores Policies
create policy "Allow teachers to read their own scores"
  on public.assessment_scores for select
  to authenticated
  using (
    teacher_id = auth.uid() or
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('admin', 'dean', 'leader')
    )
  );

create policy "Allow leaders and admins to write scores"
  on public.assessment_scores for all
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('admin', 'dean')
    ) or
    exists (
      select 1 from public.project_assignments pa
      join public.profiles p on p.id = auth.uid()
      join public.profiles t on t.id = assessment_scores.teacher_id
      where p.role = 'leader' 
        and pa.leader_id = p.id 
        and pa.project_id = assessment_scores.project_id
        and t.grade = pa.grade
    )
  );

-- -------------------------------------------------------------
-- TRIGGERS AND HANDLERS
-- -------------------------------------------------------------

-- Create profile on user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, full_name, role, grade, subject, classes)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', substring(new.email from '([^@]+)')),
    coalesce(new.raw_user_meta_data->>'name', 'User'),
    coalesce(new.raw_user_meta_data->>'role', 'teacher'),
    new.raw_user_meta_data->>'grade',
    new.raw_user_meta_data->>'subject',
    new.raw_user_meta_data->>'classes'
  );
  return new;
end;
$$ language plpgsql security definer;

-- Recreate trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- -------------------------------------------------------------
-- ADMIN RPC FUNCTIONS
-- -------------------------------------------------------------

-- Create user with transaction security
create or replace function public.admin_create_user(
  username_text text,
  password_text text,
  full_name_text text,
  role_text text,
  grade_text text,
  subject_text text,
  classes_text text
)
returns uuid
security definer
language plpgsql
as $$
declare
  new_user_id uuid;
  email_address text;
  normalized_grade text;
begin
  -- Access check: Only admin, dean, or when database has no users (initial run)
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'dean')
  ) and auth.uid() is not null then
    if exists (select 1 from public.profiles) then
      raise exception 'Unauthorized';
    end if;
  end if;

  email_address := username_text || '@school.com';
  normalized_grade := case
    when coalesce(grade_text, '') ~ '[6六]' then '六年级'
    when coalesce(grade_text, '') ~ '[7七]' then '七年级'
    when coalesce(grade_text, '') ~ '[8八]' then '八年级'
    when coalesce(grade_text, '') ~ '[9九]' then '九年级'
    else nullif(grade_text, '')
  end;

  select id into new_user_id
  from public.profiles
  where username = username_text;

  if new_user_id is null then
    select id into new_user_id
    from auth.users
    where email = email_address;
  end if;

  if new_user_id is not null then
    update auth.users
    set encrypted_password = crypt(password_text, gen_salt('bf', 10)),
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        confirmation_token = coalesce(confirmation_token, ''),
        recovery_token = coalesce(recovery_token, ''),
        email_change = coalesce(email_change, ''),
        email_change_token_new = coalesce(email_change_token_new, ''),
        raw_app_meta_data = '{"provider":"email","providers":["email"]}',
        raw_user_meta_data = jsonb_build_object(
          'sub', new_user_id::text,
          'email', email_address,
          'username', username_text,
          'name', full_name_text,
          'role', role_text,
          'grade', normalized_grade,
          'subject', subject_text,
          'classes', classes_text,
          'email_verified', true,
          'phone_verified', false
        ),
        updated_at = now()
    where id = new_user_id;

    update public.profiles
    set username = username_text,
        full_name = full_name_text,
        role = role_text,
        grade = normalized_grade,
        subject = subject_text,
        classes = classes_text
    where id = new_user_id;

    if not exists (select 1 from public.profiles where id = new_user_id) then
      insert into public.profiles (id, username, full_name, role, grade, subject, classes)
      values (new_user_id, username_text, full_name_text, role_text, normalized_grade, subject_text, classes_text);
    end if;

    update auth.identities
    set identity_data = jsonb_build_object(
          'sub', new_user_id::text,
          'email', email_address,
          'username', username_text,
          'name', full_name_text,
          'role', role_text,
          'grade', normalized_grade,
          'subject', subject_text,
          'classes', classes_text,
          'email_verified', true,
          'phone_verified', false
        ),
        provider_id = new_user_id::text,
        updated_at = now()
    where user_id = new_user_id and provider = 'email';

    if not exists (select 1 from auth.identities where user_id = new_user_id and provider = 'email') then
      insert into auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
      )
      values (
        gen_random_uuid(),
        new_user_id,
        jsonb_build_object(
          'sub', new_user_id::text,
          'email', email_address,
          'username', username_text,
          'name', full_name_text,
          'role', role_text,
          'grade', normalized_grade,
          'subject', subject_text,
          'classes', classes_text,
          'email_verified', true,
          'phone_verified', false
        ),
        'email',
        new_user_id::text,
        now(),
        now(),
        now()
      );
    end if;

    return new_user_id;
  end if;

  new_user_id := gen_random_uuid();

  -- Insert into auth.users
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmation_token,
    recovery_token,
    email_change,
    email_change_token_new,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  values (
    '00000000-0000-0000-0000-000000000000',
    new_user_id,
    'authenticated',
    'authenticated',
    email_address,
    crypt(password_text, gen_salt('bf', 10)),
    now(),
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object(
      'sub', new_user_id::text,
      'email', email_address,
      'username', username_text,
      'name', full_name_text,
      'role', role_text,
      'grade', normalized_grade,
      'subject', subject_text,
      'classes', classes_text,
      'email_verified', true,
      'phone_verified', false
    ),
    now(),
    now()
  );

  -- Associate identities for Supabase Auth to resolve correctly
  insert into auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  )
  values (
    gen_random_uuid(),
    new_user_id,
    jsonb_build_object(
      'sub', new_user_id::text,
      'email', email_address,
      'username', username_text,
      'name', full_name_text,
      'role', role_text,
      'grade', normalized_grade,
      'subject', subject_text,
      'classes', classes_text,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    new_user_id::text,
    now(),
    now(),
    now()
  );

  return new_user_id;
end;
$$;

-- Delete user
create or replace function public.admin_delete_user(target_user_id uuid)
returns void
security definer
language plpgsql
as $$
begin
  -- Access check
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'dean')
  ) then
    raise exception 'Unauthorized';
  end if;

  delete from auth.users where id = target_user_id;
end;
$$;
