# Church Trial Vertical Slice Test

## Scene

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

This is the integrated playable route and the production-facing regression target for the current prototype.

## Purpose

Validate that Grace can move through the Church of Angels trial from entry to exit while the shared combat, spell, interaction, reaction, save, and boss systems remain coherent.

## Core route

1. Start the Church Trial scene.
2. Confirm Grace spawns with movement, camera, UI, spells, and weapon combat available.
3. Follow the opening objective and enter the elemental test route.
4. Exercise interactables and room transitions.
5. Fight the ordinary enemies with both weapons and spells.
6. Confirm elemental locks and reaction-dependent objects still respond.
7. Use Sound to reveal the hidden bridge or reveal target.
8. Reach and defeat the Animated Armor boss.
9. Claim the Church Trial Sigil.
10. Use the exit and confirm the completion path resolves.

## Combat regression

- LIGHT and HEAVY attacks resolve through the current weapon-combat framework.
- Stamina is spent normally.
- Spell casting spends Mana normally.
- Dodge, Focus, lock-on, spell selection, and weapon attacks do not leave permanent action locks.
- Goblin and Gremlin behavior, telegraphs, hit reactions, status effects, force, and death remain functional.
- Frozen plus force can still produce Shatter where the current reaction rules apply.

## Progression and save regression

1. Use a valid Church Trial save point.
2. Confirm the save records the current scene, bed position, stats, story flags, and key items.
3. Return to the title scene.
4. Use Continue.
5. Confirm Grace resumes from the expected saved state.
6. Complete the boss and reward sequence.
7. Confirm the Church Trial Sigil appears as a key item and is not duplicated.

## Presentation checks

- Church art dressing does not create invisible collision.
- Goblin and Gremlin feet remain grounded.
- Enemy telegraph flashes preserve authored materials.
- Animated Armor remains readable from the gameplay camera.
- Objectives, reaction labels, messages, and boss feedback remain legible.

## Reset and failure checks

- Defeat and respawn restore a playable state.
- F8 development reset works where the active prototype supports it.
- Restarting the scene does not retain temporary laboratory values.
- `Engine.time_scale` returns to `1.0` after leaving Focus or a test scene.

## Known limitations

- Prototype and procedural assets remain replacement-ready.
- Final audio, cinematics, authored animation, difficulty tuning, and accessibility options are not represented.
- This document validates the current vertical slice, not the eventual complete first dungeon.
