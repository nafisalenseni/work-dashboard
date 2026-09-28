-- Single-owner Daily Glow. Existing Edge Functions continue to work unchanged.
begin;

create table public.task_sections (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  color text not null default 'yellow'
    check (color in ('yellow', 'red', 'green', 'blue', 'purple', 'gray')),
  sort_order bigint not null default 0,
  created_at timestamptz not null default now(),
  constraint task_sections_inbox_name check (
    id <> '00000000-0000-4000-8000-000000000001'::uuid or name = 'Inbox'
  )
);

-- Only server-side Edge Functions access sections, like the existing notes API.
alter table public.task_sections enable row level security;
revoke all on public.task_sections from public, anon, authenticated;
grant select, insert, update, delete on public.task_sections to service_role;

insert into public.task_sections (id, name, color, sort_order)
values ('00000000-0000-4000-8000-000000000001', 'Inbox', 'yellow', 0);

alter table public.notes
  add column section_id uuid not null
    default '00000000-0000-4000-8000-000000000001'::uuid,
  add column sort_order bigint not null default 0,
  add constraint notes_section_id_fkey foreign key (section_id)
    references public.task_sections(id) on delete restrict;

create index notes_section_order_idx
  on public.notes (section_id, sort_order, captured_at desc, id desc);

-- The default Inbox must always exist, including while it happens to be empty.
create function public.protect_default_task_section()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.id = '00000000-0000-4000-8000-000000000001'::uuid then
    if TG_OP = 'DELETE' then
      raise exception 'The default Inbox cannot be deleted';
    elsif new.id <> old.id then
      raise exception 'The default Inbox ID cannot be changed';
    end if;
  end if;
  if TG_OP = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger protect_default_task_section
before delete or update on public.task_sections
for each row execute function public.protect_default_task_section();

commit;
