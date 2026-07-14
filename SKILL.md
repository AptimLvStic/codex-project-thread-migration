---
name: codex-project-thread-migration
description: Restore or synchronize all local Codex conversations after an API, provider, installation, or app migration. Scan active and archived sessions across every workspace, preserve project cwd grouping, titles, archive state, and pinned conversations, and recover only threads missing from the current Codex state. Use when the user asks to sync all Codex chats, pinned chats, project chats, or conversations from an old API/provider, or to migrate one specific project.
---

# Codex Conversation Sync

## Goal

Synchronize local Codex history without editing SQLite databases, global state files, or raw session JSONL. Preserve original thread IDs whenever the current Codex state can already read them; fork only genuinely missing threads.

## Visible Copies (Explicit Opt-In)

Some Codex desktop views show only a subset of readable historical tasks for a project. When the user explicitly asks for additional old tasks to appear in that view, create **visible copies** only after confirming that duplicate task IDs are acceptable.

- This is a presentation recovery mode, not the default synchronization path.
- Limit copies to the requested active user threads. Keep archived sources archived unless the user explicitly asks to surface archive history too.
- Use `fork_thread` with `environment: { type: "same-directory" }`, then set the child title to the source title or fallback title.
- Do not rename, archive, unarchive, delete, or otherwise alter the source thread.
- Record every source ID -> visible-copy ID mapping and verify the new thread's title, cwd, active state, and readability.

## Provider Compatibility

Before asking the user to continue an old task, compare its recorded `ModelProvider` with the providers declared in the active `config.toml`.

- A missing provider name causes resumes to fail even when the historical thread is readable.
- Restore a missing provider alias only when its endpoint and credentials can be safely derived from an existing configured provider or confirmed by the user. Do not invent a URL, model, or credential.
- Parse the updated TOML and confirm that the provider key exists before reporting the old task as resumable.

## Choose Scope

- For all local conversations, projects, archived conversations, and pinned conversations, run the scanner with `-All`.
- For one workspace only, pass `-ProjectPath` with the absolute project path.
- Default to the current working directory when neither option is supplied.

## Workflow

1. Inventory the source history.
   - Run `scripts/find-project-threads.ps1 -All` for a full migration.
   - Review `Id`, `Title`, `FallbackTitle`, `Cwd`, `Archived`, `Pinned`, and `ThreadSource`.
   - Group the results by `Cwd`. Treat each group as its original project/workspace association.

2. Preserve state before creating copies.
   - Use `read_thread` for each source ID. A readable source thread is already registered in the current Codex state and must not be forked.
   - Keep archive state unchanged unless the user asks to unarchive.
   - Restore `Pinned=true` only for source IDs identified by the scanner. Do not pin other threads.

3. Recover only missing threads.
   - If `read_thread` reports that the source ID cannot be found, use `fork_thread` with `environment: { type: "same-directory" }`.
   - Rename the new thread to the original `Title`; use `FallbackTitle` only when no title exists.
   - Set the forked thread's pinned state to the original `Pinned` value.
   - Do not change the source thread, raw session file, SQLite database, or global state file.

   If the user has explicitly authorized visible copies, follow **Visible Copies (Explicit Opt-In)** after this step. Never treat a readable source thread as missing solely because a desktop sidebar does not show it.

4. Verify the sync.
   - Re-read every source or forked thread.
   - Confirm its `cwd` resolves to the original workspace path. Windows may expose this as a `\\?\`-prefixed path; compare normalized paths.
   - Confirm title, archive status, and pin state match the source inventory.
   - Report totals by workspace plus source ID -> restored ID mappings only where a fork was required.

## Safety Rules

- Include active `sessions` and `archived_sessions` in the inventory by default.
- Include only user threads unless the user explicitly asks for subagent/internal sessions.
- Do not duplicate readable source threads.
- Do not delete, archive, unarchive, rename, or unpin source threads unless explicitly requested.
- `fork_thread` copies completed history only. Interrupted active turns cannot be completed by migration.

## Scanner

Full inventory:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\find-project-threads.ps1" -All
```

Single workspace:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\find-project-threads.ps1" -ProjectPath "<absolute-project-path>"
```

Options:

- `-CodexHome "<path-to-codex-home>"`: override the standard Codex home location.
- `-IncludeSubagents`: include subagent/internal sessions.
- `-ActiveOnly`: omit archived session files.
