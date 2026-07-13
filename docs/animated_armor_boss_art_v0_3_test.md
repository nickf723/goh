# Animated Armor and Boss Chamber Art v0.3 QA

## Goal

Verify that the Church Trial finale reads as an intentional sacred boss encounter while preserving every proven gameplay and progression contract.

## Scene

Open and run:

```text
scenes/levels/prototypes/prototype_church_trial_boss_finale_v1.tscn
```

For a complete regression, start fresh from:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

## Animated Armor silhouette

1. Inspect the boss from the normal gameplay camera before entering detection range.
2. Confirm it reads as an empty ceremonial suit rather than a stack of boxes.
3. Confirm the visible shell includes:
   - hollow charcoal helmet;
   - violet eyes and judgment core;
   - layered chestplate with gold bands;
   - oversized pauldrons;
   - separated gauntlets and greaves;
   - heavy two-faced judgment hammer;
   - violet and pale rune accents.
4. Confirm the feet settle near the floor after gravity resolves.
5. Confirm the torso remains reasonably aligned with the existing capsule and overhead health display.
6. Confirm shoulder and hammer overhangs do not change collision.

## Chamber dressing

Before engaging the boss, inspect the complete room.

Confirm the visual-only dressing includes:

- framed save-bed alcove;
- ceremonial entrance arch;
- paired approach channels;
- six arena pillars;
- four warm braziers;
- thin judgment dais and concentric floor sigils;
- large halo behind the boss;
- framed Judgment Gate;
- framed reward altar;
- framed final exit;
- cool violet arena light and warmer reward light.

Judge whether the room clearly communicates this sequence:

```text
prepare → face judgment → pass the gate → claim the sigil → leave
```

## Collision and camera regression

1. Walk around the save bed and entrance arch.
2. Circle the full arena perimeter.
3. Walk through every visible pillar, brazier, sigil line, halo projection, and altar frame location that does not already contain gameplay collision.
4. Confirm new visual dressing never blocks, pushes, catches, or redirects Grace.
5. Confirm the camera does not snag on visual-only art.
6. Confirm projectiles pass through visual-only dressing and still strike the boss.
7. Confirm lock-on still selects the boss and aims near its center mass.

## Boss behavior regression

Confirm the following values feel unchanged:

- detection distance;
- chase speed;
- melee range;
- pulse range;
- melee and pulse damage;
- attack windup timing;
- recovery and cooldown timing;
- health and stance;
- fire and lightning weakness;
- poison and dreams resistance.

The art pass must not introduce a new attack, phase, or balance change.

## Windup readability

### Melee

1. Move into melee range.
2. Confirm the boss announces and raises the judgment hammer.
3. Confirm the hammer, right arm, shoulders, torso, and helmet create a clear overhead-slam silhouette.
4. Dodge outside melee range during the existing windup.
5. Confirm the slam misses exactly as before.

### Pulse

1. Remain inside pulse range but outside melee range.
2. Confirm the boss opens both arms.
3. Confirm the chest core and two rings expand visibly.
4. Confirm the floor pulse marker still expands.
5. Move outside pulse range during the existing windup.
6. Confirm the pulse misses exactly as before.

The two windups should be distinguishable before reading the UI message.

## Defeat presentation and reward ownership

1. Note Grace's mana immediately before the final damaging hit.
2. Defeat the boss.
3. Confirm boss collision disables immediately and does not trap Grace.
4. Confirm the armor visibly sinks, tilts, separates, and loses its core over roughly 1.35 seconds.
5. Confirm the Judgment Gate unlocks exactly once.
6. Confirm the boss remains visible for the collapse before being freed.
7. Confirm Grace receives the `HitReceiver` mana reward exactly once, not once from each script.
8. Confirm no second gate message or reward appears after the delayed cleanup.

## Save and progression regression

1. Sleep at the Armor Trial Bed.
2. Die once and confirm retry returns Grace to that bed.
3. Defeat the boss and pass through the Judgment Gate.
4. Claim the Church Trial Sigil.
5. Open Inventory and confirm the sigil appears.
6. Restart the project and choose Continue.
7. Confirm the saved scene, checkpoint, resources, objective, and sigil persist.
8. Use the final exit and confirm trial completion.

## Full route regression

Complete:

```text
entry/save → combat → elemental lock → Sound Reveal bridge → boss checkpoint → Animated Armor → sigil → exit
```

Confirm no earlier room, transition, spell, enemy, save, or reward behavior changed.

## CI and export

GitHub Actions validates the exact PR head before review.

The workflow covers:

- custom agent validation;
- Godot 4.6 project import;
- title-screen startup;
- Windows release export;
- artifact upload.

Artifact:

```text
GraceOfHumanity-v0.1.0-windows
```

Launch the generated Windows artifact and repeat at least the boss-finale portion.

## Creative review

Judge:

- whether the boss feels important enough for the current prototype climax;
- whether it reads as a Church instrument of judgment rather than generic fantasy armor;
- whether charcoal, gold, violet, and pale rune materials match Grace and the Church entry;
- whether the large halo frames the boss cleanly from the gameplay camera;
- whether the chamber is dramatic without obscuring navigation or attack tells;
- whether the defeat presentation feels ceremonial rather than merely delayed.

## Known limitations

- The boss remains an assembled procedural proxy rather than a rigged imported model.
- Motions are transform-based presentation poses, not skeletal animations.
- Existing attack hit logic remains distance-based rather than hammer-volume based.
- Existing room walls, floor, save bed, gate, reward altar, and exit retain prototype models beneath the new dressing.
- No new audio, particles, UV textures, authored animation, cinematic camera, or post-processing is included.
