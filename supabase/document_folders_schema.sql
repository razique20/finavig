-- ============================================================
-- Finavig — Document Folders schema
-- Run this in Supabase Dashboard → SQL Editor → New query.
--
-- Model: Folders live inside a collection (workspace) owned by a user.
-- Documents optionally reference a folder via folder_id.
-- Deleting a folder sets folder_id to NULL (documents are never deleted).
-- ============================================================

create table if not exists public.document_folders (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  collection_id uuid not null references public.collections(id) on delete cascade,
  name text not null,
  icon text not null default 'folder',
  color int not null default 0,
  created_at timestamptz not null default now()
);

-- Index for speedy listing by collection and owner
create index if not exists idx_document_folders_collection
  on public.document_folders(collection_id);

create index if not exists idx_document_folders_owner
  on public.document_folders(owner_id);

-- Add folder_id to documents table if not present
alter table public.documents
  add column if not exists folder_id uuid references public.document_folders(id) on delete set null;

create index if not exists idx_documents_folder_id
  on public.documents(folder_id);

-- Enable RLS
alter table public.document_folders enable row level security;

-- RLS Policies
drop policy if exists "Users can view their own document folders" on public.document_folders;
create policy "Users can view their own document folders"
  on public.document_folders for select
  using (auth.uid() = owner_id);

drop policy if exists "Users can insert their own document folders" on public.document_folders;
create policy "Users can insert their own document folders"
  on public.document_folders for insert
  with check (auth.uid() = owner_id);

drop policy if exists "Users can update their own document folders" on public.document_folders;
create policy "Users can update their own document folders"
  on public.document_folders for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "Users can delete their own document folders" on public.document_folders;
create policy "Users can delete their own document folders"
  on public.document_folders for delete
  using (auth.uid() = owner_id);
