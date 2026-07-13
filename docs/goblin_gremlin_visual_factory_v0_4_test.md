# Goblin + Gremlin Visual Factory v0.4 QA

## Goal

Verify that the Church Trial common enemies now have distinct, readable visual identities while all existing combat and progression behavior remains intact.

## Primary scene

Run:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Press `F8` in the editor for a fresh route when needed.

## Goblin silhouette

Confirm the Goblin reads as the heavier enemy from the normal gameplay camera:

- broad cloth-covered torso and belly;
- hunched head with long ears and blunt nose;
- visible tusks;
- large hands and boots;
- leather belt and scavenged chest plate;
- crude cleaver in the right hand;
- warm olive, brown, rust, and bone palette.

Its feet should settle near the original sphere collider floor line. The body should remain close enough to the root that lock-on and projectile hits still read correctly.

## Gremlin silhouette

Confirm the Gremlin reads as the smaller, quicker enemy:

- narrow torso;
- long angular arms and legs;
- larger pointed ears;
- visible jaw and fangs;
- clawed hands;
- thin tail;
- cool teal-green skin with violet membrane accents.

The Gremlin must remain visibly different from the Goblin when both are moving and partly obscured by effects.

## Motion and attack telegraphs

### Goblin

1. Let the Goblin chase Grace.
2. Confirm the motion is restrained and weighty rather than twitchy.
3. Enter attack range.
4. Confirm the existing windup flash preserves the authored palette instead of turning every mesh into one flat color.
5. Confirm the torso braces and the cleaver arm raises.
6. Confirm the visual returns cleanly after the attack.

### Gremlin

1. Let the Gremlin chase Grace.
2. Confirm its bob and head movement are quicker than the Goblin's.
3. Enter bite range.
4. Confirm the body crouches, arms spread, and jaw opens during the existing windup.
5. Confirm the authored teal/violet palette remains visible through the flash.
6. Confirm the visual returns cleanly after the attack.

## Gameplay regression

For both enemies, verify that the following remain unchanged:

- spawn positions;
- root scale;
- collision size;
- movement speed and turn speed;
- detection and lose-interest ranges;
- attack pressure, windup, recovery, and cooldown timing;
- damage;
- health and stance;
- fire weakness;
- status effects;
- external force and knockback;
- lock-on selection;
- unlocked projectile hits;
- melee hits;
- defeat behavior;
- encounter-manager room clear and mana reward.

No new attack, phase, loot, or AI behavior belongs in this pass.

## Combat-wing dressing

Before clearing the room, inspect the visual-only dressing:

- entrance and exit arches;
- standing and fallen pillars;
- four braziers;
- side-wall panels;
- gold/violet floor channels;
- encounter ring;
- rubble and broken beams;
- violet overhead fill and warm entrance fill.

The room should communicate damaged sacred architecture occupied by intruders.

## Collision and camera regression

1. Walk through every newly added arch, pillar, fallen-pillar visual, brazier, wall panel, floor line, rubble piece, beam, and encounter ring.
2. Confirm none of the new art blocks or pushes Grace.
3. Confirm the camera does not snag on the new dressing.
4. Confirm projectiles pass through the dressing.
5. Confirm enemies are not trapped or redirected by visual geometry.
6. Confirm the original center cover, oil patch, and water patch still behave normally.

## Material regression

1. Observe both enemies before attacking.
2. Trigger repeated attack windups.
3. Confirm telegraph code duplicates and tints authored `StandardMaterial3D` resources rather than replacing them permanently.
4. Confirm all material colors return after recover and stagger/death reset paths.
5. Confirm emissive eyes remain visible.

## Full-route regression

Complete:

```text
entry/save → Goblin + Gremlin combat → elemental lock → Sound Reveal bridge → Animated Armor → sigil → exit
```

Confirm no save, transition, puzzle, boss, reward, inventory, or exit behavior changed.

## CI and export

The exact PR head must pass:

- custom agent validation;
- Godot 4.6 import;
- title-screen startup;
- Windows release export;
- artifact upload.

Launch the generated Windows artifact and repeat the common-enemy encounter.

## Creative review

Judge whether:

- Goblin and Gremlin are distinguishable instantly;
- each silhouette remains readable during combat;
- the enemies feel like inhabitants of the same visual world as Grace and the Animated Armor;
- they feel like intruders within the Church rather than Church guardians;
- the combat room now bridges the visual quality between the entry and finale;
- either design needs simplification before becoming the template for future enemies.

## Known limitations

- Both enemies remain assembled procedural proxies rather than imported rigged models.
- Poses are transform-based rather than skeletal animation.
- Existing sphere collision and distance/cone attack logic remain unchanged.
- Enemy death still uses the existing immediate disappearance behavior.
- No new particles, audio, UV textures, cinematic camera, or post-processing are included.
