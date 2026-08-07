# Curling Puck v1

Curling Puck is an Ice terrain spell. Grace sends a low puck skimming along the current ground or water surface, and the puck writes a temporary slippery route behind itself.

## Player contract

```text
Mana cost:                2
Initial speed:            8.8 m/s
Deceleration:             0.95 m/s²
Maximum route:            22 meters
Curl rate:                11 degrees per second
Puck health damage:       1
Puck stance damage:       2
Puck status:              Chill for 2.4 seconds
Trail width:              1.45 meters
Maximum trail segments:   56
Trail lifetime:           9 seconds after the puck stops
Trail fade:               1 second
```

The cast reads horizontal movement at the instant the puck forms:

```text
Neutral cast       → straight route
Hold left + Cast   → left-hand curl
Hold right + Cast  → right-hand curl
```

The puck keeps its selected rotation instead of homing toward later input. The chosen curl is stored on the resulting trail, so rooms can verify the route itself even after a later cast changes Grace's current input state.

The result is a committed route that can bend around a corner, curve toward a mechanism, or remain straight for a bridge and momentum runway.

## Ground-conforming movement

Curling Puck does not fly like an ordinary projectile.

Each movement step:

1. Rotates the travel direction by the selected curl.
2. Samples the next supported surface.
3. Places the puck just above that surface.
4. Sweeps several rays across the puck's width.
5. Adds evenly spaced trail segments between the old and new positions.

The support sampler accepts ordinary ground and authored freezable water volumes. It can preserve one continuous route through a ground-to-water-to-ground transition rather than treating the shoreline as an impact.

A puck stops when it loses a valid route, reaches its maximum distance, loses enough speed, or contacts a solid obstruction or target.

The puck deals only a light chilling impact. The spell's main value is the terrain it leaves behind.

## Slippery terrain

Every trail segment contributes to one shared slippery area. A body entering the trail records the trail's cast serial and receives a low-traction response.

Grace receives:

```text
Acceleration response: 34%
Braking response:       8%
Turning response:       18%
Reversal response:      12%
```

These values do not add free speed. They preserve existing velocity and make direction changes slow, producing a readable slide rather than ordinary walking with a blue floor decal.

Rigid bodies temporarily receive:

```text
Linear damping:    0.04
Angular damping:   0.035
Contact friction:  0.02
Rough contact:     false
```

The low-friction contact material matters for rough objects such as Boulder. Reducing damping alone would preserve motion in the air while the object's original high-friction surface still gripped the ground. The trail temporarily replaces both the damping and the contact material, then restores the exact original values and material resource when the object leaves or the ice disappears.

A Boulder that contacts the trail records:

```text
ice_curl_last_trail_serial_contact
ice_curl_last_trail_name
```

Authored puzzles can therefore require a specific Puck-to-Boulder combination instead of merely detecting that a heavy object reached the destination.

## Reliable contact volumes

The solid ice support remains approximately 0.1 meters thick. The slippery and frozen-water detection volumes rise roughly 0.85 meters above that support and overlap it slightly.

This separation prevents a common physics edge case:

```text
Thin support top merely touches a resting collision body
        ↓
Area3D reports no overlap
        ↓
The object looks on the ice but never receives ice behavior
```

The raised interaction volume ensures Grace, rigid props, and Boulders inherit slippery or frozen-water behavior while physically resting on the thin bridge. Static floors and support geometry are rejected from those interaction areas.

## Freezing water

`SwimmingWaterVolume` now exposes a reusable frozen-surface sample. When Curling Puck crosses one of these volumes, its water segments become physical ice support at the water surface.

The frozen path performs two jobs:

- solid collision carries Grace and physical objects across the pool;
- a frozen-water handoff suspends swimming locomotion while Grace is supported by the bridge.

When the ice melts beneath Grace, the handoff releases and swimming resumes if she is still inside the water volume.

This is local freezing, not a global water toggle. Only the path actually written by the puck becomes traversable. The same trail can begin on shore, cross the water, and reacquire solid ground on the opposite side.

## Trail lifecycle

The puck and trail are separate runtime objects.

```text
Puck moving:
SPELL FX     +2
PERSISTENT   +1

Puck finished, trail remains:
SPELL FX     +1
PERSISTENT   +1

Trail melted or expired:
Both return to baseline
```

The trail remains for nine seconds after the puck stops, then fades over one second. A Fire payload can begin an early melt.

## Presentation and performance

```text
Puck:
1 CharacterBody3D controller
1 cylindrical collision shape
1 low-poly ice puck
1 short unshadowed light
5 bounded sweep rays per movement step

Trail:
1 controller
1 MultiMeshInstance3D
up to 56 visual instances
1 shared StaticBody3D
1 shared slippery Area3D
1 shared frozen-water Area3D
0 per-segment scripts
0 per-segment processing callbacks
```

Trail segments add collision shapes to the shared bodies rather than creating an independently processing node for every strip of ice. Water-supported instances receive a slightly brighter tint, making the bridge portion readable against the pool.

## Complete Focus library

Curling Puck is added to Grace's learned and runtime spell collections under Ice. The development library now contains forty-four authored abilities.

Its Focus and quick-slot badge is:

```text
◍>
```

## The Rime Rink

Launch:

```text
res://scenes/levels/prototypes/prototype_curling_puck_spell_trial_v1.tscn
```

The trial equips Curling Puck automatically and regenerates 2 Mana per second between attempts.

### I. The Curling Line

Stand on the first Ice mark, hold right, and cast once.

Three marks bend gradually across the floor. One fresh trail must pass within the authored radius of all three marks. A straight cast or a left-hand curl cannot complete the route.

This teaches that curl direction is selected at cast time and remains committed throughout the puck's journey.

### II. The Frozen Crossing

Cast neutrally from the near shore so the puck travels straight across the pool. Follow the temporary ice before it melts.

The far-side trigger requires:

- a fresh trail from the current stage;
- at least twelve water-supported ice segments;
- Grace reaching the far shore without active swimming locomotion.

Swimming across the pool does not satisfy the room.

### III. The Long Slide

Lay a straight Curling Puck runway along the final chamber, step forward on the same centerline, switch to Boulder, and roll a fresh Boulder onto the 120 kg plate.

The gate requires:

- a fresh Boulder from the current stage;
- a fresh ground trail with at least ten segments;
- the Boulder recording contact with that exact trail;
- at least 120 kg resting on the plate.

Curling Puck does not solve the plate directly. It changes the physics inherited by the next spell.

### Mastery

Enter the gold seal:

```text
CURL • FREEZE • CARRY MOMENTUM
```

Completion records:

```text
rime_rink_curling_puck_trial_complete
```

## Reset

F8 restores:

- Grace's transform, velocity, resources, and Curling Puck selection;
- swimming and frozen-surface state;
- all three gates;
- the weighted momentum plate;
- Curling Puck and Boulder serial baselines;
- every puck, ice trail, and Boulder;
- the temporary mastery flag.

## Focused playtest

1. Open Ice in Focus and confirm Curling Puck uses the `◍>` badge.
2. Cast without horizontal movement and confirm the puck travels straight.
3. Hold left while casting and confirm the route curls left.
4. Hold right while casting and confirm the route curls right.
5. Walk onto the trail with existing speed, release movement, and confirm Grace slides.
6. Attempt a sharp turn and confirm the response is slower than on ordinary ground.
7. Push a rough rigid prop onto the trail and confirm both its damping and contact friction drop until it exits.
8. Complete the three right-hand curling marks with one cast.
9. Cast straight across the pool and confirm the puck transitions from shore to water and back to shore.
10. Walk over the frozen path without entering the swimming state.
11. Wait for the bridge to melt while standing over water and confirm swimming resumes.
12. Lay an ice runway, switch to Boulder, and roll it onto the 120 kg plate.
13. Confirm the Boulder records the trail serial and keeps rolling longer than on the dry runway.
14. Apply Fire to a trail and confirm it melts early.
15. Watch F7 through puck travel, lingering ice, multiple casts, and cleanup.
16. Complete the mastery seal and press F8 to verify the full reset.
