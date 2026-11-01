-- GharKa Expenses: run this entire script in Supabase SQL Editor.
-- IMPORTANT: Change the four invite codes below before using this app.
-- Create the four Auth accounts through the website's Create account tab.

create extension if not exists pgcrypto;

create table if not exists public.families (
  id uuid primary key,
  name text not null,
  created_at timestamptz not null default now()
);

insert into public.families (id, name)
values ('b8c4f0a1-7d32-4a9e-9b20-4d7c5e8a1001', 'GharKa Family')
on conflict (id) do nothing;

create table if not exists public.family_invites (
  code text primary key,
  family_id uuid not null references public.families(id) on delete cascade,
  display_name text not null check (display_name in ('Aditya','Mom','Dad','Bhavana')),
  used_by uuid unique references auth.users(id),
  created_at timestamptz not null default now()
);

insert into public.family_invites (code, family_id, display_name) values
('CHANGE-ADITYA-91X', 'b8c4f0a1-7d32-4a9e-9b20-4d7c5e8a1001', 'Aditya'),
('CHANGE-MOM-72Q', 'b8c4f0a1-7d32-4a9e-9b20-4d7c5e8a1001', 'Mom'),
('CHANGE-DAD-63K', 'b8c4f0a1-7d32-4a9e-9b20-4d7c5e8a1001', 'Dad'),
('CHANGE-BHAVANA-84P', 'b8c4f0a1-7d32-4a9e-9b20-4d7c5e8a1001', 'Bhavana')
on conflict (code) do nothing;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  display_name text not null check (display_name in ('Aditya','Mom','Dad','Bhavana')),
  created_at timestamptz not null default now(),
  unique (family_id, display_name)
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  item text not null check (char_length(trim(item)) between 1 and 100),
  amount numeric(12,2) not null check (amount > 0),
  category text not null check (category in ('Groceries','Food','Transport','Bills','Shopping','Medical','Education','Household','Entertainment','Other')),
  expense_date date not null default current_date check (expense_date <= current_date),
  payment_method text not null check (payment_method in ('UPI','Cash','Card','Bank transfer','Other')),
  notes text check (notes is null or char_length(notes) <= 300),
  created_at timestamptz not null default now()
);

-- Signup trigger: only valid, unused family invitations can create a profile.
create or replace function public.handle_new_family_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite_row public.family_invites%rowtype;
begin
  select * into invite_row
  from public.family_invites
  where code = new.raw_user_meta_data ->> 'invite_code'
    and used_by is null
  for update;

  if not found then
    raise exception 'Invalid or already-used family invite code';
  end if;

  if (new.raw_user_meta_data ->> 'display_name') is distinct from invite_row.display_name then
    raise exception 'The selected family name does not match this invite code';
  end if;

  insert into public.profiles (id, family_id, display_name)
  values (new.id, invite_row.family_id, invite_row.display_name);

  update public.family_invites set used_by = new.id where code = invite_row.code;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_family on auth.users;
create trigger on_auth_user_created_family
after insert on auth.users
for each row execute procedure public.handle_new_family_user();

alter table public.families enable row level security;
alter table public.family_invites enable row level security;
alter table public.profiles enable row level security;
alter table public.expenses enable row level security;

-- No client policies on family_invites: invite codes cannot be enumerated from the browser.
-- SECURITY DEFINER helper avoids recursive RLS evaluation on profiles.
create or replace function public.current_family_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.family_id from public.profiles p where p.id = (select auth.uid())
$$;

-- Family members can read only profiles belonging to their family.
drop policy if exists "Family members read family profiles" on public.profiles;
create policy "Family members read family profiles"
on public.profiles for select to authenticated
using (family_id = (select public.current_family_id()));

drop policy if exists "Family members read family expenses" on public.expenses;
create policy "Family members read family expenses"
on public.expenses for select to authenticated
using (family_id = (select public.current_family_id()));

drop policy if exists "Members add own expenses" on public.expenses;
create policy "Members add own expenses"
on public.expenses for insert to authenticated
with check (
  created_by = (select auth.uid())
  and family_id = (select public.current_family_id())
);

drop policy if exists "Members update own expenses" on public.expenses;
create policy "Members update own expenses"
on public.expenses for update to authenticated
using (created_by = (select auth.uid()) and family_id = (select public.current_family_id()))
with check (created_by = (select auth.uid()) and family_id = (select public.current_family_id()));

drop policy if exists "Members delete own expenses" on public.expenses;
create policy "Members delete own expenses"
on public.expenses for delete to authenticated
using (created_by = (select auth.uid()) and family_id = (select public.current_family_id()));

-- Set family_id automatically on each inserted expense, preventing client spoofing.
create or replace function public.set_expense_family_id()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  select p.family_id into new.family_id
  from public.profiles p
  where p.id = (select auth.uid());
  if new.family_id is null then raise exception 'Family profile not found'; end if;
  new.created_by := (select auth.uid());
  return new;
end;
$$;

drop trigger if exists set_expense_family_before_insert on public.expenses;
create trigger set_expense_family_before_insert
before insert on public.expenses
for each row execute procedure public.set_expense_family_id();

-- Grant only the operations used by the frontend.
grant usage on schema public to authenticated;
grant select on public.profiles to authenticated;
grant select, insert, update, delete on public.expenses to authenticated;
