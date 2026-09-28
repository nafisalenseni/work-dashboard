# Private inbox setup

This single-owner endpoint returns the latest 100 notes, newest first. It cannot
insert, update, or delete notes. Keep existing table grants and RLS unchanged.

1. Generate a NEW read credential locally: `openssl rand -hex 32`.
   Save it in your password manager. Do not use your capture secret or admin key.
2. In Supabase → Edge Functions → Secrets, add `READ_NOTES_SECRET` with that value.
3. Create an Edge Function named `read-notes`. Paste
   `functions/read-notes/index.ts` into the dashboard editor and deploy.
4. Turn off the function's built-in JWT verification. The function itself rejects
   requests unless `x-read-secret` matches your read credential.
5. Test a GET request in the dashboard with header `x-read-secret: <your read credential>`.
   Expect status 200 and `{ "notes": [...] }`. Without the header, expect 401.
6. Run Daily Glow. In Inbox → Connect, enter the read credential. The project URL is fixed in InboxPanelView.swift
   to `https://jhpacvtyylpcmgvfvzex.supabase.co`. The app stores the credential
   in macOS Keychain, tied to that project, and reuses it on subsequent launches.

Supabase provides the server-side project URL and administrator credentials to
Edge Functions. Never put those administrator credentials in the app.
To rotate access, replace READ_NOTES_SECRET in Supabase and reconnect in the app.

If using the Supabase CLI instead of the dashboard:
`supabase functions deploy read-notes --project-ref YOUR_PROJECT_REF`
The checked-in config disables JWT verification only for this function.

Local endpoint checks (Node 22.13+):
`node --test supabase/functions/read-notes/read-notes.test.cjs`
These mock the Supabase database request; deployment still needs a live smoke test.

## Editing and permanent deletion

Create a second Edge Function named `manage-note`, paste
`functions/manage-note/index.ts`, deploy, and disable JWT verification for it.
It uses the existing `READ_NOTES_SECRET` and `x-read-secret` header; no new secret,
Keychain entry, table column, or access policy is needed. This credential now
allows reading, editing, and permanent deletion for the personal inbox.

- PATCH JSON `{ "id": "NOTE_UUID", "body": "Updated text" }` edits the body only.
- DELETE JSON `{ "id": "NOTE_UUID" }` permanently deletes that row.
- Missing rows return 404; malformed edits return 422.

Run Daily Glow again in Xcode for Edit/Save and Delete controls. Delete requires
confirmation and cannot be undone. No real notes are mutated by the local tests:
`node --test supabase/functions/manage-note/manage-note.test.cjs`

## Task sections migration

Migration: `migrations/20260927000100_task_sections.sql`.
Verified applied to DailyGlow (`jhpacvtyylpcmgvfvzex`) on 2026-09-27 through
the dashboard SQL editor. All 18 existing notes belong to Inbox. Defaults,
foreign key, Inbox protection trigger, RLS and restricted client access were
verified. This was a manual SQL application, not a CLI migration-history entry;
do not run it again against this project.
This is intended for the existing single-owner `public.notes` schema. Apply once
as a transaction using the Supabase SQL editor; it is not a repeatable seed script.

- Creates `task_sections` with a name, color, display order and creation timestamp.
- Seeds Inbox with ID `00000000-0000-4000-8000-000000000001`.
- Adds `notes.section_id` (required, defaults to Inbox) and `notes.sort_order`.
- Existing notes automatically belong to Inbox. Capture requests omitting these
  new fields continue to work. Note contents and existing notes permissions stay intact.
- Enables RLS for sections and limits direct table access to the server-side
  service role, matching the existing private Edge Function architecture.
- Prevents deleting Inbox, changing its identity/name, or deleting a section that
  still contains notes. Move those notes before deleting another section.

After applying, verify:

```sql
select s.id, s.name, count(n.id) as notes
from public.task_sections s
left join public.notes n on n.section_id = s.id
group by s.id, s.name;

select column_name, column_default, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'notes'
  and column_name in ('section_id', 'sort_order');
```

The current app remains compatible but does not yet expose section creation or
moving notes between sections. Local completion/order and local-only tasks are
not uploaded or migrated by this SQL script. The sections endpoint below handles
listing/creation; SwiftUI integration and note membership updates remain to do.

## Sections endpoint

`functions/task-sections/index.ts` implements `/functions/v1/task-sections`.
Both methods require the existing `x-read-secret: READ_NOTES_SECRET` header.
Deployed to DailyGlow on 2026-09-27 with legacy gateway JWT verification off.
A live unauthenticated GET returned HTTP 401 from the handler. Authorized
listing/creation were tested with mocked database responses, not live writes.

- `GET`: returns `{ "sections": [...] }` with `id`, `name`, `color`, `created_at`.
- `POST`: accepts `{ "name": "Growth", "color": "green" }` and returns
  HTTP 201 with `{ "section": { ... } }`.
- Names are trimmed and must contain 1–80 characters. Color defaults to yellow;
  supported values are yellow, red, green, blue, purple and gray.
- IDs are generated by the database; caller-supplied IDs/order are ignored.
  Manual display ordering remains local. No rename/delete/move API is added yet.
- Missing/wrong secrets return 401; malformed JSON 400; invalid fields 422;
  missing configuration 503; database errors 502 without database details.

Deploy `task-sections` with gateway JWT verification off, matching the existing
private functions. Authentication remains enforced by the function itself.
No new secret or table migration is required beyond the sections migration.

```sh
node --test supabase/functions/task-sections/task-sections.test.cjs
```

These tests use mocked database calls; they do not create production sections.
