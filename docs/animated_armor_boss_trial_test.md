# Animated Armor Boss Trial Test

Branch: `agent/animated-armor-boss-trial-v1`

## Goal

Add a fourth prototype room with a readable mini-boss after the save-bed and death-retry loop.

The intended flow is:

```text
sleep -> save -> combat -> puzzle -> sleep -> boss -> retry if defeated -> final exit
```

## Scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene.

## Test flow

1. Start in the entry room.
2. Sleep in the Entry Save Bed.
3. Clear the combat room.
4. Confirm the combat gate opens.
5. Solve the Fire + Water element lock.
6. Confirm the puzzle gate opens.
7. Sleep in the Armor Trial Bed before the boss room.
8. Enter the boss room.
9. Fight the Animated Armor.
10. Confirm it uses two readable attacks:
    - hammer slam
    - blue magic pulse
11. Let Grace die at least once after sleeping at the Armor Trial Bed.
12. Confirm the scene reloads and Grace wakes at the Armor Trial Bed.
13. Fight the boss again.
14. Defeat the Animated Armor.
15. Confirm the boss exit gate opens.
16. Step onto the final gold exit pad.
17. Confirm the completion message appears.

## Expected behavior

### Save/retry

```text
Grace sleeps at the Armor Trial Bed.
Grace falls during the boss fight.
The scene reloads.
Grace wakes near the Armor Trial Bed.
The boss room resets for another attempt.
```

### Boss readability

The boss should be slow and readable:

```text
Hammer slam = close-range, higher damage, obvious windup
Magic pulse = wider range, lower damage, blue marker
```

### Gate behavior

```text
Boss alive = final blue barrier blocks the exit
Boss defeated = boss collapses and the final gate opens
```

## Tuning questions

- Is the boss too much of a health sponge?
- Is the hammer slam readable enough?
- Is the blue pulse too hard to dodge?
- Does the boss bed feel fair, or too generous?
- Does the final exit feel like a reward?
- Does retrying from the boss bed make the fight less frustrating?

## Known limitations

- Prototype primitive art only.
- No boss health bar yet beyond existing overhead HUD behavior.
- No phase change yet.
- No custom boss music.
- No fade-to-black on death yet.
- Boss arena state resets when retrying, which is intended for this pass.
