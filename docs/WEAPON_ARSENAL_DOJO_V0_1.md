# Grace of Humanity — Weapon Arsenal Dojo v0.1

## Purpose

The Arsenal Dojo is the combat equivalent of the Trial Chamber format: a small controlled space where the same player, targets, camera, resources, and enemy options can be used to compare weapon classes without open-world noise.

Scene:

```text
res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn
```

## Current roster

All sixteen weapon classes are available:

```text
Sword
Lance
Axe
Bow
Hammer
Mace
Daggers
Whip
Chains
Gauntlets
Flail
Halberd
Boomerang
Scythe
Staff
Shuriken
```

Five classes currently use existing authored weapon resources and movesets:

```text
Sword
Lance
Hammer
Whip
Chains
```

The remaining classes are deliberately marked `[Proxy]`. Proxy weapons are development-only combat sketches with generated combo graphs, class-specific timing/range/commitment, and readable primitive silhouettes. They are not progression items and should not be treated as final balance or final movesets.

## Motion authority

Weapon animation now has two layers:

1. Authored per-attack pose/footwork profiles remain authoritative.
2. If an attack has no authored body or footwork profile, the SafeWeaponController duplicates that attack at runtime and supplies a weapon-class motion signature.

The source attack Resource is never mutated.

Class motion signatures currently provide distinct body language for all sixteen classes: anticipation, torso commitment, arm intent, hand travel, weapon-pivot share, and a temporary compatible footwork profile.

The temporary footwork profiles intentionally reuse proven Sword root-motion curves. They are stunt doubles, not final locomotion identity. Per-class footwork should be authored only after playtesting shows what each class actually needs.

## Why this precedes final models

Combat feel should not depend on a high-detail character model.

The current mannequin can answer questions about:

- startup readability;
- active timing;
- recovery and commitment;
- root movement;
- input buffering;
- facing assist;
- hit stop;
- range and spacing;
- combo rhythm;
- stance pressure;
- target reactions;
- dash and aerial techniques.

A production character later needs a stable humanoid rig, skin weights, authored/acquired animation clips, retargeting, IK, blending, and weapon grip alignment. Static AI-generated block meshes are useful proxy geometry but are not a substitute for that animation pipeline.

The intended boundary is:

```text
Godot combat timing / hit logic / root-motion contract
→ animation-control layer
→ replaceable rigged character + authored animation assets
```

## First playtest

Use the side pedestals to switch classes. `[AUTHORED]` means an existing weapon resource/moveset is being used. `[PROXY]` means the class is present specifically so its combat identity can be tested before permanent content is authored.

Test each class against the same central targets:

- neutral Light chain;
- Heavy entry;
- Light → Heavy branches;
- whiff recovery;
- moving attack;
- dodge attack;
- neutral / forward / down aerial attacks;
- multi-target spacing;
- stance break and critical follow-up.

In editor builds:

```text
F8 = reset dojo
F9 = toggle Goblin + Gremlin live sparring
```

Record qualitative reactions first. Useful labels include:

```text
snappy
floaty
sticky
slippery
committed
weightless
overcommitted
precise
hard to aim
satisfying impact
samey
```

Do not tune all sixteen simultaneously.

## Recommended authoring order after comparison

Use the dojo to pick the weakest/highest-value contrast, but the default comparison set is:

1. Sword — baseline flow and responsiveness.
2. Hammer — planted weight and commitment.
3. Daggers or Gauntlets — rapid close-pressure opposite.
4. Lance — spacing and linear precision.
5. Whip / Chains — flexible range and control.

If these archetypes feel meaningfully different, the remaining classes can inherit lessons rather than each becoming a separate combat-engine rewrite.

## Next feel layer

Once attacker motion is readable, isolate contact feel:

```text
hit confirm
→ hit stop
→ attacker followthrough
→ defender flinch / stagger / launch
→ knockback damping
→ recovery back to authored locomotion
```

That pass should specifically target the current stiff / ragdoll-like feeling. It should not be mixed into class-identity tuning until the dojo reveals whether a problem belongs to Grace, the target, or both.

## Regression

```text
res://scenes/tests/weapon_arsenal_dojo_smoke_test.tscn
```

The regression checks all sixteen classes, proxy moveset graphs, runtime proxy silhouettes, authored Sword preservation, fallback Hammer motion, pose-router compatibility, temporary footwork compatibility, dojo construction, and SafeWeaponController integration.
