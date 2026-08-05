# Church Trial Vertical Slice Test

## Scene

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

This is the integrated playable route and the production-facing regression target for the current prototype.

## Purpose

Validate that Grace can move through the Church of Angels trial from entry to exit while the shared combat, spell, Soul Grip, mechanism, reaction, save, and boss systems remain coherent.

## Core route

1. Start the Church Trial scene.
2. Confirm Grace spawns with movement, camera, UI, spells, Soul Grip, and weapon combat available.
3. Follow the opening objective and enter the combat route.
4. Clear the Goblin and Gremlin encounter.
5. Enter the Chamber of Accord.
6. Use Soul Grip to place offering `V` on the left scale and offerings `II + III` on the right scale.
7. With the scales balanced, cast Water and then Fire at the two rite altars.
8. Confirm the completed chamber seal opens permanently.
9. Use Sound to reveal the hidden bridge or reveal target in the next trial.
10. Reach and defeat the Animated Armor boss.
11. Claim the Church Trial Sigil.
12. Use the exit and confirm the completion path resolves.

## Chamber of Accord regression

- All three offerings are Soul-Grippable and retain their authored masses.
- Unequal scale loads do not power the rite.
- The balanced arrangement is `V = II + III`.
- Fire before Water clears the elemental attempt.
- Losing balance before the rite completes clears partial sequence progress.
- Water followed by Fire completes the rite.
- Completion latches so moving offerings afterward cannot close the passage.
- The completion story flag survives a save and reload.
- Offering transforms, current mass, and unfinished elemental progress do not persist.
- F8 clears the prototype save and restores the fresh room state.

Focused instructions:

```text
docs/church_trial_chamber_of_accord_v1_test.md
```

## Combat regression

- LIGHT and HEAVY attacks resolve through the current weapon-combat framework.
- Stamina is spent normally.
- Spell casting spends Mana normally.
- Dodge, Focus, lock-on, spell selection, Soul Grip, and weapon attacks do not leave permanent action locks.
- Goblin and Gremlin behavior, telegraphs, hit reactions, status effects, force, and death remain functional.
- Frozen plus force can still produce Shatter where the current reaction rules apply.

## Progression and save regression

1. Use a valid Church Trial save point.
2. Confirm the save records the current scene, bed position, stats, story flags, and key items.
3. Return to the title scene.
4. Use Continue.
5. Confirm Grace resumes from the expected saved state.
6. If the Chamber of Accord was completed before saving, confirm its passage remains open.
7. Complete the boss and reward sequence.
8. Confirm the Church Trial Sigil appears as a key item and is not duplicated.

## Presentation checks

- Church art dressing does not create invisible collision.
- Chamber runes, offering marks, altar order, and floor channels are readable without laboratory debug labels.
- Goblin and Gremlin feet remain grounded.
- Enemy telegraph flashes preserve authored materials.
- Animated Armor remains readable from the gameplay camera.
- Objectives, reaction labels, messages, and boss feedback remain legible.

## Reset and failure checks

- Defeat and respawn restore a playable state.
- F8 development reset clears the prototype save and the Chamber completion flag.
- Restarting the scene does not retain temporary scale or elemental-sequence state.
- `Engine.time_scale` returns to `1.0` after leaving Focus or a test scene.

## Known limitations

- Prototype and procedural assets remain replacement-ready.
- Final audio, cinematics, authored animation, difficulty tuning, and accessibility options are not represented.
- This document validates the current vertical slice, not the eventual complete first dungeon.
