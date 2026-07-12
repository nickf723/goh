# Church Trial Room v1 Test

## Goal

This branch adds a small beatable encounter room so the prototype can test actual game flow instead of only systems menus.

```text
Enter room -> fight / use spells -> clear enemies -> gate opens -> reach exit
```

## Scene

```text
res://scenes/levels/prototypes/church_trial_room_v1.tscn
```

For this branch, `project.godot` points the main scene to this room so pressing Play should load it directly.

## Room ingredients

- Player spawn near the back of the room.
- Mana shrine near the starting side.
- Two enemies:
  - Gremlin Drone
  - Goblin Drone
- Oil patch in the center lane.
- Water patch on the left side.
- A few pillars / altar cover pieces.
- Sealed magic gate at the far exit.
- Level exit behind the gate.
- EncounterManager unlocks the gate when enemies are defeated.

## Intended play

1. Press Play.
2. Confirm the objective appears:

```text
Clear the trial room, then reach the exit beyond the sealed gate.
```

3. Fight the enemies.
4. Try using the center oil patch as a fire/combo opportunity.
5. Use the side water patch as a status-cleansing / spacing landmark.
6. Defeat both enemies.
7. Confirm the gate dissolves.
8. Walk through the exit volume.
9. Confirm completion text appears.

## Win condition

The room is cleared when the gate opens and the exit triggers:

```text
Trial cleared. Grace survives the first room.
```

## Failure / tuning notes

If the room is too hard:

- Move enemies farther from the player.
- Replace Goblin + Gremlin with only Gremlin.
- Increase shrine access or reward mana.
- Add another cover block.

If the room is too easy:

- Move enemies closer together.
- Add a second gremlin.
- Move the mana shrine behind the gate.
- Add a hazard near the player start.

## Things to watch

- Does the player understand the objective?
- Does enemy pressure feel readable?
- Does the oil patch matter, or is it ignored?
- Does the gate opening feel like a reward?
- Does reaching the exit feel like a tiny complete level?

## Known limitations

- This is a layout/flow test, not a polished dungeon room.
- The room uses blockout geometry.
- It depends on existing enemy, spell, and encounter behavior.
- I could not run Godot here, so parser/scene testing is needed.
