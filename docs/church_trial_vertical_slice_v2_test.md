# Church Trial Vertical Slice v2

## Goal

Verify the complete connected prototype flow:

```text
entry/save → combat → elemental lock → Sound Reveal bridge → boss checkpoint → Animated Armor → sigil → exit
```

## Entry scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene.

Press `F8` once if an older prototype save is active.

## Full fresh run

1. Confirm the opening objective includes combat, the elemental lock, the echo path, the armor, the sigil, and the exit.
2. Sleep in the Entry Save Bed.
3. Clear the Goblin and Gremlin combat room.
4. Confirm the Combat Gate opens.
5. Activate the Water Lock with Water.
6. Activate the Fire Lock with Fire.
7. Confirm the Element Lock Gate opens.
8. Walk forward through the open gate.
9. Confirm the scene transitions into the Sound Reveal chamber before Grace reaches the old embedded boss room.

## Sound chamber

1. Confirm Sound Pulse is selected automatically.
2. Confirm the destination is visible but the bridge is absent.
3. Cast Sound Pulse.
4. Confirm the orange echo bridge appears with collision.
5. Cross before it fades.
6. Step into the far exit.
7. Confirm the scene transitions to the focused boss finale.

## Boss finale

1. Confirm Grace arrives before the Armor Trial Bed.
2. Confirm the objective asks Grace to rest, defeat the armor, claim the sigil, and leave.
3. Sleep in the Armor Trial Bed.
4. Fight the Animated Armor.
5. Allow Grace to be defeated once after saving.
6. Confirm the finale scene reloads and Grace wakes at the Armor Trial Bed.
7. Defeat the Animated Armor.
8. Confirm the Judgment Gate opens.
9. Walk through the gate and find the Church Trial reward altar.
10. Try the final exit before claiming the sigil.
11. Confirm the exit refuses Grace and asks for the Church Trial Sigil.
12. Claim the sigil from the altar.
13. Confirm resources restore and progress saves.
14. Open the full menu and confirm Inventory lists:

```text
Church Trial Sigil · Trial Relic · First Church Trial
```

15. Step into the final exit.
16. Confirm the Church Trial completes.

## Resume regression

1. Restart the boss-finale scene after claiming the sigil.
2. Confirm Grace resumes from the altar save in the finale scene.
3. Confirm the altar shows the sigil as already claimed.
4. Confirm the final exit still accepts the saved key item.

## Standalone Sound regression

Open the Sound scene directly:

```text
scenes/levels/prototypes/prototype_sound_reveal_bridge_v1.tscn
```

Confirm the bridge reveal, expiry, fall reset, and exit still function. The exit now continues into the boss finale because the room is part of the vertical slice.

## General regression

Across the three scenes, briefly verify:

- movement, camera, jump, and dodge;
- Focus and spell switching;
- HUD resource updates;
- full menu opening and closing;
- save-bed interaction;
- boss attacks and death retry;
- reward persistence and Inventory display.

## Creative review

Judge whether:

- the three-scene sequence feels like one examination despite prototype scene cuts;
- Sound works as a mental pause between combat and the boss;
- the boss finale is compact enough to feel climactic rather than repetitive;
- the sigil feels earned after the complete route;
- objective wording makes the next step clear without sounding like developer instructions.

## Known limitations

- Scene changes are immediate and have no fade or loading presentation.
- The original monolithic scene still contains its old boss geometry beyond the transition, but fresh progression enters the Sound chamber first.
- Prototype geometry, lighting, text, and materials remain temporary.
- No exported Windows build is included in this pass.
