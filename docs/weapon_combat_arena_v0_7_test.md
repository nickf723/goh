# Weapon Combat Arena v0.7 — Stance Break and Critical Test

Run:

```text
scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn
```

## Player-facing goal

The existing Sword, Hammer, and Spear combat now supports a complete stance loop:

```text
Weapon pressure
→ stance depletion
→ timed stagger and critical opening
→ one weapon critical
→ stance recovery
```

No new input is required. Use the configured semantic `LIGHT` and `HEAVY` actions.

## Core test

1. Equip the Practice Sword.
2. Attack a training totem until its blue stance bar reaches zero.
3. Confirm `STANCE BREAK` appears and the target receives the `STAGGERED` status.
4. Attack again before the opening closes.
5. Confirm the strike produces a gold `CRITICAL STRIKE` burst, longer hit stop, health damage, and a restored stance bar.
6. Break the stance again, but do not attack.
7. Confirm the opening expires after about three seconds and stance returns without health damage.

## Live enemy test

Fight the rear Goblin and Gremlin.

Confirm:

- weapon hits deplete stance before damaging health;
- stance break interrupts enemy action through the shared `staggered` status;
- the enemy does not attack during the critical opening;
- the next valid weapon melee strike consumes the opening;
- a missed swing does not consume the opening;
- the enemy recovers if Grace does not capitalize;
- defeated enemies still disappear and reset normally.

## Weapon identities

### Practice Sword

- Balanced stance pressure.
- `2.2×` critical damage.
- Flexible Light/Heavy branches remain unchanged.

### Training Hammer

- Highest stance pressure and fastest route to a break.
- Lower `1.75×` critical multiplier because the weapon already owns the break phase.
- Heavy force, Shatter tags, commitment, and broad geometry remain unchanged.

### Training Spear

- Lowest stance pressure.
- Highest `3×` critical multiplier.
- Long, narrow attacks should reward positioning during the short opening.

## Stance regeneration

Partially damage a stance bar, then stop attacking.

Confirm:

- regeneration waits roughly 2.25 seconds after the latest stance hit;
- the stance bar then refills gradually;
- continued pressure resets the delay;
- stance does not regenerate during the critical window.

## Existing combat regression

Confirm:

- Light/Heavy input buffering and branch selection still work;
- normal hit geometry and one-hit-per-target behavior remain unchanged;
- spell and dodge cancel windows remain unchanged;
- weapon racks, lock-on, force, status reactions, and reset still work;
- reset restores Grace, targets, enemies, resources, weapon, lock-on, and combo state;
- the Church Trial remains completable with the Practice Sword.

## Automated coverage

`weapon_moveset_smoke_test.tscn` now verifies:

- all existing moveset graphs and payload tags;
- weapon critical identity ordering;
- critical multipliers entering built payloads;
- stance depletion opening the timed vulnerability;
- weapon melee consuming the opening;
- multiplied health damage;
- stance restoration after a critical or an expired opening.

## Known limitations

- Critical strikes reuse the attack that lands during the opening instead of playing a bespoke execution animation.
- Boss-specific break rules, backstabs, blocking, parrying, and aerial criticals are deferred.
- Current values are prototype tuning and require playtest judgment.
