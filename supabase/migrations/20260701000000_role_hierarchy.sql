create or replace function public.role_level(role_text text)
returns integer
language sql
immutable
as $$
  select case role_text
    when 'teacher' then 1
    when 'leader' then 2
    when 'dean' then 3
    when 'admin' then 4
    else 0
  end;
$$;

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
  actor_role text;
  target_existing_role text;
begin
  select role into actor_role
  from public.profiles
  where id = auth.uid();

  if auth.uid() is not null then
    if actor_role not in ('admin', 'dean') then
      raise exception 'Unauthorized';
    end if;
  elsif exists (select 1 from public.profiles) then
    raise exception 'Unauthorized';
  end if;

  if role_text not in ('admin', 'dean', 'leader', 'teacher') then
    raise exception 'Invalid role';
  end if;

  email_address := username_text || '@school.com';
  normalized_grade := case
    when coalesce(grade_text, '') ~ '[6六]' then '六年级'
    when coalesce(grade_text, '') ~ '[7七]' then '七年级'
    when coalesce(grade_text, '') ~ '[8八]' then '八年级'
    when coalesce(grade_text, '') ~ '[9九]' then '九年级'
    else nullif(grade_text, '')
  end;

  select id, role into new_user_id, target_existing_role
  from public.profiles
  where username = username_text;

  if new_user_id is null then
    select id into new_user_id
    from auth.users
    where email = email_address;

    if new_user_id is not null then
      select role into target_existing_role
      from public.profiles
      where id = new_user_id;
    end if;
  end if;

  if auth.uid() is not null then
    if new_user_id = auth.uid() then
      raise exception 'Cannot modify own account';
    end if;

    if actor_role = 'dean' and public.role_level(role_text) >= public.role_level(actor_role) then
      raise exception 'Insufficient role level';
    end if;

    if actor_role = 'dean'
       and target_existing_role is not null
       and public.role_level(target_existing_role) >= public.role_level(actor_role) then
      raise exception 'Insufficient role level';
    end if;
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

  insert into auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  values (
    new_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    email_address,
    crypt(password_text, gen_salt('bf', 10)),
    now(),
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

  insert into public.profiles (id, username, full_name, role, grade, subject, classes)
  values (new_user_id, username_text, full_name_text, role_text, normalized_grade, subject_text, classes_text);

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

create or replace function public.admin_delete_user(target_user_id uuid)
returns void
security definer
language plpgsql
as $$
declare
  actor_role text;
  target_role text;
begin
  select role into actor_role
  from public.profiles
  where id = auth.uid();

  select role into target_role
  from public.profiles
  where id = target_user_id;

  if actor_role not in ('admin', 'dean') then
    raise exception 'Unauthorized';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'Cannot delete own account';
  end if;

  if actor_role = 'dean' and public.role_level(target_role) >= public.role_level(actor_role) then
    raise exception 'Insufficient role level';
  end if;

  delete from auth.users where id = target_user_id;
end;
$$;
