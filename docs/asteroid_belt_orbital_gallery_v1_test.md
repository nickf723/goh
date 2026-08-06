# Asteroid Belt and the Orbital Gallery v1

## Purpose

Add a Space spell whose power lives at an exact distance from Grace rather than at a target point or in a centered aura.

```text
Space Blink    = change Grace's position instantly
Asteroid Belt  = carry a damaging orbit with Grace
```

## Launch

Run:

```text
res://scenes/levels/prototypes/prototype_asteroid_belt_spell_trial_v1.tscn
```

The development trial equips Asteroid Belt automatically, restores Mana on entry, and regenerates Mana at 2 points per second between casts.

## Spell behavior

Asteroid Belt costs 4 Mana and lasts approximately 8 seconds.

The base spell:

- creates six asteroids in a ring approximately 2.75 meters from Grace;
- follows Grace while she moves, jumps, dodges, or blinks;
- leaves a hollow safe region immediately beside Grace;
- strikes only when an asteroid physically crosses a target at the orbit radius;
- deals 2 health damage and 3 stance damage per contact;
- pushes targets outward from Grace;
- allows at most three contacts against one target per cast;
- gives each target a short repeat cooldown;
- replaces Grace's previous belt when recast rather than stacking indefinitely;
- applies strong knockback resistance to bosses; and
- can nudge force-aware mobs or rigid props even when they have no health receiver.

The spell's main question is therefore not merely whether an enemy is nearby:

```text
Too close   -> inside the orbit, no asteroid contact
At the ring -> asteroids can strike and repel
Too far     -> beyond the orbit, no asteroid contact
```

## Performance contract

Asteroid Belt is intentionally built as one effect controller:

- all six rocks render through one `MultiMeshInstance3D`;
- no asteroid owns an individual `_process`, `Area3D`, signal set, or light;
- orbit transforms update at 30 Hz;
- one broad physics query runs at 10 Hz;
- narrow asteroid contact is resolved with distance math after that query;
- one belt per caster is allowed; and
- a small global cap prevents pathological multi-caster stacking.

The shared F7 performance monitor was also tightened during this pass. Its rolling frame history now uses a fixed circular buffer instead of calling `Array.pop_front()` every frame after the history fills. The overlay now reports active spell effects and persistent spell effects when visible.

## Room I: The Exact Orbit

Three witnesses stand at different distances from the central cast mark:

```text
INNER WITNESS  -> inside the belt
ORBIT TARGET   -> exactly at the belt radius
OUTER WITNESS  -> beyond the belt
```

1. Stand on the central mark.
2. Cast Asteroid Belt.
3. Remain near the center long enough for the rocks to circle.
4. Confirm the Orbit Target is struck and eventually defeated.
5. Confirm the Inner and Outer Witnesses remain unharmed.
6. Confirm the first gate opens.

The room demonstrates that Asteroid Belt is a moving ring, not a conventional radial damage aura.

## Room II: Orbital Drift

The Drifting Moon moves laterally across the chamber.

1. Enter the second room with Asteroid Belt ready.
2. Watch the target's path.
3. Reposition Grace so her orbit, rather than her body, crosses that path.
4. Keep adjusting as the target moves.
5. Confirm two contacts defeat the Drifting Moon and open the mastery route.

This room proves that the field follows Grace and turns locomotion into spell aiming.

## Mastery

Enter the gold seal after the second gate opens.

Completion records:

```text
orbital_gallery_spell_trial_complete
```

The mastery summary is:

```text
POSITION • ORBIT • REPEL
```

## Reset behavior

F8 restores:

- Grace's starting transform, velocity, full Mana, and Asteroid Belt selection;
- all four training targets;
- the Drifting Moon's route and timing;
- both gates;
- the trial stage and objective;
- the completion flag; and
- every active Asteroid Belt controller and MultiMesh.

## Automated regression

Run:

```text
godot --headless --path . res://scenes/tests/asteroid_belt_orbital_gallery_smoke_test.tscn
```

The regression covers:

- ability-library integration and four-Mana cost;
- Space metadata and authored icon resolution;
- one-MultiMesh rendering;
- no per-asteroid processing nodes;
- same-caster recast replacement;
- exact inner, orbit, and outer distance behavior;
- health damage, stance identity, and outward force;
- bounded repeat contacts;
- finite duration and cleanup;
- fixed-capacity performance history without per-frame shifting;
- both trial gates;
- mastery persistence; and
- complete reset behavior.

## Known limitations

- The procedural low-poly rocks and orbit guide are replacement-ready presentation rather than final asteroid art, debris trails, audio, haptics, or gravitational distortion.
- V1 does not intercept enemy projectiles. Projectile capture, asteroid sacrifice, and reflected shots are strong upgrade candidates.
- V1 does not alter its radius during the cast. Expanding, contracting, elliptical, and tilted orbits remain upgrade space.
- Asteroids use a broad query plus mathematical contact checks instead of six independent physics bodies. This is deliberate for stable gameplay and performance.
