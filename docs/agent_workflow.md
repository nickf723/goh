# Agent Development Workflow

This repo is set up for a faster assistant-driven Godot workflow.

## Loop

1. Nick gives a task, such as `make zombies`, `make a spell`, `build a prototype room`, or `refactor abilities`.
2. The assistant inspects the relevant repo files.
3. The assistant creates a branch named like `agent/<task-name>`.
4. The assistant edits scripts/resources/docs directly in GitHub.
5. Nick pulls the branch in GitHub Desktop and tests in Godot.
6. Nick reports Godot errors, console output, and DevAudit output.
7. The assistant patches the branch until the feature is clean.
8. Nick merges when the feature works.

## Branch naming

Use short task branches:

```txt
agent/zombie-v1
agent/spell-sound-resonance
agent/room-controller-v1
agent/dev-factory-v1
```

## Commit style

Prefer small, readable commits:

```txt
Add zombie enemy resources
Add zombie behavior tuning
Fix zombie audit warnings
```

## Safety rules

- Keep `main` as the latest working baseline.
- Pull before testing a branch.
- Commit working local changes before asking the assistant to patch the same files.
- Use DevAuditManager after each pull.
- For generated scenes/resources, expect one test cycle because Godot may rewrite `.tscn` and `.tres` metadata.

## Current dev hotkeys

```txt
F6: Spawn test wave
F7: Clear spawned enemies
F8: Run DevAuditManager
```

## Preferred feature packet format

Each agent task should include:

```txt
Goal:
Files changed:
How to test:
Expected DevAudit result:
Known risks:
```

## First-class automation targets

These are the next systems that should make development faster:

1. `DevAuditManager` expansion for project health checks.
2. `DevSandboxDirector` expansion for prototype spawning and test scenarios.
3. Enemy factory helpers for data-driven enemies.
4. Ability factory helpers for data-driven spells.
5. Receiver installer/auditor for standard component stacks.
6. Prototype room spawner once room-building feels less fiddly.
