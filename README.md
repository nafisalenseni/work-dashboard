Fun little side project to make a personal work dashboard. more to come :)

The notes editor is a TypeScript React project in `notes-editor/`.

- `src/NotesEditor.tsx`: editor component.
- `src/main.tsx`: imports styles and mounts React.
- `src/storage.ts`: native and browser persistence.
- `src/styles.css`: custom editor styles.
- `index.html`: page markup.

Run `npm ci --prefix notes-editor` to install dependencies, then
`npm run dev --prefix notes-editor` to preview at http://127.0.0.1:8765
with live reload. Browser notes remain separate from app notes.

After edits, run `npm run build --prefix notes-editor` before building in Xcode.
This type-checks TypeScript and bundles the editor into `Dailyglow/NotesEditorWeb`,
which Xcode copies into the app. Keep these generated assets with source changes.
The bundled editor does not need the development server or CDN imports to run.

## Native app code

- `Dailyglow/ContentView.swift`: responsive sidebar/workspace layout.
- `Dailyglow/InboxPanelView.swift`: task sections, sorting, and inbox actions.
- `Dailyglow/Inbox/InboxStorage.swift`: task models, local persistence schema, and Keychain access.
- `Dailyglow/Inbox/InboxTaskRow.swift`: task display, inline renaming, and hover deletion.
- `Dailyglow/Inbox/TaskSectionView.swift`: shared section padding, corners, header layout, and detached scrolling.
- `Dailyglow/Inbox/TodayNotesView.swift`: expandable Notes row and persistent editor.
- `Dailyglow/Inbox/TodayWindowPortal.swift`: Today pop-out, docking, dragging, and window sizing.
- `Dailyglow/WorkspaceView.swift`: bundled PR workspace, native GitHub bridge, and local asset serving.
- `Dailyglow/BlockNoteEditorView.swift`: notes webview and native persistence bridge.

The legacy browser, cookie importer, PR sidebar, Quick Links, and old to-do editor
have been removed. GitHub authentication uses the existing GitHub CLI login.
See `pulldash-workspace/README.md` for rebuilding the bundled PR workspace.
