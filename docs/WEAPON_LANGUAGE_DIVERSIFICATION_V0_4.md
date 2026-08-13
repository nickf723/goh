# Weapon Language Diversification v0.4

## Goal

Sword established the first production-shaped combat language. This pass starts spreading that quality bar by contrast rather than by copying Sword animation across every class.

Primary playtest scene:

```text
res://scenes/levels/prototypes/prototype_weapon_arsenal_dojo_v1.tscn
```

The first three contrast classes are:

```text
Hammer  → planted commitment and mass
Lance   → linear reach and precision
Daggers → alternating pressure and evasive rhythm
```

Sword remains the balanced reference.

## Shared rule

The skeletal animation system now treats weapon identity as a question of **where force comes from**, not simply how many degrees the weapon rotates.

```text
Sword   = balanced stance → torso rotation → blade
Hammer  = planted legs → hips/chest load → two-handed head momentum
Lance   = rear-leg drive → torso line → two-hand point control
Daggers = low stance → compact torso turn → alternating arms
```

Gameplay remains authoritative for hit timing, attack range, root movement, combo windows, targeting, damage, and reactions.

## Hammer language

Authored resource:

```text
res://data/weapon_movesets/training_hammer_moveset.tres
```

Hammer keeps its existing seven-attack Light/Heavy branch structure, but its presentation ranges are reduced from the earlier oversized arcs.

### Light chain

- `Weighted Sweep` — planted horizontal opening with restrained travel.
- `Backhand Crush` — heavier reversal rather than a full-body spin.
- `Falling Weight` — compact overhead drop that ends the Light string.

### Heavy branches

- `Groundbreaker` — neutral committed slam.
- `Anvil Lift` — launcher generated from a crouched upward drive.
- `Quake Sweep` — broad crowd-control sweep without near-full-circle rotation.
- `Cathedral Bell` — maximum commitment finisher using load, hit stop, stance pressure, and recovery instead of extreme backswing.

### Feel contract

Hammer should feel slow to redirect. The head appears to pull Grace through recovery, while both arms and the planted stance remain involved.

## Lance language

Authored resource:

```text
res://data/weapon_movesets/training_spear_moveset.tres
```

Lance is intentionally dominated by thrusts. Rotation is reduced on the normal line attacks, with sweeps reserved for space control and combo punctuation.

### Light chain

- `Quick Jab` — small forward point with minimal flourish.
- `Passing Thrust` — deeper advancing thrust.
- `Clearing Arc` — first meaningful lateral sweep.

### Heavy branches

- `Brace Pierce` — long neutral commitment.
- `Shaft Sweep` — lateral response after the first Light.
- `Driving Skewer` — deepest linear commitment.
- `Reaping Return` — broad finisher, still bounded below a full orbit.

### Feel contract

Lance should read as distance management. Rear-leg drive and two-handed alignment matter more than body spin.

## Daggers language

Daggers remain a sandbox proxy for this pass so animation rhythm can prove the class before a permanent authored resource is promoted.

Current sandbox source:

```text
res://scripts/weapons/weapon_sandbox_catalog.gd
```

The three-Light / four-Heavy generated graph remains intact:

```text
L1 → L2 → L3
 |    |    |
H1   H2   H3

neutral H0
```

The skeletal layer gives those generated attacks authored body language.

### Light rhythm

The hands alternate rather than both following one broad weapon swing. Grace stays low and forward, with short stance exchanges and early recovery.

### Heavy rhythm

- neutral / second-depth precision options drive both hands forward;
- one branch uses an evasive lateral step;
- the deep branch closes with a committed cross-cut.

### Real off-hand dagger

The old proxy built both dagger meshes as one right-hand object. During skeletal Daggers combat, the left proxy blade is hidden and a replacement off-hand dagger follows the animated `hand_l` bone.

This makes the two-arm animation visually honest without changing the existing hit authority.

## Context attacks

The existing explicit context grammar remains available for all classes:

```text
dodge + Light → Dash Light
dodge + Heavy → Dash Heavy
jump + Light  → Aerial Light
jump + Heavy  → Aerial Heavy
```

Hammer, Lance, and Daggers now receive class-specific skeletal choreography for these contexts instead of relying on Sword-like generic body motion.

## Active skeletal owner

The scene path remains stable:

```text
res://scenes/actors/player/grace_humanoid_skeletal_proxy_v1.tscn
```

Its active controller now extends:

```text
res://scripts/visuals/grace_humanoid_skeletal_proxy_weapon_languages_v2.gd
```

The layer inherits all previous grounding, full rest-pose initialization, agile Grace calibration, Sword authoring, and right-hand weapon socket behavior.

## Manual playtest order

Use the center target and compare the classes back-to-back.

### Sword reference

```text
L → L → L → H
```

Use this only to reset your sense of the baseline.

### Hammer

```text
L → L → L
H
L → H
L → L → H
L → L → L → H
dodge → Light / Heavy
jump → Light / Heavy
```

Questions:

- Does each reversal look like Grace has to manage the hammer head?
- Do Heavy attacks feel larger because of weight and commitment rather than oversized arcs?
- Does Groundbreaker feel planted?
- Does Anvil Lift visibly generate upward force from the legs?

### Lance

Use several starting distances.

```text
L → L → L
H
L → H
L → L → H
L → L → L → H
dodge → Light / Heavy
jump → Light / Heavy
```

Questions:

- Do normal thrusts stay visually linear?
- Does Passing Thrust feel like an advancing point rather than a sword stab?
- Are the sweeps distinct punctuation?
- Does the weapon feel best when Grace controls distance?

### Daggers

Stay close to the target and move frequently.

```text
L → L → L
H
L → H
L → L → H
L → L → L → H
dodge → Light / Heavy
jump → Light / Heavy
```

Questions:

- Do the left and right hands visibly alternate?
- Does the off-hand blade remain attached to the left hand?
- Do attacks recover quickly enough to preserve the agile Grace rhythm?
- Does the class invite dodging and re-entry rather than planted trading?

## Automated contract

Existing registered tests remain the owners:

```text
res://scenes/tests/weapon_moveset_smoke_test.tscn
res://scenes/tests/context_weapon_technique_smoke_test.tscn
res://scenes/tests/grace_skeletal_grounding_smoke_test.tscn
res://scenes/tests/weapon_arsenal_dojo_smoke_test.tscn
```

The skeletal grounding test now also verifies that the active visual reports authored combat languages for Sword, Hammer, Lance, and Daggers.

No new permanent test scene or development lab was added.

## Next expansion

If these three contrasts survive playtesting, use them as families rather than authoring every remaining class from a blank page:

```text
Hammer family → Axe / Mace
Daggers family → Gauntlets
Lance family → Halberd / Staff
Sword + Hammer → Scythe
specialized existing systems → Whip / Chains / Flail
ranged family → Bow / Boomerang / Shuriken
```

Each class should still receive its own final authored language, but the family reference gives production a starting grammar instead of another framework.
