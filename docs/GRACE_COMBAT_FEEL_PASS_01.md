# Grace Combat Feel Pass 01 — Continuous Motion

## Goal

This pass responds to recorded Arsenal Dojo gameplay rather than expanding combat breadth.

The first clip showed that individual actions were increasingly readable, but their boundaries still felt synthetic:

```text
locomotion → attack
attack → contact
contact → recovery
recovery → locomotion / next attack
weapon hit → target response → target recovery
```

A follow-up playtest exposed a second issue: Grace looked like she was swinging a sword **near** an enemy rather than attacking that enemy as a participant in one shared event.

The pass therefore improves connective tissue and target engagement instead of adding mechanics.

Primary scene:

```text
res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn
```

## Grace continuity layer

The dojo player uses:

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

`WeaponRecoveryPresenter` also captures the final ordinary weapon-pivot pose before the controller resets it and eases the prop home when no buffered follow-up has already begun. Runtime flexible rigs keep ownership of their own recovery.

## Target-coupled Sword engagement

The dojo `CombatWeaponControllerV2` now assigns one **engagement target** when a grounded Sword attack begins.

It reuses existing targeting sources in this order:

```text
hard lock
→ targeting-assist hard target
→ soft aim target
→ existing facing-assist candidate
```

No new target is selected after the attack commits.

The engagement target is shared by three existing layers:

### Heading

Sword attack heading is biased toward the committed target only when the target begins within the existing turn allowance. This keeps attack geometry, visual facing, and footwork on the same line without unrestricted homing.

### Spacing

Instead of always applying the attack resource's full forward lunge, the dojo computes how much distance Grace actually needs to close to a useful Sword pocket.

```text
already close → tiny weight shift / plant
slightly outside pocket → bounded catch-up step
too far away → ordinary attack, no magnetic teleport
```

This is still the existing combat-motion / footwork pipeline. The change only supplies a target-aware requested distance.

### Body commitment

`CombatEngagementPresenter` reads the same engagement target and adds a small chest/weight bias through Grace's existing motion-accent bookkeeping.

It does not introduce a second skeletal animator and does not permanently modify the canonical pose.

The intent is that Grace's body communicates **who she is attacking**, while the Sword remains the endpoint of that action.

## Paired defender response

The Arsenal Dojo uses a testing-only target variant:

```text
res://scenes/actors/testing/combat_training_target_engaged.tscn
```

The base `CombatTrainingTarget` still owns grounded flinch, damped world displacement, airborne handoff, and recovery.

The engaged variant adds attacker-defender coupling:

- broad Sword cuts twist/recoil the target with the lateral direction of the cut;
- thrust-like attacks remain mostly axial;
- launchers still hand visual authority to the existing airborne presentation stack.

This gives one contact a shared visual cause-and-effect relationship instead of playing an attacker animation and defender animation independently.

## Grounded defender response

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

Also deliberately try the first Light from three spacings:

```text
very close
normal striking distance
just outside striking distance
```

The useful comparison is whether Grace looks like she is entering the enemy's space intentionally rather than replaying the same lunge at all three distances.

Then test one or two contrasting weapons only after the Sword sequence is readable.

## Manual questions

### Grace

- Does running into Light feel continuous rather than like locomotion was switched off?
- Does the body continue through the hit before braking?
- Can you see a catch/settle after Heavy attacks?
- Does attack → locomotion feel less like a pose reset?
- Do buffered combo hits flow without an obvious neutral frame between them?
- Do the feet and hips better explain the root movement?
- Does Grace visibly commit toward a target instead of merely swinging in its neighborhood?
- Does close-range Sword footwork stop sliding her through the target?
- Does a slightly distant target produce a believable bounded approach rather than a teleport/homing lunge?

### Target

- Does contact read before the target starts sliding?
- Are Light hits visibly different from Heavy hits?
- Does ordinary knockback feel controlled rather than ragdoll-like?
- Does a lateral Sword cut rotate/recoil the target in the direction of the cut?
- Do thrusts remain centerline/axial?
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
- unrestricted melee magnetism or homing;
- a replacement animation framework;
- final character models or production animation assets;
- broad balance changes.

## Automated regression

```text
res://scenes/tests/grace_combat_feel_pass_01_smoke_test.tscn
```

The test checks continuity/settle presentation, target engagement acquisition, target-aware approach calculation, the engagement presenter, the paired training-target reaction, and the reduced dojo trail settings.

GitHub Actions may not execute while the repository Actions budget is exhausted. A workflow failure with no job steps and an Actions-budget annotation is infrastructure-only, not a Godot test result.

## Next decision

If the calibration sequence now feels like **Grace attacking a target**, promote these target-engagement principles into the canonical player presentation and then repeat the same footage comparison with a real enemy.

If it still feels like a weapon animation playing near an enemy, the next likely limitation is the prototype character rig itself: shoulder/hand reach, grip alignment, and lack of true contact-aware skeletal animation or IK.
