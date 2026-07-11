# Supabase MCP (for Claude Code)

[`.mcp.json`](.mcp.json) connects Claude Code to our Supabase project so it can
**read** the live database — tables, functions, RLS policies, Edge Functions —
and confirm the repo matches what's actually deployed.

- **Read-only** (`--read-only`): Claude can inspect and query, never modify.
- **Scoped** to our project only (`--project-ref=fccorlnfoegipybtrdfq`).
- The config is committed; **your access token is not** — it's read from the
  `SUPABASE_ACCESS_TOKEN` environment variable at runtime.

## Getting started

1. **Prereqs:** Node/`npx` installed (the server runs via `npx`, first launch
   downloads it).
2. **Generate a personal access token:** https://supabase.com/dashboard/account/tokens
   → *Generate new token* → copy the `sbp_...` value (shown once). This is a
   *personal* token — each of us uses our own; never commit it.
3. **Add it to your shell env.** Put it in `~/.zshenv` (loaded by every shell,
   not just interactive ones — `.zshrc` alone won't reach Claude Code):
   ```zsh
   export SUPABASE_ACCESS_TOKEN=sbp_your_token_here
   ```
4. **Restart Claude Code from a terminal** (not the Dock — GUI launches skip
   your shell config), and approve the `supabase` server when prompted.
5. **Verify:** ask Claude to "list the tables" — if it answers from the live DB,
   you're set.

## Notes

- Keep it read-only. Widen access only if we both agree.
- Treat the token like a password; rotate it from the tokens page if it leaks.
