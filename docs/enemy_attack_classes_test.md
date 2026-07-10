# Enemy Attack Classes Test

## Goal

Abstract what enemies do into reusable attack archetypes.

Enemy species can now use an `EnemyAttackDefinition`, and that attack can inherit its timing, range, cone, cooldown, miss behavior, and default payload from an `EnemyAttackClassDefinition`.

## Branch

`agent/enemy-attack-classes-v1`

## New architecture

```txt
EnemyAttackClassDefinition
  -> broad attack DNA
  -> bite / claw / grab / future lunge / projectile / aura / summon

EnemyAttackDefinition
  -> species-specific attack instance
  -> Goblin Claw / Gremlin Bite / Zombie Grab
  -> may inherit class defaults or override them

EnemyBrain
  -> reads effective attack values through getters
```

## Added attack classes

### Claw

- Delivery: melee.
- Shape: baseline short cone.
- Use case: goblins, beasts, quick melee enemies.
- Current user: Goblin Claw.

### Bite

- Delivery: melee.
- Shape: fast close-range snap.
- Use case: small skirmishers and quick monsters.
- Current user: Gremlin Bite.

### Grab

- Delivery: grab.
- Shape: slower, wider cone.
- Use case: zombies, brutes, grapplers.
- Current user: Zombie Grab.

## How to test

1. Pull branch `agent/enemy-attack-classes-v1`.
2. Run the usual dev scene.
3. Use `F9` / `F10` and `F6` to spawn:
   - `Goblin Duel`
   - `Gremlin Duel`
   - `Zombie Duel`
   - `Mixed Wave`
4. Confirm all enemies still chase and attack.
5. Confirm the feel is intact:
   - Goblin uses a baseline claw pace.
   - Gremlin attacks faster with bite timing.
   - Zombie uses a slower grab with a miss message.
6. Turn on Dev Vision.
7. Confirm EnemyBrain debug data includes:
   - enemy class, such as `brawler`.
   - attack class, such as `claw / melee`.

## Expected behavior

- Existing enemies still fight normally.
- Enemy attack timing still feels distinct.
- Zombie runtime spawning still works.
- New attack resources can be made by referencing an attack class instead of manually copying every timing/payload field.

## Future attack classes

Good next additions:

- `lunge`
- `charge`
- `projectile`
- `beam`
- `burst`
- `shield_bash`
- `summon`
- `heal_ally`
- `explode`
