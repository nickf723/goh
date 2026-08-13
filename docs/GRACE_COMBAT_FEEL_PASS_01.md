# Grace Combat Feel Pass 01 — Continuous Motion

## Goal

This pass responds to the first recorded Arsenal Dojo gameplay clip rather than expanding combat breadth.

The clip showed that individual actions were increasingly readable, but their boundaries still felt synthetic:

```text
locomotion → attack
attack → contact
contact → recovery
recovery → locomotion / next attack
weapon hit → target response → target recovery
```

The pass therefore improves connective tissue instead of adding mechanics.

Primary scene:

```text
res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn
```

## Grace continuity layer

The dojo player now uses:

```text
res://scripts/visuals/grace_wire_motion_visual_combat_v2.gd
```

This subclasses the existing Grace wire-motion visual. The canonical locomotion, dodge, attack-pose, and combat-footwork systems remain authoritative.

The continuity layer adds only four presentation accents:

1. **Locomotion carry** — entering an attack preserves a small amount of the body's incoming movement posture instead of instantly erasing the stride.
2. **Contact drive** — the active frame adds a small hip/root commitment so the body explains the gameplay movement.
3. **Follow-through and braking** — recovery continues past contact before compressing into a catch step instead of linearly dissolving to neutral.
4. **Residual settle** — after an attack finishes, a short decaying pose tail bridges into locomotion or idle.

The extra accents use the existing `motion_accent_*` bookkeeping so they are removed cleanly before the canonical rig samples the next frame.

## Grounded defender response

`CombatTrainingTarget` now owns a grounded hit-presentation envelope.

A normal grounded weapon hit reads as:

```text
local flinch
→ controlled world displacement
→ visual recovery
```

rather than letting force displacement do all of the presentation work.

Grounded planar knockback is scaled and capped for the training target. Launchers and airborne reactions remain under the existing airborne systems.

This is a presentation/calibration change to the training target, not a rewrite of `ForceReceiver` or the global payload grammar.

## Cleaner attack readability

The Arsenal Dojo reduces the opacity and footprint of its sandbox slash trails. Trails remain useful for attack-direction debugging, but should no longer obscure Grace and the target during motion evaluation.

The underlying authored trail values remain unchanged outside the dojo because the dojo modifies duplicated sandbox weapon resources.

## Calibration sequence

Use Sword first.

Record or play the same short sequence repeatedly:

```text
run toward center target
→ Light
→ Light
→ Heavy
→ dodge
→ run back in
→ Heavy
→ run away
```

Then test one or two contrasting weapons only after the Sword sequence is readable.

## Manual questions

### Grace

- Does running into Light feel continuous rather than like locomotion was switched off?
- Does the body continue through the hit before braking?
- Can you see a catch/settle after Heavy attacks?
- Does attack → locomotion feel less like a pose reset?
- Do buffered combo hits flow without an obvious neutral frame between them?
- Do the feet and hips better explain the root movement?

### Target

- Does contact read before the target starts sliding?
- Are Light hits visibly different from Heavy hits?
- Does ordinary knockback feel controlled rather than ragdoll-like?
- Do launchers still feel allowed to break the grounded response envelope?

### Readability

- Can you see Grace's silhouette through the trail?
- Is contact still obvious without the old large opaque polygon?

## Out of scope

This pass deliberately does not add:

- new weapon classes;
- new attacks or techniques;
- new spell mechanics;
- new enemy AI;
- a replacement animation framework;
- final character models or production animation assets;
- broad balance changes.

## Next decision

If the calibration sequence feels clearly better, promote the continuity principles into the canonical player presentation and repeat the same footage comparison for Dodge, casting, and target recovery.

If it still feels clunky, diagnose the remaining roughness from the same fixed sequence before changing another subsystem.
