create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  friend_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (user_id != friend_id),
  unique (user_id, friend_id)
);

create index friendships_user_id_idx on public.friendships(user_id);
create index friendships_friend_id_idx on public.friendships(friend_id);

alter table public.friendships enable row level security;

create policy "Users can view friendships they're party to"
  on public.friendships for select
  using (auth.uid() = user_id or auth.uid() = friend_id);

create policy "Users can send friend requests"
  on public.friendships for insert
  with check (auth.uid() = user_id);

-- Only the recipient can accept/decline — the sender can't accept their own request.
create policy "Recipients can accept or decline"
  on public.friendships for update
  using (auth.uid() = friend_id);

create trigger friendships_set_updated_at
  before update on public.friendships
  for each row execute function public.set_updated_at();
