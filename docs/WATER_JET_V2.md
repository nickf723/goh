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

At a bounded 20 Hz contact cadence, one oriented cylinder query gathers valid targets inside the resolved stream. The query shape and parameter object are reused for the complete channel rather than being allocated repeatedly.

The center ray's first valid effect target is also inserted directly into the contact set. This closes the numerical seam where the cylinder ended exactly against a cube or enemy and therefore reported no overlap despite the visible stream striking it.

The stream can affect:

- enemies with `ForceReceiver`;
- ordinary `CharacterBody3D` mobs;
- `RigidBody3D` props;
- objects exposing `receive_external_impulse`;
- targets with payload or hit receivers.

## Pressure

Force and damage are separate processes.

### Target force

At every pressure scan, Water Jet adds directional pressure along the complete three-dimensional aim line. Repeated scans quickly drive ordinary targets toward their authored speed limits.

```text
ForceReceiver impulse:  0.72 per scan
Scan cadence:           0.05 seconds
Rigid-body pressure:    190 force units per second
Rigid-body speed limit: 10 m/s
Fallback acceleration:  30 m/s²
Boss multiplier:        18%
```

Rigid bodies are awakened before pressure is applied. Intentionally frozen bodies remain fixed. The stronger rigid-body tune is high enough to overcome ordinary floor friction while remaining capped against runaway prop speeds.

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

The production tune uses:

```text
Maximum recoil distance: 5 meters
Recoil acceleration:     46 m/s² at full pressure
Maximum upward speed:    11.5 m/s
Maximum planar speed:     8 m/s
Minimum close-contact factor: 30%
```

The stronger traversal tune lets Grace clear the Pressureworks ledge through a maintained downward stream rather than receiving only a decorative hop. Ground normals blend into the recoil direction, making a downward cast rise cleanly instead of sending Grace through the floor at an oblique angle.

The launch remains continuous physics, not a teleport or scripted jump. Releasing Water Jet preserves the velocity already earned.

The spell publishes `water_jet_self_launch_serial` on Grace when upward speed crosses the traversal threshold. Authored rooms can require a genuine pressure launch without hard-coding the spell into ordinary movement logic.

## Presentation and performance

Water Jet uses one action node for the complete channel:

```text
2 reused CylinderMesh stream layers
1 endpoint splash MultiMesh
12 splash instances
0 per-droplet nodes
1 center obstruction ray per physics frame
1 reused cylinder contact query at 20 Hz
30 visual updates per second
0 persistent spell fields
```

The production authority initializes both stream transforms immediately when casting begins, so the reused cylinders never spend a frame sitting at the scene origin.

F7 should show one additional `SPELL FX` while the stream is active. `PERSISTENT` should remain unchanged. Releasing or exhausting the channel returns `SPELL FX` to its prior value.

## The Pressureworks

Launch:

```text
res://scenes/levels/prototypes/prototype_water_jet_spell_trial_v1.tscn
```

The development trial regenerates 2 Mana per second, slightly less than the 2.5-Mana channel drain. Mana falls while Water Jet is active and recovers between attempts.

### I. The Pressure Lane

A 12 kg cargo block sits in a narrow hydraulic lane.

The cargo retains its heavy mass but uses an authored low-friction contact material and reduced linear damping. Hold Water Jet on it until repeated pressure drives it into the gold basin. The room tests sustained alignment and accumulated force rather than a single knockback burst.

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
- the 12 kg cargo transform, velocity, sleep state, friction tune, and latch;
- both progression gates;
- trial stage and completion flag;
- every active Water Jet action.

## Focused playtest

1. Open the Pressureworks and confirm Water Jet remains under Water with the `≋` symbol.
2. Hold Cast in open space and confirm the stream follows camera aim.
3. Confirm Mana drains continuously instead of being spent once per stream.
4. Tap the spell repeatedly and confirm the fractional Mana cost still accumulates.
5. Aim directly at the pressure cargo and confirm the endpoint splash, target registration, and cube motion all agree.
6. Hold the jet on the pressure cargo until it reaches the basin.
7. Test an enemy and confirm rapid one-point health ticks, zero stance damage, Wet, and strong sustained knockback.
8. Aim into a nearby wall and feel Grace push away from it.
9. Aim sharply into the blue floor pad and maintain the stream until Grace launches onto the raised platform.
10. Release while airborne and confirm earned velocity remains.
11. Combine Water Jet recoil with Surf and ordinary movement.
12. Watch F7 during a long channel. `SPELL FX` should rise by one, `PERSISTENT` should remain unchanged, and both frame distribution and effect cleanup should stay green.
13. Complete the mastery seal and press F8 to verify the full reset.

## Regression scenes

```text
res://scenes/tests/water_jet_spell_smoke_test.tscn
res://scenes/tests/water_jet_rigid_body_smoke_test.tscn
res://scenes/tests/water_jet_trial_smoke_test.tscn
```

The rigid-body regression uses a sleeping 12 kg cube with high friction. It verifies that the center-ray contact enters the pressure set, wakes the cube, applies repeated pressure, and produces real displacement rather than only a visual endpoint splash.
