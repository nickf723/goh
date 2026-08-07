# Lightning Spark v2

Lightning Spark is a short-range forward cone burst. It is no longer a generic projectile.

## Player contract

- Tap Cast once for an immediate burst.
- Range: 4.8 meters.
- Half-angle: 38 degrees.
- Every exposed target inside the cone receives the same Lightning payload once.
- Solid architecture blocks targets behind it.
- Other valid combat targets do not block the fan from reaching targets farther along the same opening.
- Mana cost remains 1.

The spell deals 2 health damage, 3 stance damage, and applies Stunned for 0.45 seconds. Wet and conductive targets continue to participate in the shared reaction grammar through the Lightning payload tags.

## Procedural presentation

Each cast generates a fresh branching pattern. The runtime uses one `MultiMeshInstance3D` with a maximum of 56 box segments. It does not create a Node, Area3D, light, or process callback for each visible spark.

Performance contract per cast:

```text
1 bounded sphere query
angle + range filtering
line-of-sight rays only for candidate targets
1 MultiMesh visual
1 short OmniLight flash
0 per-segment nodes
0 persistent spell effects
~0.18 second lifetime
```

## Haptics

Lightning Spark uses a short crack-buzz-snap pattern:

```text
strong crack
silent gap
weak high-frequency buzz
silent gap
smaller closing snap
```

The pattern is played through `ControllerHapticPattern`, which uses Godot's weak and strong gamepad vibration motors. Only one short pattern for the same caster is allowed at a time; recasting replaces the previous pattern. With no compatible controller, the spell continues normally and the haptic node removes itself immediately.

The controller looks for either:

```text
source actor metadata: controller_vibration_scale
or
PlayerPreferences preference: controller_vibration_scale
```

and otherwise uses full authored strength. A value of `0.0` disables vibration without changing spell behavior.

## Forked Conduit trial

Launch:

```text
res://scenes/levels/prototypes/prototype_lightning_spark_spell_trial_v1.tscn
```

### I. Forked Fan

Stand on the indigo casting mark. Three two-health conductors fit inside one correctly centered Lightning Spark cone. The blue witness is close enough to see the burst, but sits outside the authored cone angle and should remain unharmed.

### II. Broken Sightline

A stone shield blocks the direct line to the final conductor. Move around the left or right edge, enter short range, and cast from a clear angle. The spell does not damage through the shield.

### Mastery

Enter the gold seal after both gates open.

```text
FAN • FLANK • INTERRUPT
```

The development trial restores Mana on entry and regenerates 2 Mana per second. Stamina and Focus regeneration remain disabled.

## Reset

F8 restores:

- Grace's transform and velocity;
- full Mana and Lightning Spark selection;
- all four conductors and the outside-cone witness;
- both gates;
- trial progression and completion flag;
- every active Lightning Spark visual;
- every active controller haptic pattern.

## Focused playtest

1. Open the Forked Conduit.
2. Confirm Lightning Spark is equipped and still uses the lightning glyph.
3. Stand on the first indigo mark and cast once.
4. Confirm all three conductors are struck by the same fan.
5. Confirm the outside-cone witness remains at full health.
6. Repeat several casts and confirm the branch pattern changes without creating lingering `SPELL FX` or `PERSISTENT` counts.
7. With a controller, feel for a strong crack, a brief electrical buzz, and a smaller closing snap.
8. Walk to the second chamber and cast directly into the shield. The conductor should remain untouched.
9. Flank the shield and cast from short range. The conductor should be struck.
10. Enter the mastery seal.
11. Press F8 and confirm the complete trial and any active vibration reset.
12. Keep F7 visible during repeated casts. The frame rate should remain green, with one temporary spell effect and no persistent effect.
