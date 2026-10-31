-- Focus Reset — Supabase schema (run once in Supabase → SQL Editor → New query → Run).
-- Safe to run again: every statement is idempotent.

-- 1) One table holds every synced record (tasks, habits, commitments, ...).
create table if not exists public.user_records (
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  kind        text        not null check (kind in ('task','commitment','habit','habit_log','focus','sleep','profile')),
  id          text        not null check (char_length(id) between 1 and 100),
  data        jsonb,
  updated_at  timestamptz not null,
  deleted     boolean     not null default false,
  synced_at   timestamptz not null default clock_timestamp(),
  primary key (user_id, kind, id)
);

create index if not exists user_records_user_synced_idx on public.user_records (user_id, synced_at);

-- 2) Server-side rules for every write:
--    * synced_at always comes from the server clock (used for "pull changes since").
--    * an older edit can never overwrite a newer one (last write wins).
create or replace function public.user_records_before_write()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    return null; -- keep the newer version already stored
  end if;
  new.synced_at := clock_timestamp();
  return new;
end;
$$;

drop trigger if exists user_records_before_write on public.user_records;
create trigger user_records_before_write
  before insert or update on public.user_records
  for each row execute function public.user_records_before_write();

-- 3) Row Level Security: each user can only ever see and change their own rows.
alter table public.user_records enable row level security;

drop policy if exists "own rows: select" on public.user_records;
drop policy if exists "own rows: insert" on public.user_records;
drop policy if exists "own rows: update" on public.user_records;
drop policy if exists "own rows: delete" on public.user_records;

create policy "own rows: select" on public.user_records
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "own rows: insert" on public.user_records
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own rows: update" on public.user_records
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own rows: delete" on public.user_records
  for delete to authenticated using ((select auth.uid()) = user_id);

revoke all on public.user_records from anon;
grant select, insert, update, delete on public.user_records to authenticated;

-- 4) In-app account deletion (required by the App Store).
--    Deletes the signed-in user; their rows are removed by ON DELETE CASCADE.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
