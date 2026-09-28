# Dailyglow PullDash workspace

React workspace for Dailyglow, with a standalone browser playground.

## Run

From this directory, run `npm run dev`, then open http://127.0.0.1:8790.
Source edits rebuild automatically; refresh the browser to see changes.
The preview automatically uses the same GitHub CLI login as Dailyglow.
Run `gh auth status` to check it; use Retry connection after fixing a login.
The token stays in the local server and is never sent to browser storage.
The browser preview calls a localhost GitHub API proxy.

## Setup on a fresh checkout

1. `npm install --prefix .tools --no-audit --no-fund bun`
2. `cd upstream && ../.tools/node_modules/.bin/bun install --frozen-lockfile`
3. Return to this directory and run `npm run dev`.

`npm run build` builds the browser app; `npm run typecheck` checks TypeScript.

The editable PullDash source lives in `upstream/`. See UPSTREAM.md for its
pinned source commit and local changes. License and attribution are retained.
Analytics are disabled in this copy. The server listens only on localhost.

## Bundle into Dailyglow

Run `npm run bundle` from this directory, then build/run Dailyglow in Xcode.
This copies the production build (including diff workers and lazy language chunks)
into `Dailyglow/PullDashWeb`, an Xcode folder resource. Repeat after React edits.

The installed app needs no Node, Bun, or `npm run dev`. Its WKWebView loads bundled
assets through an app-owned loopback server, started and stopped with the workspace.
GitHub requests use a native message bridge and the existing `gh` login; credentials
stay in Swift. GitHub CLI must be installed and signed in. A connection screen offers
retry if login is unavailable. External links open in the default browser.

The asset server uses an available port per workspace instance, so web storage is
not guaranteed to persist between launches. Inbox integration is separate.

