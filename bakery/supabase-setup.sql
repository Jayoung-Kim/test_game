-- 꼬마 빵집: Supabase SQL Editor에 통째로 붙여넣고 Run 하세요.

create table if not exists public.villages (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  nickname   text not null unique check (char_length(nickname) between 1 and 12),
  data       jsonb not null default '{}'::jsonb,
  level      int not null default 1,
  hearts     int not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.guestbook (
  id         bigint generated always as identity primary key,
  owner_id   uuid not null references public.villages(user_id) on delete cascade,
  author_id  uuid not null references auth.users(id) on delete cascade,
  author_name text not null,
  message    text not null check (char_length(message) between 1 and 80),
  created_at timestamptz not null default now()
);

alter table public.villages  enable row level security;
alter table public.guestbook enable row level security;

-- 마을: 누구나 구경 가능, 수정은 본인만
drop policy if exists "villages read"   on public.villages;
drop policy if exists "villages insert" on public.villages;
drop policy if exists "villages update" on public.villages;
create policy "villages read"   on public.villages for select using (true);
create policy "villages insert" on public.villages for insert with check (auth.uid() = user_id);
create policy "villages update" on public.villages for update using (auth.uid() = user_id);

-- 방명록: 누구나 읽기, 로그인한 사람이 본인 이름으로 쓰기, 마을 주인/작성자는 지우기
drop policy if exists "guestbook read"   on public.guestbook;
drop policy if exists "guestbook write"  on public.guestbook;
drop policy if exists "guestbook delete" on public.guestbook;
create policy "guestbook read"   on public.guestbook for select using (true);
create policy "guestbook write"  on public.guestbook for insert with check (auth.uid() = author_id);
create policy "guestbook delete" on public.guestbook for delete using (auth.uid() = owner_id or auth.uid() = author_id);

-- 하트 보내기 (다른 사람 마을의 hearts만 +1, 본인 제외)
create or replace function public.send_heart(target uuid)
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if auth.uid() is null or auth.uid() = target then return null; end if;
  update public.villages set hearts = hearts + 1 where user_id = target returning hearts into n;
  return n;
end $$;
grant execute on function public.send_heart(uuid) to authenticated;
