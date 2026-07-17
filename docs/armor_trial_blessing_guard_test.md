# Armor Trial Blessing Guard Test

## Goal

Make the first progression modifier actually change gameplay:

```text
claim sigil -> unlock Armor Trial Blessing -> sleep at bed -> gain Guard -> next hit is absorbed
```

This proves the progression framework can turn an unlock into a rule change, not just a saved trophy.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene.

## What changed

- `scripts/systems/game_state.gd`
  - Adds prototype Guard support through dynamic stats:
    - `guard`
    - `max_guard`
  - Adds `apply_rest_unlocks()`.
  - Adds `grant_guard()`.
  - Adds `consume_guard()`.
  - Makes `take_damage()` consume Guard before health.
  - Shows a message when Guard absorbs a hit.
- `scripts/interaction/save_bed.gd`
  - Calls `GameState.apply_rest_unlocks()` after rest restoration.
  - If Grace has `armor_trial_blessing`, sleeping grants 1 Guard.
  - The sleep/save message reports the blessing.
- `scripts/levels/prototype_boss_dungeon_chain.gd`
  - Spawns a `GuardTestGoblin` after Grace has both:
    - `armor_trial_blessing`
    - at least 1 Guard
  - The test goblin appears near Grace so the Guard hit can be tested after the boss is already defeated.

## Main test flow

1. Pull branch `agent/progression-framework-v1`.
2. Open the boss dungeon chain scene.
3. Press `F8` for a fresh run if needed.
4. Defeat the Animated Armor.
5. Claim the Church Trial Sigil.
6. Confirm the reward flow still grants progression normally.
7. Restart the scene or continue to a save bed.
8. Sleep at a save bed.
9. Confirm the bed message includes:

```text
Armor Trial Blessing grants 1 Guard.
```

10. Confirm a `GuardTestGoblin` appears nearby.
11. Let the test goblin hit Grace once.
12. Confirm the message says Guard absorbs the hit.
13. Confirm Grace does not lose health on that hit.
14. Let a second hit land.
15. Confirm normal health damage happens after Guard is consumed.

## Regression checks

- Before claiming the sigil/blessing, sleeping should not grant Guard.
- Before gaining Guard, the Guard Test Goblin should not spawn.
- Pressing `F8` should clear the save and remove the blessing.
- Saving after gaining Guard should preserve the current Guard value.
- Existing save/load, boss retry, and final exit behavior should still work.

## Known limitations

- Guard is currently a prototype dynamic stat, not a polished HUD resource.
- Guard absorbs a whole hit, regardless of hit damage amount.
- The Guard Test Goblin is a prototype test affordance, not final dungeon pacing.
- The modifier hook is direct for now: `has_unlock("armor_trial_blessing")` inside rest handling.
- A later Modifier Engine can generalize this into declarative hooks like `on_sleep` and `on_damage_taken`.
- I could not run Godot here, so parser and scene validation are needed.
