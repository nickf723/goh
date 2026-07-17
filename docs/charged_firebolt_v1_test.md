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
Controller: right input axis 5
```

So the same hold-and-release path should work for keyboard and controller.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene.

## Prototype shortcut

For this branch, the boss dungeon director grants `charged_firebolt` automatically on scene load while running in the editor.

This lets the upgrade be tested immediately without clearing the dungeon first.

The normal Church Trial reward still grants `charged_firebolt` too, so the reward flow remains testable.

## What changed

- `scripts/abilities/ability_caster.gd`
  - Adds Charged Firebolt state.
  - Starts charging when the current spell is Firebolt and Grace has `charged_firebolt`.
  - Polls `Input.is_action_pressed("cast_spell")` so keyboard and controller share the same charge path.
  - Releasing the action fires.
  - Quick taps still fire a normal Firebolt.
  - Held charges create a stronger DamagePayload.
  - Charged shots scale projectile size and speed slightly.
- `scripts/levels/prototype_boss_dungeon_chain.gd`
  - Grants `charged_firebolt` on scene load in the editor for fast prototype testing.
  - Shows a startup/resume message when the shortcut grants the unlock.
- `scripts/interaction/church_trial_reward_altar.gd`
  - Adds `charged_firebolt` to the Church Trial reward unlocks for prototype testing.
- `scripts/systems/unlock_catalog.gd`
  - Updates the Charged Firebolt description and hook list.

## Fast test flow

1. Pull branch `agent/charged-firebolt-v1`.
2. Open the boss dungeon chain scene.
3. Run Current Scene.
4. Confirm the startup or resume message says Charged Firebolt is unlocked for immediate testing.
5. Equip Firebolt.
6. Tap the cast action.
7. Confirm a normal Firebolt fires.
8. Hold the cast action.
9. Confirm the spell label shows `Charging Firebolt` with a percentage.
10. Release after a partial or full charge.
11. Confirm `Charged Firebolt released.` appears.
12. Confirm the projectile appears larger/faster and hits harder.
13. Repeat with controller input.

## Reward flow test

1. Press `F8` for a fresh run if needed.
2. Defeat the Animated Armor.
3. Claim the Church Trial Sigil.
4. Confirm the reward message mentions Firebolt can now be charged.
5. Confirm Charged Firebolt remains listed in the Relics menu.

## Controller test

Use the controller input mapped to `cast_spell`.

```text
press and release quickly -> normal Firebolt
hold input -> charge percent rises
release input -> charged Firebolt fires
```

## Regression checks

- Other spells should still cast on button press.
- Firebolt should not charge before `charged_firebolt` is unlocked outside the prototype shortcut scene.
- Focus menu quick-cast should still cast normally and should not get trapped in charge state.
- Switching spells while charging should cancel the charge cleanly.
- If Grace lacks the extra mana for a charged shot, it should fail with the existing resource message instead of firing for free.

## Known limitations

- The charge indicator uses the existing spell label, not a polished charge meter.
- Charged Firebolt currently uses direct `has_unlock("charged_firebolt")` checks instead of a full declarative Modifier Engine.
- The Church Trial Sigil grants this upgrade for prototype testing; we can move it to a fire-specific reward later.
- The boss dungeon also grants this upgrade immediately in the editor for testing speed.
- I could not run Godot here, so parser and controller validation are needed.
