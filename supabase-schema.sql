-- CODERVOX Supabase database setup
-- Run the entire script in Supabase Dashboard > SQL Editor.
-- This script uses Row Level Security. Never expose a service_role key in the website.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 24),
  display_name text not null default 'CODERVOX member' check (char_length(display_name) <= 40),
  bio text not null default '' check (char_length(bio) <= 160),
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 2200),
  image_url text,
  created_at timestamptz not null default now(),
  constraint post_has_content check (char_length(trim(body)) > 0 or image_url is not null)
);

create table if not exists public.likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id <> following_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete set null,
  reason text not null check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists posts_created_at_idx on public.posts(created_at desc);
create index if not exists posts_user_id_idx on public.posts(user_id, created_at desc);
create index if not exists comments_post_id_idx on public.comments(post_id, created_at);
create index if not exists follows_following_idx on public.follows(following_id);

-- Create a profile automatically when a new Auth user registers.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_name text;
  candidate text;
begin
  base_name := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1), 'member'), '[^a-zA-Z0-9_]', '', 'g'));
  base_name := left(coalesce(nullif(base_name, ''), 'member'), 15);
  candidate := base_name;
  if exists (select 1 from public.profiles where username = candidate) then
    candidate := base_name || '_' || left(replace(new.id::text, '-', ''), 6);
  end if;
  insert into public.profiles(id, username, display_name)
  values (new.id, candidate, coalesce(nullif(new.raw_user_meta_data->>'display_name',''), 'CODERVOX member'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Enable RLS.
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;
alter table public.reports enable row level security;

-- Profiles: public read, owner-only insert/update.
drop policy if exists "Profiles are visible to everyone" on public.profiles;
create policy "Profiles are visible to everyone" on public.profiles for select using (true);
drop policy if exists "Users can create own profile" on public.profiles;
create policy "Users can create own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Posts: public read, signed-in users create their own; owners delete/update.
drop policy if exists "Posts are visible to everyone" on public.posts;
create policy "Posts are visible to everyone" on public.posts for select using (true);
drop policy if exists "Users can create own posts" on public.posts;
create policy "Users can create own posts" on public.posts for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users can update own posts" on public.posts;
create policy "Users can update own posts" on public.posts for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users can delete own posts" on public.posts;
create policy "Users can delete own posts" on public.posts for delete to authenticated using (auth.uid() = user_id);

-- Likes: public counts/visibility, each user manages their own likes.
drop policy if exists "Likes are visible to everyone" on public.likes;
create policy "Likes are visible to everyone" on public.likes for select using (true);
drop policy if exists "Users can add own likes" on public.likes;
create policy "Users can add own likes" on public.likes for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users can remove own likes" on public.likes;
create policy "Users can remove own likes" on public.likes for delete to authenticated using (auth.uid() = user_id);

-- Comments: public read; authenticated users create their own; owners delete.
drop policy if exists "Comments are visible to everyone" on public.comments;
create policy "Comments are visible to everyone" on public.comments for select using (true);
drop policy if exists "Users can create own comments" on public.comments;
create policy "Users can create own comments" on public.comments for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users can delete own comments" on public.comments;
create policy "Users can delete own comments" on public.comments for delete to authenticated using (auth.uid() = user_id);

-- Follows: visible publicly; a user can only create/remove their own follow edges.
drop policy if exists "Follows are visible to everyone" on public.follows;
create policy "Follows are visible to everyone" on public.follows for select using (true);
drop policy if exists "Users can follow as themselves" on public.follows;
create policy "Users can follow as themselves" on public.follows for insert to authenticated with check (auth.uid() = follower_id);
drop policy if exists "Users can unfollow as themselves" on public.follows;
create policy "Users can unfollow as themselves" on public.follows for delete to authenticated using (auth.uid() = follower_id);

-- Reports are private to the reporter for insertion; only trusted admins should review them.
drop policy if exists "Users can submit reports" on public.reports;
create policy "Users can submit reports" on public.reports for insert to authenticated with check (auth.uid() = reporter_id);
drop policy if exists "Users can view own reports" on public.reports;
create policy "Users can view own reports" on public.reports for select to authenticated using (auth.uid() = reporter_id);

-- Public image bucket for post images. Only the signed-in owner can upload/delete files
-- inside a folder named with their own auth UID. Public read is needed to display feed images.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-images', 'post-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Post images are publicly readable" on storage.objects;
create policy "Post images are publicly readable" on storage.objects for select using (bucket_id = 'post-images');
drop policy if exists "Users upload into own folder" on storage.objects;
create policy "Users upload into own folder" on storage.objects for insert to authenticated
with check (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Users delete from own folder" on storage.objects;
create policy "Users delete from own folder" on storage.objects for delete to authenticated
using (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- Realtime feed refresh.
do $$
begin
  alter publication supabase_realtime add table public.posts;
exception when duplicate_object then null;
when undefined_object then null;
end $$;
