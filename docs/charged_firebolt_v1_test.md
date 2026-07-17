# Charged Firebolt v1 Test

## Goal

Make the first active spell upgrade real:

```text
unlock Charged Firebolt -> hold cast -> charge Firebolt -> release -> stronger projectile
```

This proves that progression modifiers can change an existing spell, not only add passive rules like Guard.

## Why controller matters

The implementation uses Godot's existing `cast_spell` input action rather than a hardcoded keyboard key.

Current project mapping already includes:

```text
Keyboard: Q
Controller: right trigger / joypad axis 5
```

So the same hold-and-release path should work for keyboard and controller.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene.

## What changed

- `scripts/abilities/ability_caster.gd`
  - Adds Charged Firebolt state.
  - Starts charging when the current spell is Firebolt and Grace has `charged_firebolt`.
  - Polls `Input.is_action_pressed("cast_spell")` so keyboard and controller share the same charge path.
  - Releasing the action fires.
  - Quick taps still fire a normal Firebolt.
  - Held charges create a stronger DamagePayload.
  - Charged shots scale projectile size and speed slightly.
- `scripts/interaction/church_trial_reward_altar.gd`
  - Adds `charged_firebolt` to the Church Trial reward unlocks for prototype testing.
- `scripts/systems/unlock_catalog.gd`
  - Updates the Charged Firebolt description and hook list.

## Main test flow

1. Pull branch `agent/charged-firebolt-v1`.
2. Open the boss dungeon chain scene.
3. Press `F8` for a fresh run if needed.
4. Defeat the Animated Armor.
5. Claim the Church Trial Sigil.
6. Confirm the reward message mentions Firebolt can now be charged.
7. Equip Firebolt.
8. Tap the cast action.
9. Confirm a normal Firebolt fires.
10. Hold the cast action.
11. Confirm the spell label shows `Charging Firebolt` with a percentage.
12. Release after a partial or full charge.
13. Confirm `Charged Firebolt released.` appears.
14. Confirm the projectile appears larger/faster and hits harder.
15. Repeat with controller right trigger.

## Controller test

Use the right trigger mapped to `cast_spell`.

```text
press and release quickly -> normal Firebolt
hold trigger -> charge percent rises
release trigger -> charged Firebolt fires
```

## Regression checks

- Other spells should still cast on button press.
- Firebolt should not charge before `charged_firebolt` is unlocked.
- Focus menu quick-cast should still cast normally and should not get trapped in charge state.
- Switching spells while charging should cancel the charge cleanly.
- If Grace lacks the extra mana for a charged shot, it should fail with the existing resource message instead of firing for free.

## Known limitations

- The charge indicator uses the existing spell label, not a polished charge meter.
- Charged Firebolt currently uses direct `has_unlock("charged_firebolt")` checks instead of a full declarative Modifier Engine.
- The Church Trial Sigil grants this upgrade for prototype testing; we can move it to a fire-specific reward later.
- I could not run Godot here, so parser and controller validation are needed.
