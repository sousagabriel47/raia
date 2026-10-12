-- Raia: esquema do Supabase (rode no SQL Editor do seu projeto)

create table if not exists public.planned_workouts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date        date not null,
  name        text not null,
  sport       text not null default 'running',
  steps       jsonb not null default '[]'::jsonb,
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.activities (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  start_time    timestamptz not null,
  sport         text not null,
  distance_m    numeric,
  duration_s    numeric,
  elapsed_s     numeric,
  avg_hr        int,
  max_hr        int,
  avg_cadence   int,
  ascent_m      int,
  calories      int,
  avg_speed_ms  numeric,
  source        text not null default 'fit',
  created_at    timestamptz not null default now(),
  unique (user_id, start_time)
);

create index if not exists planned_workouts_user_date on public.planned_workouts (user_id, date);
create index if not exists activities_user_start on public.activities (user_id, start_time desc);

alter table public.planned_workouts enable row level security;
alter table public.activities enable row level security;

create policy "planned: dono acessa" on public.planned_workouts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "activities: dono acessa" on public.activities
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- Análise por IA (revisão semanal) ----------
create table if not exists public.ai_analyses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  week_start  date not null,
  result      jsonb not null,
  metrics     jsonb not null,
  model       text,
  created_at  timestamptz not null default now(),
  unique (user_id, week_start)
);

alter table public.ai_analyses enable row level security;

create policy "ai_analyses: dono acessa" on public.ai_analyses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- Musculação ----------
create table if not exists public.strength_templates (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null,
  items       jsonb not null default '[]'::jsonb,   -- [{name, muscle, sets, reps, rest_s}]
  created_at  timestamptz not null default now()
);

create table if not exists public.strength_sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date         date not null,
  name         text not null default 'Musculação',
  duration_min int,
  notes        text,
  sets         jsonb not null default '[]'::jsonb,  -- [{exercise, muscle, n, kg, reps, rpe}]
  template_id  uuid references public.strength_templates(id) on delete set null,
  created_at   timestamptz not null default now()
);

create index if not exists strength_sessions_user_date on public.strength_sessions (user_id, date desc);

alter table public.strength_templates enable row level security;
alter table public.strength_sessions enable row level security;

create policy "strength_templates: dono acessa" on public.strength_templates
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "strength_sessions: dono acessa" on public.strength_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- Corpo: check-ins semanais com fotos ----------
create table if not exists public.body_checkins (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date        date not null,
  weight_kg   numeric,
  waist_cm    numeric,
  notes       text,
  photos      jsonb not null default '{}'::jsonb,   -- {front, side, back}: caminhos no bucket body-photos
  ai          jsonb,                                -- última comparação feita pela IA
  ai_at       timestamptz,
  created_at  timestamptz not null default now(),
  unique (user_id, date)
);

alter table public.body_checkins enable row level security;

create policy "body_checkins: dono acessa" on public.body_checkins
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Bucket PRIVADO: cada usuário só enxerga a própria pasta (<user_id>/...)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('body-photos', 'body-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

create policy "body-photos: ler as proprias" on storage.objects
  for select to authenticated
  using (bucket_id = 'body-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "body-photos: enviar as proprias" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'body-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "body-photos: atualizar as proprias" on storage.objects
  for update to authenticated
  using (bucket_id = 'body-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'body-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "body-photos: apagar as proprias" on storage.objects
  for delete to authenticated
  using (bucket_id = 'body-photos' and (storage.foldername(name))[1] = auth.uid()::text);
