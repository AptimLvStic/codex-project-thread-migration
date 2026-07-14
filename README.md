# Codex Conversation Sync

A reusable Codex skill for restoring or synchronizing local Codex conversations after an API, provider, installation, or app migration.

It inventories active history, archived history, project/workspace grouping, and pinned conversations. It keeps readable source threads intact and only forks threads that are genuinely missing from the current Codex state.

## What It Preserves

- Original workspace (cwd) grouping for project conversations.
- Existing thread IDs whenever Codex can already read them.
- Original titles, with a fallback derived from the first user message.
- Archived state.
- Pinned conversations, including restored pins that may exist only in current app state.

## Usage

Synchronize all local conversations:

~~~
Use $codex-project-thread-migration to sync all local Codex conversations, project chats, archived chats, and pinned chats.
~~~

Inventory all local history:

~~~powershell
powershell -ExecutionPolicy Bypass -File "scripts\find-project-threads.ps1" -All
~~~

Inventory one workspace:

~~~powershell
powershell -ExecutionPolicy Bypass -File "scripts\find-project-threads.ps1" -ProjectPath "<absolute-project-path>"
~~~

## Safety

The skill does not edit Codex SQLite databases, global state files, or raw session JSONL files. It avoids duplicate forks by first checking whether the source thread is already readable in the current Codex state.

A fork carries completed history only; interrupted active turns cannot be completed by migration.