# Codex Project Thread Migration

A reusable Codex skill for migrating local Codex conversations that belong to a project workspace.

The skill scans Codex session history for threads whose `cwd` matches a target project path, then guides Codex to fork those threads into the current project while preserving original titles and avoiding pinned state.

## What It Does

- Finds Codex conversations by exact project workspace path.
- Includes both active sessions and archived sessions by default.
- Preserves original thread titles when migrating.
- Uses Codex thread tools instead of editing raw databases or session files.
- Keeps migrated threads unpinned unless explicitly requested.
- Reports source thread IDs and new migrated thread IDs.

## When To Use

Use this skill when you need to:

- Move conversations from an old Codex API/provider setup into the current project.
- Restore project conversations that still exist in local Codex session history.
- Collect all conversations belonging to a repo or workspace into one Codex project.
- Repeat a safe, auditable project-thread migration workflow.

## Skill Contents

```text
codex-project-thread-migration/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    └── find-project-threads.ps1
```

## Usage

Invoke the skill in Codex:

```text
Use $codex-project-thread-migration to migrate all Codex conversations for this project into the current project.
```

The bundled scanner can also be run directly:

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\find-project-threads.ps1" -ProjectPath "<absolute-project-path>"
```

Optional scanner parameters:

- `-CodexHome "<path-to-codex-home>"`
- `-IncludeSubagents`
- `-ActiveOnly`

## Safety Notes

This skill is designed to avoid destructive operations:

- It does not edit Codex SQLite databases.
- It does not modify raw session JSONL files.
- It does not delete, archive, or rename source threads unless explicitly requested.
- It uses `fork_thread` so the original conversations remain intact.

`fork_thread` copies completed history only. Interrupted or unfinished active turns are not completed by migration.