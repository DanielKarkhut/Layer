# Supabase MCP (for Claude Code)

Connects Claude Code to our Supabase project so it can **read** the live
database — tables, functions, RLS policies, Edge Functions — and confirm the
repo matches what's actually deployed.

- **Read-only** (`--read-only`): Claude can inspect and query, never modify.
- **Scoped** to our project only (`--project-ref=fccorlnfoegipybtrdfq`).
- Each person uses their **own** personal access token.
- [`.mcp.json.example`](.mcp.json.example) is committed; your real
  `.mcp.json` (with the token in it) is **gitignored** — never commit it.

## Getting started

1. **Prereqs:** Node/`npx` installed (the server runs via `npx`; first launch
   downloads it).
2. **Generate a personal access token:** https://supabase.com/dashboard/account/tokens
   → *Generate new token* → copy the `sbp_...` value (shown once).
3. **Create your local config:** copy the template and paste your token in.
   ```sh
   cp .mcp.json.example .mcp.json
   ```
   Then edit `.mcp.json` and replace `REPLACE_WITH_YOUR_SUPABASE_ACCESS_TOKEN`
   with your `sbp_...` token. (`.mcp.json` is gitignored, so this stays local.)
4. **Restart Claude Code** and approve the `supabase` server when prompted.
   Putting the token directly in `.mcp.json` means it works whether you launch
   from the app UI or the CLI — no shell-env setup needed.
5. **Verify:** ask Claude to "list the tables." If it answers from the live DB,
   you're set.

## Notes

- Keep it read-only. Widen access only if we both agree.
- Treat the token like a password; rotate it from the tokens page if it leaks.
