# Enemy Classes v1 Test

## Goal

Abstract enemy traits into reusable enemy classes while keeping species-specific definitions readable.

The new shape is:

```text
EnemyClassDefinition
  -> broad archetype traits
  -> movement, vitals, defenses, force behavior, role tags

EnemyDefinition
  -> species identity
  -> references an enemy class
  -> can opt out of class trait groups later for custom overrides

EnemyBrain
  -> applies the effective definition to HitReceiver, ForceReceiver, TagComponent, movement, and debug data
```

## Branch

`agent/enemy-classes-v1`

## New enemy classes

### Brawler

Used by Goblin.

- Baseline melee pressure.
- Medium speed.
- Medium health / stance.
- Weak to fire.

### Skirmisher

Used by Gremlin.

- Fast, fragile, evasive.
- Low health / stance.
- Weak to ice, lightning, and sound.
- Resistant to poison.

### Brute

Used by Zombie.

- Slow and tanky.
- Uses stance-then-health.
- Weak to fire.
- Resistant to poison.

## Test plan

1. Pull branch `agent/enemy-classes-v1`.
2. Run the usual dev scene.
3. Use `F9` / `F10` to select:
   - Goblin Duel
   - Gremlin Duel
   - Zombie Duel
   - Mixed Wave
4. Press `F6` to spawn enemies.
5. Confirm all spawned enemies still move, chase, attack, show HUD bars, and take damage.
6. Confirm class differences:
   - Goblin feels like the baseline brawler.
   - Gremlin is fast and fragile.
   - Zombie is slow and durable.
7. Use Dev Vision if needed and confirm EnemyBrain debug data includes `class`.
8. Hit enemies with elemental spells and confirm weaknesses/resistances apply.

## Expected behavior

- Existing enemies still work.
- Goblin, Gremlin, and Zombie feel more distinct.
- Health/stance values come from class data.
- Tags are merged from class + species definition.
- EnemyBrain debug data shows the active class id.

## Notes

This is architecture first, not final balance. The big win is that future enemies can now be made from reusable archetype pieces instead of copying every stat by hand.
