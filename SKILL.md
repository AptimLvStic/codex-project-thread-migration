---
name: codex-project-thread-migration
description: Migrate or restore Codex conversations for any local project by scanning Codex session history for a matching workspace cwd, then forking matching threads into the current project while preserving original conversation titles and avoiding pinned state. Use when the user asks to migrate project conversations, recover old API/provider Codex chats, move all conversations belonging to a repo/workspace/project into the current project, or explain/repeat this migration workflow.
---

# Codex Project Thread Migration

## Goal

Migrate Codex conversations that belong to a local project path without editing Codex databases or raw session files. Prefer Codex app thread tools for actual migration; use the bundled scanner only to discover candidates from local session history.

## Workflow

1. Identify the target project path.
   - Default to the current working directory.
   - Use an absolute path and match the normalized `cwd` exactly.
   - Do not use loose substring matching for the final migration set.

2. Discover candidate sessions.
   - Run `scripts/find-project-threads.ps1 -ProjectPath "<absolute-project-path>"`.
   - Review `Id`, `Title`, `FallbackTitle`, `Cwd`, `Archived`, `ThreadSource`, and `File`.
   - The scanner includes both active `sessions` and `archived_sessions` by default because older provider/API threads may be archived but still readable.
   - Include only user project threads unless the user explicitly wants subagent/internal sessions.
   - Exclude the current migration thread unless the user explicitly wants to duplicate it.

3. Preserve original names.
   - Prefer `Title` from `session_index.jsonl` or `read_thread`.
   - If no title exists, derive a short name from the original first user message or preview.
   - Do not prefix migrated titles with labels such as `migrated-` unless the user asks.

4. Migrate with Codex thread tools.
   - Use `fork_thread` with `environment: { type: "same-directory" }` for each source thread.
   - This creates a new project thread in the same directory and preserves completed history.
   - Do not write to `state_*.sqlite`, `logs_*.sqlite`, `session_index.jsonl`, or raw `sessions/*.jsonl`.

5. Post-process each fork.
   - Rename the fork to the preserved original title with `set_thread_title`.
   - Set `pinned=false` with `set_thread_pinned` unless the user requested pinning.
   - Unarchive only when necessary and only through `set_thread_archived`.

6. Verify.
   - Use `read_thread` on every new thread.
   - Confirm the `cwd` equals the target project path.
   - Confirm the title matches the original/fallback title.
   - Report source thread id -> new thread id mappings.

## Safety Rules

- Treat local Codex history as user data. Read it only for discovery, and summarize minimally.
- Do not modify raw Codex history files, SQLite databases, or global state files.
- Do not delete, archive, or rename source threads unless explicitly requested.
- Do not pin migrated threads unless explicitly requested.
- Explain that `fork_thread` copies completed history only; interrupted active turns are not completed by the migration.

## Scanner

Use the bundled script:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\find-project-threads.ps1" -ProjectPath "<absolute-project-path>"
```

Optional parameters:

- `-CodexHome "<path-to-codex-home>"`: override Codex home when it is not `CODEX_HOME`, `%USERPROFILE%\.codex`, or `$HOME/.codex`.
- `-IncludeSubagents`: include subagent/internal sessions.
- `-ActiveOnly`: scan active `sessions` only.

The script outputs JSON suitable for planning the migration.
