-- Unified invite-code mechanism for both friend adds and crew joins — not
-- part of the original schema (docs/framework.md §5), added because both
-- the friends and crews checklists ask for invite codes and there's no
-- reason to build the same thing twice.
create table public.invite_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default upper(substring(md5(random()::text || clock_timestamp()::text), 1, 8)),
  created_by uuid not null references public.users(id) on delete cascade,
  kind text not null check (kind in ('friend', 'crew')),
  crew_id uuid references public.crews(id) on delete cascade,
  max_uses integer,
  use_count integer not null default 0,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  check ((kind = 'crew' and crew_id is not null) or (kind = 'friend' and crew_id is null))
);

create index invite_codes_code_idx on public.invite_codes(code);

alter table public.invite_codes enable row level security;

-- Creators manage their own codes directly. Redemption by someone else goes
-- through the redeem-invite function (service role) — a redeemer needs to
-- look up a code they didn't create.
create policy "Users can view their own invite codes"
  on public.invite_codes for select
  using (auth.uid() = created_by);

create policy "Users can create their own invite codes"
  on public.invite_codes for insert
  with check (
    auth.uid() = created_by
    and (kind = 'friend' or public.is_crew_member(crew_id))
  );
