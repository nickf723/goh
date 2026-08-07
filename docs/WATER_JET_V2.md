# Water Jet v2

Water Jet is now a sustained high-pressure Water channel rather than a blue generic projectile.

## Player contract

```text
Input:              hold Cast
Upfront Mana:       0
Mana drain:         2.5 per second
Maximum range:      9 meters
Stream radius:      0.42 meters
Damage tick:        1 health every 0.12 seconds
Stance damage:      0
Status:             Wet, continuously refreshed
Primary force:      strong repeated directional pressure
Self propulsion:    nearby solid-surface recoil
```

Releasing Cast, changing spells, opening Focus, guarding, dodging, using an item, being staggered, being defeated, or exhausting Mana ends the channel.

Movement and camera aim remain available while Water Jet is active. The cast channel blocks attacks, other spells, guarding, dodging, and interactions through the shared `PlayerActionState` contract.

## Continuous Mana

Water Jet has no fixed cast cost. Its action owns a fractional Mana debt:

```text
mana_debt += 2.5 × delta
whole points are spent when debt reaches 1
remaining fraction is preserved
```

The fractional debt is stored on Grace between short casts. Rapidly tapping the stream therefore cannot generate free pressure by resetting a temporary node before one complete Mana point accrues.

## Stream collision

Every physics frame, one center ray resolves the visible stream length and first solid obstruction. Walls, gates, props, enemies, and other bodies can shorten the stream.

At a bounded 20 Hz contact cadence, one oriented cylinder query gathers valid targets inside the resolved stream. The jet does not create projectile actors, per-droplet colliders, or per-target stream nodes.

The stream can affect:

- enemies with `ForceReceiver`;
- ordinary `CharacterBody3D` mobs;
- `RigidBody3D` props;
- objects exposing `receive_external_impulse`;
- targets with payload or hit receivers.

## Pressure

Force and damage are separate processes.

### Target force

At every pressure scan, Water Jet adds a small directional impulse. Repeated scans quickly drive ordinary targets toward the shared force-speed cap.

```text
ForceReceiver impulse: 0.72 per scan
Scan cadence:          0.05 seconds
Rigid-body pressure:   28 force units per second
Fallback acceleration: 30 m/s²
Boss multiplier:       18%
```

Because pressure is repeated rather than delivered as one burst, targets can be pinned against architecture, swept along a lane, or continuously denied forward movement while the stream remains aligned.

### Rapid chip

Water Jet applies one health damage every 0.12 seconds, with zero stance damage. The rapid payload refreshes Wet but suppresses elemental-reaction resolution on the stream ticks themselves.

That separation prevents a continuous jet from repeatedly detonating the same reaction many times per second. Wet remains available for a later Lightning, Ice, or other authored payoff.

```text
Water Jet → fast low chip + Wet setup
Wave      → broad zero-damage displacement
Bubble    → one-hit protection and rebound
Surf      → committed terrain traversal
```

## Self propulsion

If Water Jet contacts nearby solid architecture, Grace receives reaction force opposite the nozzle direction.

```text
Aim into distant open space → no useful recoil
Aim into a nearby wall      → horizontal push away
Aim into nearby ground      → upward launch
```

The base tune uses:

```text
Maximum recoil distance: 4.2 meters
Recoil acceleration:     34 m/s² at full pressure
Maximum upward speed:    10.5 m/s
Maximum planar speed:     8 m/s
```

Ground normals blend into the recoil direction, making a downward cast rise cleanly instead of sending Grace through the floor at an oblique angle. The launch is still continuous physics, not a teleport or scripted jump. Releasing Water Jet preserves the velocity already earned.

The spell publishes `water_jet_self_launch_serial` on Grace when upward speed crosses the traversal threshold. Authored rooms can require a genuine pressure launch without hard-coding the spell into ordinary movement logic.

## Presentation and performance

Water Jet uses one action node for the complete channel:

```text
2 reused CylinderMesh stream layers
1 endpoint splash MultiMesh
12 splash instances
0 per-droplet nodes
1 center obstruction ray per physics frame
1 cylinder contact query at 20 Hz
30 visual updates per second
0 persistent spell fields
```

F7 should show one additional `SPELL FX` while the stream is active. `PERSISTENT` should remain unchanged. Releasing or exhausting the channel returns `SPELL FX` to its prior value.

## The Pressureworks

Launch:

```text
res://scenes/levels/prototypes/prototype_water_jet_spell_trial_v1.tscn
```

The development trial regenerates 2 Mana per second, slightly less than the 2.5-Mana channel drain. Mana falls while Water Jet is active and recovers between attempts.

### I. The Pressure Lane

A 12 kg cargo block sits in a narrow hydraulic lane.

Hold Water Jet on the cargo until repeated pressure drives it into the gold basin. The room tests sustained alignment and accumulated force rather than a single knockback burst.

### II. Counterflow Ascent

The route ends at a raised platform with no stairs.

Aim Water Jet into the blue floor pad, maintain pressure until Grace rises, and steer onto the upper platform. The arrival trigger requires a newly published Water Jet self-launch serial.

### Mastery

Cross the upper gate and enter the gold seal:

```text
PRESSURE • PIN • PROPEL
```

Completion records:

```text
pressureworks_water_jet_trial_complete
```

## Reset

F8 restores:

- Grace's transform, velocity, resources, and Water Jet selection;
- fractional Water Jet Mana debt;
- self-launch metadata;
- the 12 kg cargo transform, velocity, sleep state, and latch;
- both progression gates;
- trial stage and completion flag;
- every active Water Jet action.

## Focused playtest

1. Open the Pressureworks and confirm Water Jet remains under Water with the `≋` symbol.
2. Hold Cast in open space and confirm the stream follows camera aim.
3. Confirm Mana drains continuously instead of being spent once per stream.
4. Tap the spell repeatedly and confirm the fractional Mana cost still accumulates.
5. Hold the jet on the pressure cargo and confirm force builds while damage remains irrelevant to the object puzzle.
6. Test an enemy and confirm rapid one-point health ticks, zero stance damage, Wet, and strong sustained knockback.
7. Aim into a nearby wall and feel Grace push away from it.
8. Aim sharply into the blue floor pad and maintain the stream until Grace launches.
9. Release while airborne and confirm earned velocity remains.
10. Combine Water Jet recoil with Surf and ordinary movement.
11. Watch F7 during a long channel. `SPELL FX` should rise by one, `PERSISTENT` should remain unchanged, and both frame distribution and effect cleanup should stay green.
12. Complete the mastery seal and press F8 to verify the full reset.
