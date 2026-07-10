# Dev Scenario Director Summary

`DevSandboxDirector` now acts as a tiny scenario selector instead of only a single test-wave spawner.

## Controls

```txt
F6  spawn selected scenario
F7  clear spawned enemies
F8  run DevAuditManager
F9  next scenario
F10 previous scenario
```

## Scenarios

- Mixed Wave: Goblin + Gremlin + Zombie
- Goblin Duel: one Goblin
- Gremlin Duel: one Gremlin
- Zombie Duel: one Zombie
- Zombie Pair: two Zombies
- Dodge Timing: one Zombie tuned through existing zombie behavior

## Why this matters

Future agent tasks can add a named scenario alongside the feature itself. For example, a new spell can ship with a spell test scenario, and a new enemy can ship with a duel scenario.
