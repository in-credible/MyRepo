FileMaker CLI Helper

Overview
- Bash CLI for FileMaker Data API (list, find, create, update, delete).
- Caches an API token under `fm/.sessions/` and auto-relogins on 401.

Setup
- Requirements: curl, jq, bash.
- Copy `.env.example` to `.env` and fill values:
  - `FM_HOST`, `FM_DB`, `FM_USER`, `FM_PASS`, `FM_LAYOUT`
  - Optional: `FM_INSECURE=1` to skip TLS verification (dev only).

Usage
- Login and verify:
  - `./fm/fm.sh login`
  - `./fm/fm.sh status`
- List layouts:
  - `./fm/fm.sh layouts`
- List records (from `FM_LAYOUT`):
  - `./fm/fm.sh list --limit 10 --offset 1`
- Find records (key=value pairs):
  - `./fm/fm.sh find Status=Open Priority=High`
  - Raw JSON query file: `./fm/fm.sh find --query-file query.json`
- Create a record:
  - `./fm/fm.sh create Name="Acme" Status=Open`
- Update record 123:
  - `./fm/fm.sh update 123 Status=Closed`
- Delete record 123:
  - `./fm/fm.sh delete 123`
- Logout:
  - `./fm/fm.sh logout`

Flags
- `-l, --layout <name>` to override `FM_LAYOUT` per command.
- `-H, --host`, `-d, --db`, `-u, --user`, `-p, --pass` to override `.env`.
- `--insecure` to allow self-signed certs for this invocation.

Notes
- The layout controls which fields are visible/editable via the Data API.
- Tokens expire after inactivity; the script transparently re-authenticates.

