# Summoning Framework v1

Summons are player-owned actors created by equipped summon spells. The framework separates spell metadata, summon definitions, ownership, command state, and the creature itself.

## First summon

Lumen is a spectral familiar with three commands:

- Follow stays near Grace and attacks only her locked target.
- Stay holds its current position and ignores combat.
- Assist follows Grace and independently acquires nearby enemies.

Casting Call Familiar creates Lumen. Casting it again recalls Lumen without creating a duplicate. Defeat starts a recovery cooldown.

## Summon contract

Summon definitions declare identity, scene, active limit, mana cost, recovery time, spawn offset, and roles. PlayerSummonManager owns the active instance and exposes summon, dismiss, recall, and command methods.

This contract can support beasts, animated weapons, turrets, swarms, mounts, and temporary copies without rewriting player input.

## Laboratory

Run:

`scenes/levels/prototypes/prototype_spectral_familiar_lab_v1.tscn`

- Cast: summon or recall Lumen
- J: cycle Follow, Stay, and Assist
- K: dismiss Lumen
- Lock-on: designate a target in Follow mode
- F8: reset

The plate tests positional puzzle commands. The target tests autonomous Assist combat.

## Smoke test

`scenes/tests/summoning_smoke_test.tscn`
