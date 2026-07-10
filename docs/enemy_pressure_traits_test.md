# Enemy Pressure Traits Test

## Goal

Move attack pressure tuning out of `EnemyBrain` and into enemy class data so each archetype can decide how eagerly it starts trouble.

## What changed

- `scripts/enemies/enemy_class_definition.gd`
  - Adds `attack_commit_time`.
  - Adds `attack_pressure_range_padding`.
- `scripts/enemies/enemy_definition.gd`
  - Adds `use_class_pressure`.
  - Adds species-level pressure overrides.
  - Adds `get_attack_commit_time()`.
  - Adds `get_attack_pressure_range_padding()`.
  - Adds `get_pressure_summary()` for Dev Vision.
- `scripts/enemies/enemy_brain.gd`
  - Removes the local pressure exports.
  - Reads pressure behavior from `EnemyDefinition` / `EnemyClassDefinition`.
  - Adds `pressure` to debug data.
- `data/enemy_classes/*.tres`
  - Brawler, Skirmisher, and Brute now each define their own pressure feel.

## Current class pressure targets

### Brawler

- `attack_commit_time = 0.12`
- `attack_pressure_range_padding = 0.18`
- Goal: steady default pressure.

### Skirmisher

- `attack_commit_time = 0.06`
- `attack_pressure_range_padding = 0.10`
- Goal: fast, twitchy commitment once close enough.

### Brute

- `attack_commit_time = 0.28`
- `attack_pressure_range_padding = 0.22`
- Goal: slower, more readable commitment before the big grab.

## How to test

1. Pull branch `agent/enemy-pressure-traits-v1`.
2. Run the usual dev scene.
3. Spawn `Goblin Duel`.
4. Stand near the Goblin without attacking.
5. Confirm it closes and attacks with normal brawler pressure.
6. Spawn `Gremlin Duel`.
7. Confirm it commits faster once in range.
8. Spawn `Zombie Duel`.
9. Confirm it commits more slowly and still feels readable.
10. Spawn `Mixed Wave`.
11. Confirm the three enemy classes pressure differently in the same fight.
12. Enable Dev Vision and confirm EnemyBrain shows `pressure` values.

## Expected behavior

- Enemy attacks still work.
- Enemies still strike first when close enough.
- Brawler, Skirmisher, and Brute have distinct pressure timing.
- Dev Vision shows pressure tuning per enemy.

## Future use

This opens the door to classes like:

- `Ambusher`: long patience, sudden burst.
- `Berserker`: near-zero commit, very aggressive.
- `Defender`: low pressure padding, waits near guarded positions.
- `Coward`: only commits after Grace is vulnerable or far from safety.
