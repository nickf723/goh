# Church Trial Reward v1 Test

## Goal

Add a real payoff after the Animated Armor boss:

```text
boss defeated -> final gate opens -> reward altar -> Church Trial Sigil -> completion flag -> victory save -> exit
```

This is a prototype reward loop, not final narrative presentation.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene.

## What changed

- Adds `scenes/actors/interactables/church_trial_reward_altar.tscn`.
- Adds `scripts/interaction/church_trial_reward_altar.gd`.
- Updates `scripts/levels/prototype_boss_dungeon_chain.gd` to spawn the altar beyond the boss gate.
- The altar:
  - shows a visible gold / blue sigil reward object
  - prompts `Claim Trial Sigil`
  - sets `completed_church_trial = true`
  - sets `claimed_church_trial_sigil = true`
  - restores health, mana, stamina, and stance
  - autosaves after the reward is claimed
  - hides the sigil and shows a claimed glow after pickup

## Test flow

1. Run the boss dungeon chain scene.
2. Sleep in the entry save bed.
3. Clear the combat room.
4. Solve the Fire + Water lock.
5. Sleep in the Armor Trial Bed.
6. Defeat the Animated Armor.
7. Confirm the final boss gate opens.
8. Walk beyond the boss gate.
9. Confirm the reward altar is visible before the final exit pad.
10. Walk into the reward altar interaction area.
11. Confirm the prompt says `Claim Trial Sigil`.
12. Interact with the altar.
13. Confirm the message says Grace claims the Church Trial Sigil.
14. Confirm the blue sigil visual disappears and the claimed glow appears.
15. Confirm resources are restored.
16. Stop and run the same scene again.
17. Confirm Grace resumes from saved progress near the altar.
18. Step onto the final exit pad.
19. Confirm the Church Trial completion message appears.

## Expected result

The dungeon should now feel like it has a complete reward cadence:

```text
challenge -> boss -> gate -> altar -> sigil -> save -> exit
```

The altar should be optional in code, but visually placed so it naturally reads as the prize before the final exit.

## Known limitations

- The sigil is a primitive blue sphere for now.
- There is no inventory item screen yet.
- The flags exist in GameState through normal dynamic story flags, but there is not yet a dedicated quest journal UI.
- Autosave uses the current one-slot save system.
- The final exit does not require the sigil yet.
- I could not run Godot here, so parser and scene validation are needed.
