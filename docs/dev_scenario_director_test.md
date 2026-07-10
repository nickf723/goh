# Dev Scenario Director Test

This branch upgrades `DevSandboxDirector` from a single F6 test wave into a small scenario selector.

## New controls

```txt
F6  spawn the selected scenario
F7  clear dev-spawned enemies
F8  run DevAuditManager
F9  next scenario
F10 previous scenario
```

## Starter scenarios

```txt
Mixed Wave
Goblin Duel
Gremlin Duel
Zombie Duel
Zombie Pair
Dodge Timing
```

## How to test

1. Pull branch `agent/dev-scenario-director-v1`.
2. Run the usual dev scene.
3. Watch the output panel for the printed scenario list.
4. Press `F9` and `F10` to change scenarios.
5. Press `F6` to spawn the selected scenario.
6. Press `F7` to clear spawned enemies.
7. Press `F8` to run the audit.

## Expected behavior

- F6 no longer blindly spawns the same default platter every time.
- F9/F10 rotate through scenario names.
- The selected scenario prints before spawning.
- Existing Goblin/Gremlin scene assignments still work.
- Runtime zombie scenarios still use `DevRuntimeEnemyFactory`.
