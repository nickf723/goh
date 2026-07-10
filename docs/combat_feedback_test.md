# Combat Feedback v1 Test

## Goal

Make combat outcomes readable without needing the console.

## What to test

Use a branch with this patch:

```txt
agent/combat-feedback-v1
```

Run the usual dev scene.

## Basic hit feedback

1. Select `Goblin Duel`, `Gremlin Duel`, or `Zombie Duel` with `F9` / `F10`.
2. Press `F6` to spawn enemies.
3. Lock on with `R3` / `T`.
4. Cast Firebolt, Ice Lance, Lightning Spark, or Arcane Spark.

Expected:

- A floating damage / stance number appears above the enemy.
- A small burst appears at the enemy.
- Defeating an enemy shows a clear `DEFEATED` popup.
- Breaking stance shows `STANCE BREAK`.

## Status feedback

1. Use Poison Cloud, Fire Field, Ice Lance, or any spell that applies status.
2. Watch the target when the status first applies.

Expected:

- Statuses such as `POISONED`, `BURNING`, `FROZEN`, or `STUNNED` appear above the target.
- Burning and poison ticks show damage feedback over time.

## Miss feedback

1. Lock onto a fast Gremlin.
2. Fire a projectile while it is moving fast enough to dodge or outrun the shot.

Expected:

- If the projectile expires without hitting anything, it shows `MISS` at its final position.

## Combo feedback

1. Use a reaction scenario, such as wet + lightning, wet + ice, or frozen + force.
2. Trigger a reaction.

Expected:

- The reaction name appears above the target.
- Normal hit/status feedback still appears as usual.

## Things to tune later

- Text size.
- Text lifetime.
- Burst size.
- Whether `MISS` is too noisy.
- Enemy-specific feedback styles.
- Real enemy health / stance bars.
