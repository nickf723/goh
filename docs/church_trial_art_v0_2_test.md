# Church Trial Art Vertical Slice v0.2 QA

## Goal

Verify that Grace and the Church entry have a coherent first art pass without changing gameplay behavior.

## Scene

Open:

```text
scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Run Current Scene. Press `F8` first when an old save skips the fresh opening state.

## Grace visual

1. Confirm Grace appears as a young robed explorer rather than the plain debug capsule.
2. Confirm the visible design includes:
   - warm skin;
   - dark hair with a rear silhouette and side locks;
   - weathered cream robe;
   - muted violet sash;
   - small gold brooch;
   - dark boots.
3. Rotate the camera around Grace and confirm the silhouette reads from front, side, and rear angles.
4. Walk and confirm the visual receives a subtle presentation bob and lean.
5. Stand still and confirm the idle motion remains restrained.
6. Confirm the hidden debug capsule does not render during normal play.

## Player regression

Confirm the art wrapper does not alter:

- movement;
- camera orbit and spring arm;
- jumping;
- dodging;
- interaction range;
- Focus and spell selection;
- spell casting;
- light attacks and slash trail;
- save loading and checkpoint placement;
- death retry;
- Inventory and full-menu behavior.

Pay special attention to whether the visible feet agree reasonably with the ground and whether the model fits inside the existing collision capsule.

## Projectile free-aim regression

1. Leave lock-on disabled.
2. Select Firebolt, Water Bolt, Ice Lance, or another projectile spell.
3. Aim the camera forward with its normal slightly downward third-person framing.
4. Cast and confirm the projectile leaves Grace at chest height and travels forward rather than immediately striking the floor.
5. Turn the camera left and right, cast again, and confirm the projectile follows the camera heading.
6. Aim the camera upward and confirm unlocked casts can still travel upward.
7. Lock onto an enemy and cast again.
8. Confirm lock-on continues to aim at the target's center mass.
9. Confirm non-projectile pulses, hazards, movement spells, and other abilities behave as before.

Unlocked projectile casts intentionally ignore downward camera pitch so the standard third-person view does not fire into the floor. Lock-on remains the precise vertical aiming mode.

## Church entry dressing

Before entering combat, inspect the opening room.

Confirm it now contains:

- three layered stone-and-gold arches;
- six modular pillars;
- engraved violet wall panels;
- illuminated floor channels;
- altar frames around the save bed and mana shrine;
- four lit braziers;
- violet ambient fill and warm threshold lighting.

Judge whether the room reads as an intentional sacred trial space rather than a long undecorated corridor.

## Navigation and collision regression

1. Walk the entire opening room perimeter.
2. Walk between the shrine and save bed.
3. Walk around both existing cover blocks.
4. Pass through the threshold into combat.
5. Confirm no new art piece blocks, pushes, catches, or redirects Grace.
6. Confirm camera collision still responds only to gameplay geometry.
7. Confirm enemies and projectiles are not blocked by the new dressing.

All v0.2 kit scenes are visual-only and should add no collision.

## Full dungeon regression

Complete the existing route:

```text
entry/save → combat → elemental lock → Sound Reveal bridge → boss checkpoint → Animated Armor → sigil → exit
```

Confirm:

- combat gates still open;
- element targets still respond;
- the Sound scene transition still triggers;
- the echo bridge still reveals and supports Grace;
- the boss-finale checkpoint still saves and reloads;
- Animated Armor still functions;
- the sigil still saves and appears in Inventory;
- the final exit still completes the trial.

## Title and export regression

Run the project normally and confirm:

- the v0.1 title screen still opens;
- New Trial and Continue still work;
- Controls and Quit remain functional;
- the Windows export pipeline still succeeds.

The release version remains v0.1 during this visual review. Version promotion can happen after the art direction is accepted.

## Creative review

Judge:

- whether Grace feels like the correct age and general personality;
- whether the cream, violet, gold, and dark-hair palette feels right;
- whether her silhouette is too simple, too doll-like, or appropriately stylized;
- whether the Church entry feels solemn without becoming visually muddy;
- whether arches and panels create enough architectural identity;
- whether the warm braziers and violet fill guide the eye effectively;
- which module deserves the next refinement pass.

## Known limitations

- Grace is an assembled low-poly proxy, not a rigged production model.
- Her limbs do not yet use a skeleton or authored animations.
- The practice sword still uses its prototype visual.
- Only the Church entry has been redressed.
- Goblin, Gremlin, Animated Armor, interactables, surfaces, gates, and later rooms remain prototype art.
- No final textures, UVs, facial rig, cloth simulation, post-processing, or bespoke environment models are included.
