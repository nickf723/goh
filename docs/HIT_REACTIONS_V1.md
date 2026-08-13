# Hit Reactions and Anti-Stunlock v1

Run:

```text
scenes/levels/prototypes/prototype_hit_reaction_lab_v1.tscn
```

## Shared reaction contract

`HitReactionController` combines damage, stance damage, knockback, attack tags, mass, armor, current poise, and temporary reaction resistance. It resolves an impact into:

- Resist
- Flinch
- Stagger
- Launch
- Guard Break
- Super Armor
- Adapted

Every interrupt builds temporary reaction resistance. Fast repeated hits therefore become less disruptive until the attacker pauses long enough for resistance to decay. Poise also regenerates independently.

## EnemyActor presentation integration

`EnemyReactionPresentationBridge` now sits under normal `EnemyActor` instances as a presentation-only adapter.

It does not change health, stance, force, AI, poise, attack timing, or airborne motion. Its job is to make receiver state read as one coherent defender beat:

```text
HitReceiver health / stance signals
        ↓
EnemyReactionPresentationBridge
        ↓
one grounded reaction request
        ↓
EnemyVisualShell
```

The bridge takes ownership of the visual shell's health/stance callbacks after both nodes are ready. Health and stance deltas emitted during one gameplay call stack are deferred and coalesced before presentation.

Priority is:

```text
defeat > airborne ownership > stance break > ordinary hit
```

A stance break therefore cannot be overwritten by a small flinch from the same impact. Likewise, launched/falling/bouncing targets keep `AirbornePresentationController` authority instead of receiving a competing grounded recoil tween.

For grounded hits the bridge reads the already-applied `ForceReceiver.external_velocity` to add a small directional outer-body recoil. If no impulse is available, it falls back to an away-from-player direction. This directional layer is presentation only and does not add gameplay displacement.

## Lab profiles

- **Light Gremlin:** light hits flinch, repeated hits stagger, launcher attacks lift it, and rapid pressure eventually triggers Adapted.
- **Armored Goblin:** ordinary light attacks are resisted; heavy guard-break attacks interrupt it.
- **Unstoppable Brute:** permanent super armor demonstrates committed actions that receive damage and feedback without displacement.

## Controls

- Light attack: J / left mouse / controller left face
- Heavy attack: K / mouse 4 / controller right face
- Reset: F8

The compact panel reports each target's current reaction, poise, adaptation, and armor state.

## Manual EnemyActor check

Use any scene containing the normal Goblin or Gremlin `EnemyActor` rather than the dedicated reaction targets.

Check that:

1. a normal hit produces one readable recoil rather than a rapid double-pose;
2. hits from the side produce a modest matching body roll without visibly moving the gameplay body twice;
3. breaking stance reads stronger than an ordinary hit;
4. launch / falling / bounce presentation remains continuous and is not interrupted by a grounded flinch;
5. defeat still takes final presentation authority;
6. enemy attack telegraphs and locomotion resume normally after recovery.

This is a readability pass, not a balance pass. Do not tune damage, poise, force, or AI from this checklist unless a separate combat issue calls for it.

## Automated contract scene

```text
scenes/tests/hit_reaction_smoke_test.tscn
```

The test covers light flinch, armored resistance, guard break, launch motion, super armor, repeated-hit adaptation, the enemy airborne loop, and the real Goblin `EnemyActor` presentation bridge. The bridge regression verifies signal ownership, same-beat coalescing, stance-break priority, and airborne suppression.
