# Surf v1

Surf is a Water traversal spell that turns continued movement into a fast, committed ride on a compact wave.

## Player contract

- Mana cost: 3 upfront.
- Cast once to form the wave beneath Grace.
- Launch speed: 8.5 m/s.
- Maximum speed: 12.5 m/s.
- Steering is capped at 72 degrees per second.
- Releasing movement collapses the wave after roughly 0.22 seconds.
- A brief 0.34-second startup grace lets the player press movement immediately after casting.
- Being blocked, airborne too long, defeated, staggered, or entering a dodge ends Surf.
- Recasting refreshes the existing controller rather than stacking another wave.

Surf temporarily owns Grace's root physics movement. The ordinary player locomotion script is disabled only while the wave is active and restored immediately when Surf ends. Camera input, UI, spell selection, and child gameplay controllers continue processing.

## Surface hazards

Surf protects Grace only from payloads explicitly authored as surface or terrain hazards.

Recognized contracts include:

```text
hit_type = surface_hazard
hit_type = terrain_hazard

tags:
surface_hazard
terrain_hazard
ground_hazard
lava_surface
spike_floor
```

Ordinary Fire attacks, enemy weapons, projectiles, explosions, and airborne hazards are not blocked merely because Surf is active.

`SurfaceHazardArea` is the reusable authoring component for lava, spike floors, acid ground, hot coals, and similar terrain. It sleeps when no supported body occupies it and sends its tagged payload through the ordinary player-defense pipeline. Surf converts that payload to a zero-damage skim result; the same area damages Grace normally after the wave collapses.

## Performance contract

Surf uses one reusable controller attached to Grace on its first cast.

```text
Inactive:
0 physics callbacks
0 rendered wave geometry
0 spell-effect group entries

Active:
1 locomotion controller
2 reused water meshes
1 MultiMesh foam crest
0 per-foam nodes
30 visual updates per second
0 overlap queries
```

F7 should show one temporary `SPELL FX` and one `PERSISTENT` effect while Surf is active. Both return to their previous values after idle cancellation or another ending condition.

## Focus and quickbar repair

Focus now reads from `AbilityLoadout.learned_abilities`, while the permanent ten-slot quickbar stores shortcut spell IDs separately.

```text
Learned library → Focus contents
Saved shortcut IDs → quickbar contents
Runtime equipped array → current cast resolution
```

Replacing a quick slot therefore no longer removes, duplicates, or reorders that spell in Focus. Selecting a learned spell that no longer has a runtime copy appends a reserve runtime entry without changing any of the ten shortcut assignments.

## Riptide Causeway

Launch:

```text
res://scenes/levels/prototypes/prototype_surf_spell_trial_v1.tscn
```

### I. Momentum Run

Cast Surf, hold movement, and cross the gold threshold above 9.5 m/s. The gate rejects ordinary running and underdeveloped wave speed.

### II. Hazard Slalom

Maintain Surf through both a lava strip and a spike floor while steering around solid pylons. The final trigger requires:

- an active Surf wave;
- at least one Surf-negated lava contact;
- at least one Surf-negated spike-floor contact.

Stopping inside either strip collapses the wave and restores ordinary hazard damage.

### Mastery

Enter the gold seal after the hazard gate opens.

```text
DRIVE • GLIDE • KEEP MOVING
```

The development trial restores Mana on entry and regenerates 2 Mana per second. Stamina and Focus regeneration remain disabled.

## Reset

F8 restores:

- Grace's transform, velocity, health, stance, and Mana;
- ordinary player physics ownership;
- Surf selection;
- both gates;
- both hazard counters;
- trial stage and completion flag;
- every Surf effect-group entry and active wave visual.

## Focused playtest

1. Open the Riptide Causeway.
2. Confirm Surf appears under Water in Focus with its `≈>` symbol.
3. Replace Surf or another spell in the permanent quickbar and confirm the Water Focus list does not change.
4. Assign Surf to a quick slot from Focus and confirm both interfaces remain usable.
5. Cast Surf without moving and confirm it collapses after the startup grace.
6. Cast while moving and confirm Grace rapidly accelerates.
7. Attempt a sharp ninety-degree turn and confirm the wave bends gradually rather than snapping.
8. Cross the first gold threshold above 9.5 m/s.
9. Ride across the lava and spike strips while steering through the pylons.
10. Release movement inside a hazard and confirm Surf collapses and the terrain becomes dangerous again.
11. Complete both hazard skims in one active run and enter the mastery seal.
12. Press F8 and confirm the full trial resets.
13. Keep F7 visible during repeated attempts. Active Surf should add exactly one temporary and one persistent spell effect, then cleanly remove both.
