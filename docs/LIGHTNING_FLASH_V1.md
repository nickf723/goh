# Lightning Flash v1

Flash is a Lightning traversal spell that turns Grace into a bolt and resolves the entire aimed line immediately.

## Player contract

```text
Mana cost:          4
Maximum open range: 24 meters
Travel time:        immediate
Damage:             0
Stance damage:      0
Aim:                full 3D camera ray
Stopping rule:      first solid contact
Safe landing:       none
```

The 24-meter open-range cap is a prototype world-boundary guard. Within ordinary architecture, Flash is distance-variable: a wall two meters away yields a two-meter Flash, while a far conductor yields a much longer one.

Flash does not flatten its direction, snap to ground, search backward for a safe landing, or validate supporting terrain. The camera ray itself is authoritative. Aiming upward transforms Grace into an upward bolt and leaves her wherever that line ends.

## Collision sweep

Flash approximates Grace's capsule profile with one bounded nine-ray bundle.

- The ray origins begin at the capsule's leading surface.
- Their offsets sample the center, cardinal edges, and four diagonal edges.
- Capsule height and radius determine the projected sweep extents.
- The nearest solid-body result wins.
- A small skin distance keeps Grace immediately outside the contacted surface.
- Areas are ignored, so trigger volumes and non-solid hazards do not become invisible walls.

The sweep includes ordinary architecture, movable solid bodies, enemies, and other bodies on Grace's collision mask. The base spell stops at them but sends no damage payload.

## Presentation

For roughly 0.055 seconds Grace's 3D presentation disappears. A procedural lightning line remains between origin and destination, then Grace reforms at the endpoint.

```text
1 temporary controller
1 MultiMesh trail
8 to 30 primary segments
bounded decorative branches
0 per-segment nodes
2 unshadowed flash lights
0 persistent effects
```

F7 should briefly show one additional `SPELL FX`. `PERSISTENT` should not change.

## Haptics

Flash uses the reusable controller haptic bridge:

```text
ignition crack
short rushing buzz
contact impact
```

The final pulse is heavier when Flash reaches solid contact. Open-space travel ends with a softer discharge. Overall strength scales slightly with travel distance and respects the player's vibration preference.

## Movement-state combinations

Flash changes Grace's position without cancelling unrelated persistent states.

Notably:

```text
Surf + Flash
    Surf remains active
    Grace jumps instantly to the Flash endpoint
    the wave resumes from the new position
```

This supports high-speed route construction and emergency course corrections. An upward Flash during Surf may still leave Grace airborne long enough for Surf's own airborne cancellation rule to end the wave.

## Difference from Space Blink

```text
Space Blink
short fixed range
horizontal intent
safe-destination search
ground-aware fallback

Flash
long variable range
full 3D intent
first-contact stop
no safe landing
```

Blink is controlled repositioning. Flash is a committed line.

## The Thunderline

Launch:

```text
res://scenes/levels/prototypes/prototype_lightning_flash_spell_trial_v1.tscn
```

### I. First Contact

Aim along the first conductor and cast. The closed gate must become the first solid body that stops Grace. A valid result requires an actual contacted Flash with enough travel distance and an endpoint near the gate.

### II. The Open Circuit

The floor ends. The far platform begins beyond a chasm, and its closed gate is within Flash's 24-meter line.

Aim across the gap and let the far gate stop the bolt. There is no ground beneath most of the route and no landing correction at the end.

The chamber's central advice is concise:

```text
DO NOT AIM UP.
```

Upward attempts are counted but do not solve the room. Falling below the trial restores Grace to the most recent conductor checkpoint.

### Mastery

Enter the gold seal after the far gate opens.

```text
AIM • BECOME • CONTACT
```

Completion records:

```text
thunderline_flash_spell_trial_complete
```

The development trial restores resources and regenerates 2 Mana per second.

## Reset

F8 restores:

- Grace's initial transform, velocity, and visibility;
- Flash selection;
- health, Mana, stamina, and stance;
- both contact gates;
- the active checkpoint;
- upward-attempt and fall-recovery counters;
- the trial completion flag;
- any fading Flash trail or visual token;
- active Surf or dodge states created during an attempt.

## Focused playtest

1. Open the Thunderline and confirm Flash appears under Lightning with the `↯` symbol.
2. Assign Flash to a quick slot and verify Focus remains unchanged.
3. Cast into a nearby wall. Grace should stop immediately before it.
4. Cast down the first corridor. The travel distance should expand until the closed gate.
5. Try a diagonal line into a side wall and confirm first contact still wins.
6. Cross the open chasm by aiming at the far gate.
7. Aim upward in the chasm and observe that Flash does not invent a landing.
8. Cast Flash while Surf is active and confirm the wave continues from the destination.
9. Compare controller vibration for an open-space Flash and a wall-contact Flash.
10. Watch F7 during repeated casts. `SPELL FX` should flicker by one and return to baseline; `PERSISTENT` should remain unchanged.
11. Enter the mastery seal.
12. Press F8 and confirm the complete Thunderline resets.
