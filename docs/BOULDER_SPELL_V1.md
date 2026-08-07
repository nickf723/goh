# Boulder Spell v1

Boulder is an Earth spell built as a real rolling physics body rather than a translated projectile.

## Player contract

```text
Mana cost:                 3
Physical mass:             160 kg
Radius:                    1.15 meters
Initial roll speed:        7.6 m/s
Base health damage:        5
Base stance damage:        11
Impact scaling:            current relative speed
Lifetime:                  no fixed timer
Settle confirmation:       0.8 seconds
Dissolve duration:         0.48 seconds
Maximum active per caster: 3
```

Grace forms the Boulder directly on the ground in front of her. The spell projects the forward aim direction onto the local surface, so a Boulder cast on a slope begins along that grade instead of launching into the terrain.

```text
Cast
  ↓
Probe the ground ahead of Grace
  ↓
Form a 160 kg stone sphere above the contacted surface
  ↓
Apply matching linear and rolling velocity
  ↓
Let rigid-body physics determine the route
```

The production launch authority uses the surface normal crossed with the travel direction for its angular axis. This gives the sphere matching no-slip spin instead of visually rolling backward while translating forward.

## Motion is the lifetime

Boulder has no ordinary projectile lifetime and no distance timer.

Every physics frame it measures:

```text
linear speed
angular speed × radius
contact support
sleeping state
```

The settle timer advances only when both linear motion and surface rolling are below their thresholds while the Boulder is physically supported. Any renewed movement resets the timer.

Consequences:

```text
Flat floor
    → damping and friction reduce momentum
    → Boulder eventually settles
    → settle confirmation completes
    → Boulder crumbles

Downhill slope
    → gravity replenishes forward motion
    → settle timer remains at zero
    → Boulder continues indefinitely while the grade sustains it

Water Jet, Wave, collision, machinery, or another force
    → motion resumes
    → pending cleanup is cancelled
```

There are two bounded safety rules outside ordinary settling:

- an emergency out-of-bounds cleanup far below the playable world;
- a three-Boulder budget per caster, where forming a fourth Boulder begins dissolving the oldest one.

The budget allows multi-Boulder physics setups without permitting an endless convoy of active rigid bodies on a perpetual slope.

## Physical integration

The summoned Boulder is a `RigidBody3D` with continuous collision detection. It participates in ordinary world physics and therefore can:

- collide with walls and architecture;
- shove and exchange momentum with rigid props;
- be redirected by Wave and Water Jet;
- roll down authored slopes;
- rest on weighted pressure plates;
- report its full 160 kg mechanism mass;
- remain in the world as long as outside forces keep it moving.

The caster is added as a collision exception so the Boulder does not form inside Grace or immediately bowl her over.

## Rolling impacts

The Boulder listens for body contacts while active. Static architecture shapes its route but does not receive combat payloads.

Characters and authored physical targets receive a speed-scaled payload:

```text
Earth
Stone
Boulder
Rolling
Crush
Physical
Projectile
Force
Heavy impact
```

At the authored launch speed, an impact carries approximately:

```text
5 health damage
11 stance damage
6.2 directional knockback
```

Faster downhill impacts scale upward, with a bounded maximum multiplier. Slow contacts below the damaging threshold remain physical bumps rather than repeated combat hits.

Targets record:

```text
boulder_last_cast_serial
boulder_last_impact_speed
boulder_last_impact_energy
boulder_last_impact_count
```

This allows encounters and puzzles to verify that the moving Boulder itself completed a route.

## Presentation and performance

```text
1 RigidBody3D controller
1 spherical collision shape
1 low-poly core mesh
4 embedded rock lobes
3 dark surface scars
1 short unshadowed formation light
0 particle emitters
0 per-fragment scripts
maximum 3 active bodies per caster
```

Boulder registers as both `SPELL FX` and `PERSISTENT` because its physical lifetime can become long on a slope. Both counters return to baseline after the Boulder settles, is reset, leaves the emergency world boundary, or is retired by the per-caster body budget.

The visual crumbles by shrinking and fading only after physical collision has been disabled.

## Complete Focus library

Boulder is added to Grace's learned and runtime spell collections under Earth. The complete-library regression still scans every `AbilityDefinition` in `res://data/abilities`, so the library now contains forty-three authored spells and remains protected against future omissions.

## Momentum Quarry

Launch:

```text
res://scenes/levels/prototypes/prototype_boulder_spell_trial_v1.tscn
```

The trial equips Boulder automatically and regenerates 2 Mana per second between casts.

### I. Flat Momentum

Stand on the first Earth mark and cast through the Flat Impact target.

The first gate requires a qualifying rolling impact. Afterward, the original Boulder is left to lose speed naturally on the flat quarry floor and crumble only once both translation and rotation settle.

### II. The Long Grade

Cast a fresh Boulder from the upper mark.

A long twelve-degree grade carries the Boulder into the lower quarry. The second gate opens only when a Boulder from the new stage crosses the weighted plate with at least 120 kg of supported mass.

Grace weighs less than the threshold, so standing on the plate cannot substitute for the spell. The stage demonstrates that the Boulder remains alive across a route much longer than an ordinary projectile because gravity continues feeding its motion.

### Mastery

Enter the final gold seal:

```text
MASS • MOMENTUM • GRADE
```

Completion records:

```text
momentum_quarry_boulder_trial_complete
```

## Reset

F8 restores:

- Grace's transform, velocity, resources, and Boulder selection;
- the Flat Impact target and its hit metadata;
- both gates;
- the weighted pressure plate;
- the Boulder cast serial baseline;
- every active Boulder;
- the temporary mastery flag.

## Focused playtest

1. Open Earth in Focus and confirm Boulder appears with the `●` badge.
2. Cast on a flat floor and confirm a large stone sphere forms on the ground instead of flying through the air.
3. Watch the visible scars rotate forward with the body rather than backward against its travel.
4. Confirm the Boulder rolls several meters, slows naturally, settles, and only then crumbles.
5. Push a slowing Boulder with Water Jet or Wave and confirm its settle timer is cancelled.
6. Roll it into an enemy and inspect heavy damage, stance pressure, and directional knockback.
7. Roll it into movable props and confirm physical momentum transfers naturally.
8. Place it on a pressure plate and confirm the plate reads 160 kg.
9. Keep three Boulders moving, cast a fourth, and confirm the oldest crumbles while the new one forms.
10. In Momentum Quarry, clear the Flat Impact target with one Boulder.
11. Cast a new Boulder from the top of the long grade and confirm it remains active all the way to the lower plate.
12. Watch F7 during several casts. Each live Boulder should add one `SPELL FX` and one `PERSISTENT`, with no invisible residue after cleanup.
13. Complete the mastery seal and press F8 to verify the full reset.
