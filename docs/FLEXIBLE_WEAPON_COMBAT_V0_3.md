# Grace of Humanity — Controlled Flexible Weapons v0.3

## Why this pass exists

The first Whip / Chains / Flail physics pass proved that a full rope solver was adding more combat uncertainty than useful weapon feel.

Observed problems:

- flexible weapons could visually cross a target without the attack registering;
- the simulated line could oscillate while the endpoint followed an authored attack;
- most practical damage authority still lived near the tip;
- the simulation could occupy a different pose when the shared weapon controller reached its single active hit frame.

The combat rule is now deliberately simpler:

```text
authored attack path
→ small controlled endpoint lag
→ deterministic rendered line
→ hit detection samples that exact rendered line
```

The rendered weapon and the hittable weapon are the same geometry.

## What was removed

Whip, Chains, and Flail combat rigs no longer use `FlexibleTether3D` as their combat or visual authority.

`FlexibleTether3D` remains available for environmental ropes, cables, grapples, experiments, and other situations where free simulation is useful.

Combat weapons prioritize deterministic readability.

## ControlledFlexibleLine3D

`ControlledFlexibleLine3D` is a small presentation/contact helper. It receives authored world-space points and:

- draws segments between those points;
- exposes the same points and midpoints as contact samples;
- contains no Verlet integration, constraint iterations, tension solver, break simulation, or per-link dynamics.

## Whip

Whip keeps the strongest authored flexibility.

During startup the tip follows a curved snap, overhead, wrap, or precision path. The body of the whip is generated between Grace's hand and the controlled tip.

At the actual active hit frame the visible line enters the authored contact lane. The whole distal body may hit, with contact strength increasing toward the tip.

The tip can still earn stronger crack identity, but the rest of the whip is no longer harmless decoration.

## Chains

Chains use one damped weighted endpoint plus a deterministic sagging line.

The endpoint has controlled velocity/inertia, but individual links are not simulated. Startup can describe an orbit, while the active hit frame visibly converges into the authored contact lane.

The whole rendered line can strike. Contacts nearer the weight receive greater authority.

## Flail

Flail inherits the controlled weighted-endpoint model with:

- a short 1.9 m chain;
- seven rendered segments;
- a heavy endpoint;
- slower endpoint response than Chains;
- a larger orbit wind-up;
- one intentional physics flavor: damped head lag.

The chain itself does not simulate link-by-link physics.

At the active hit frame the head and line occupy a reliable forward contact pose. Recovery lets the weighted head settle back toward Grace.

## Combat timing rule

The shared weapon controller resolves one hit when startup becomes active.

Flexible weapons therefore treat the active frame as authoritative:

```text
startup  = expressive curve / orbit / lag
active   = visible deterministic contact pose
recovery = controlled settling
```

This is intentionally game-first rather than physically pure.

## Ranged behavior preserved

The Arsenal Dojo still uses `CombatWeaponControllerV2`, so the previous projectile fixes remain:

- Bow / Shuriken / Boomerang aim is decoupled from movement input;
- ranged aim is re-sampled at the hit frame;
- floor/wall colliders cannot recursively resolve to unrelated sibling targets.

## Manual playtest

Scene:

```text
res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn
```

Primary checks:

1. Stand at normal melee distance from the center target and confirm Whip Light attacks reliably connect when the visible line reaches it.
2. Repeat with Chains. The line should be stable and the target should not require a perfect weighted-tip collision.
3. Repeat with Flail. The head should feel slightly reluctant during the wind-up but the active strike should be reliable.
4. Move around while attacking. Flexible lines should remain coherent rather than exploding into oscillations.
5. Whiff intentionally. Recovery should settle quickly instead of vibrating for several seconds.
6. Confirm Bow / Shuriken / Boomerang still hit while strafing.

Qualitative question:

> Is the remaining flexibility helping the weapon identity, or would an even more authored animation path be clearer?

## Automated regression

```text
res://scenes/tests/flexible_weapon_combat_v2_smoke_test.tscn
```

The regression now tests deterministic line construction, full-line contact sampling, simplified Flail head lag, ranged strafe-aim preservation, safe collider ancestry, and real nearby target acquisition by Whip / Chains / Flail.

GitHub Actions may not currently execute because the repository Actions budget is exhausted; local playtest remains authoritative until CI capacity returns.
