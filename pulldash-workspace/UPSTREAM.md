# PullDash source provenance

- Source: https://github.com/coder/pulldash
- Commit: 1fd065eb179ad26e46e08194e287aac432268149
- Imported: 2026-09-27
- License: AGPL-3.0-only; retained in upstream/LICENSE

The upstream folder is a vendored source copy, not a submodule.
Local changes: disable analytics; bind development server to localhost:8790.

Authentication customization: removed PullDash OAuth/PAT UI and endpoints;
replaced with a localhost-only GitHub CLI session bridge, connection status,
and REST/GraphQL transport. Swift and inbox files are unchanged.

Removed Electron entry point, packaging configuration, release workflow, desktop
build/icon scripts and dependencies. Removed unused PostHog dependency.

Removed unused bookmarklet, API client wrapper, Vercel entry point/config/build,
upstream PR maintenance scripts, original placeholder, and Add Repo UI logic.
