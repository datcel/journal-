-- =====================================================================
-- CRT Desk · configuración de Supabase (pegar entero en SQL Editor → Run)
-- Se puede ejecutar varias veces sin problema.
-- =====================================================================

-- 1) Tabla del journal: una fila por usuario y por app ('crtdesk', y en el futuro 'swingdesk')
create table if not exists public.journals (
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  app        text not null,
  data       jsonb not null,
  rev        bigint not null default 1,
  updated_at timestamptz not null default now(),
  primary key (user_id, app)
);

alter table public.journals enable row level security;
grant select, insert, update, delete on public.journals to authenticated;
revoke all on public.journals from anon;

drop policy if exists "journals_select_own" on public.journals;
drop policy if exists "journals_insert_own" on public.journals;
drop policy if exists "journals_update_own" on public.journals;
drop policy if exists "journals_delete_own" on public.journals;
create policy "journals_select_own" on public.journals for select to authenticated using (auth.uid() = user_id);
create policy "journals_insert_own" on public.journals for insert to authenticated with check (auth.uid() = user_id);
create policy "journals_update_own" on public.journals for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "journals_delete_own" on public.journals for delete to authenticated using (auth.uid() = user_id);

-- 2) Bucket PRIVADO para las capturas (máx. 5 MB por imagen, solo imágenes)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('capturas', 'capturas', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false;

-- Cada usuario solo ve y toca su carpeta: capturas/<su id>/...
drop policy if exists "capturas_select_own" on storage.objects;
drop policy if exists "capturas_insert_own" on storage.objects;
drop policy if exists "capturas_update_own" on storage.objects;
drop policy if exists "capturas_delete_own" on storage.objects;
create policy "capturas_select_own" on storage.objects for select to authenticated
  using (bucket_id = 'capturas' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "capturas_insert_own" on storage.objects for insert to authenticated
  with check (bucket_id = 'capturas' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "capturas_update_own" on storage.objects for update to authenticated
  using (bucket_id = 'capturas' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "capturas_delete_own" on storage.objects for delete to authenticated
  using (bucket_id = 'capturas' and (storage.foldername(name))[1] = auth.uid()::text);

-- Comprobación: debe devolver la tabla y el bucket
select 'tabla journals' as que, count(*) as filas from public.journals
union all
select 'bucket capturas', count(*) from storage.buckets where id = 'capturas';
