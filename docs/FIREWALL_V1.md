# Firewall v1

Firewall is a Fire spell that turns camera aim into a temporary line-drawing tool. Hold Cast to laser-etch a path onto architecture, then release to make the complete path erupt into lingering flame.

## Player contract

```text
Mana cost:          4 upfront
Maximum draw time:  2.7 seconds
Maximum path:       18 meters
Maximum aim range:  12 meters
Wall height:        2.2 meters
Lingering time:     3.2 seconds
Fade time:          0.4 seconds
```

The draw ends and ignites when:

- Cast is released;
- the 2.7-second timer expires;
- the path reaches its length or point budget.

Changing spells, being staggered, dodging, guarding, interacting, or otherwise losing the cast channel cancels an unfinished drawing instead of igniting it.

Movement remains available during drawing. That includes Surf, so Grace can etch a moving route before releasing the spell. Other attacks and spells remain blocked until the drawing ends.

## Surface path

The camera-center ray is authoritative. The orange laser starts at Grace's casting hand but records the position and normal of the surface under the reticle.

Base drawable surfaces include:

- `StaticBody3D` architecture;
- `GridMap` geometry;
- `CSGShape3D` geometry;
- `AnimatableBody3D` surfaces;
- nodes explicitly placed in `firewall_drawable_surface`;
- dynamic nodes explicitly placed in `firewall_dynamic_surface`.

Enemies and arbitrary rigid bodies are not treated as drawing paper by default.

Each sample stores:

```text
world position
surface normal
surface category: floor / wall / ceiling
collider identity
```

Points are resampled at roughly 0.34-meter spacing, with an eighteen-meter total cap. Large reticle jumps are rejected rather than connected through empty air.

## Edge continuity

When adjacent samples have sharply different normals, Firewall does not connect them with one diagonal chord through the corner.

For a floor-to-wall edge, the spell projects the previous point onto the wall plane and the next point onto the floor plane. Those projected points lie along the architectural seam. The path is then resampled through that seam while its normal blends toward the new surface.

```text
floor sample
    ↓
projected floor-side corner
    ↓
blended seam samples
    ↓
projected wall-side corner
    ↓
wall sample
```

The same rule handles wall-to-ceiling and wall-to-wall transitions. Opposing surfaces and implausibly large bridges are rejected.

The ignited presentation overlaps neighboring segments slightly and places elongated flame plumes at every joint. These plumes hide tiny visual cracks while allowing the wall direction to bend continuously around edges.

## Surface-relative eruption

The stored normal determines the direction of each flame segment:

```text
Floor normal up       → flame rises
Wall normal outward   → flame projects from the wall
Ceiling normal down   → flame burns downward
```

Firewall is therefore not a horizontal spline with decorative rotation. It is a three-dimensional surface path.

## Contact behavior

The lingering wall applies the authored Firewall payload on a rate limit:

```text
Health damage:     2
Stance damage:     1
Status:            Burning, 1.4 seconds
Repeat interval:   0.45 seconds per target
Thermal energy:    520 J/s at contact ticks
```

Collinear visual pieces are merged into longer contact segments before physics queries are issued. A long straight line may contain dozens of smooth visual samples but only one or two oriented contact boxes.

## Performance contract

Firewall uses one node for the entire lifecycle:

```text
Drawing:
1 laser mesh
1 surface-line MultiMesh
0 persistent effects

Ignited:
1 surface-line MultiMesh
1 outer-flame MultiMesh
1 inner-flame MultiMesh
1 joint-plume MultiMesh
1 unshadowed light
0 per-segment nodes
```

The flame presentation updates at 24 Hz. Contact checks run every 0.28 seconds against compressed line segments. Recasting replaces the previous Firewall belonging to Grace.

F7 should show one `SPELL FX` while drawing. After release, the same node becomes one `PERSISTENT` effect. Both counters return to baseline after expiration or replacement.

## The Ember Scriptorium

Launch:

```text
res://scenes/levels/prototypes/prototype_firewall_spell_trial_v1.tscn
```

### I. The Flat Script

Hold Cast and trace one long line across the three marked floor bands. Release to ignite it.

The trial requires a sufficiently long path whose samples remain primarily on the floor and inside the first chamber.

### II. The Turned Script

The second alcove contains a continuous floor, vertical wall, and ceiling underside.

Draw one uninterrupted path in this order:

```text
FLOOR → WALL → CEILING
```

The trial requires at least two surface transitions and verifies that the ordered surface sequence survived the corner bridges.

### Mastery

Enter the gold seal after the second gate opens.

```text
TRACE • TURN • IGNITE
```

Completion records:

```text
ember_scriptorium_firewall_trial_complete
```

The development trial regenerates 2 Mana per second.

## Reset

F8 restores:

- Grace's transform, velocity, visibility, and resources;
- Firewall selection;
- both progression gates;
- trial counters and completion state;
- all active Firewall drawing and lingering nodes;
- the temporary mastery flag.

## Focused playtest

1. Open the Ember Scriptorium and confirm Firewall appears under Fire with the `╫╫` symbol.
2. Hold Cast while aiming at the floor. Confirm the laser and glowing trace follow the reticle.
3. Release and confirm the line rises into a wall of flame.
4. Draw a short line and confirm it still produces a small valid wall rather than an empty cast.
5. Hold until the timer expires and confirm automatic ignition.
6. Complete the Flat Script.
7. In the second alcove, begin on the floor, move up the wall, then continue onto the ceiling underside.
8. Inspect both corners. The trace should bend through the seam instead of cutting diagonally through the blocks.
9. Walk an enemy or suitable thermal target into the lingering wall and confirm Burning and heat ticks.
10. Cast while Surf is active and confirm movement continues while the laser paints.
11. Watch F7. Drawing should add one temporary spell effect; ignition should convert it to one persistent effect; expiration should return both counters to baseline.
12. Enter the mastery seal and press F8 to verify the complete reset.
