# Firewall v2

Firewall is a Fire spell that turns camera movement into a temporary surface-painting tool. Hold Cast to laser-etch a path onto architecture, then release to make the complete path erupt into lingering flame.

## Player contract

```text
Mana cost:          4 upfront
Maximum draw time:  3.4 seconds
Maximum path:       18 meters
Maximum aim range:  12 meters
Wall height:        2.2 meters
Lingering time:     3.2 seconds
Fade time:          0.4 seconds
```

The draw ends and ignites when:

- Cast is released;
- the 3.4-second timer expires;
- the path reaches its length or point budget.

Changing spells, opening Focus, being staggered, dodging, guarding, interacting, or otherwise losing the cast channel cancels an unfinished drawing instead of igniting it.

Movement remains available during drawing. That includes Surf, so Grace can paint a moving route before releasing the spell. Other attacks and spells remain blocked until drawing ends.

## Camera-brush aiming

Firewall no longer moves the independent Flash-style pointer while freezing the camera. Its reticle remains centered and normal look input becomes a slower drawing camera.

```text
Hold Cast
    ↓
Reticle stays centered
    ↓
Mouse / right stick turns Grace and the camera
    ↓
Center ray paints the current surface
```

The brush temporarily expands camera pitch to roughly:

```text
84 degrees upward
78 degrees downward
```

This permits one natural motion from looking down at the floor, through a wall, and toward a ceiling underside. The pre-cast camera pitch and ordinary third-person limits return immediately after release or cancellation. R3 restores the pre-cast pitch during drawing.

Mouse and controller sensitivity are reduced while the brush is active, giving the line more drafting-table precision and less caffeinated seismograph.

## Adaptive stroke continuity

Camera movement can still move the aim ray farther than the path's legal surface-gap distance in one sample, particularly at low frame rate or across large depth changes.

Firewall stores the previous brush ray. When the current ray moved too far in angle or origin, the spell casts a bounded sequence of intermediate rays between them.

```text
Previous ray
    ↓
1–12 intermediate rays when needed
    ↓
Current ray
    ↓
Recovered surface contacts become one batch
```

This behavior:

- fills fast legitimate sweeps across the same floor or wall;
- provides more samples near architectural corners;
- does not connect through empty air;
- preserves the existing maximum-gap and opposing-surface rejection rules;
- rebuilds the glowing line once per batch, not once per recovery ray.

The ordinary sample interval is now 0.02 seconds. Surface resampling uses roughly 0.24-meter spacing with a 96-point cap.

## Surface path

The orange laser begins at Grace's casting hand, while the centered reticle chooses the contacted surface. Each accepted sample stores:

```text
world position
surface normal
surface category: floor / wall / ceiling
collider identity
```

Base drawable surfaces include:

- `StaticBody3D` architecture;
- `GridMap` geometry;
- `CSGShape3D` geometry;
- `AnimatableBody3D` surfaces;
- nodes explicitly placed in `firewall_drawable_surface`;
- dynamic nodes explicitly placed in `firewall_dynamic_surface`.

Enemies and arbitrary rigid bodies are not treated as drawing paper by default.

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

The same rule handles wall-to-ceiling and wall-to-wall transitions. Opposing surfaces and implausibly large bridges remain rejected.

Neighboring flame segments overlap slightly, while elongated joint plumes hide tiny cracks and rotate the presentation through the corner.

## Surface-relative eruption

The stored normal determines the direction of each flame segment:

```text
Floor normal up       → flame rises
Wall normal outward   → flame projects from the wall
Ceiling normal down   → flame burns downward
```

Firewall is therefore a true three-dimensional surface path rather than a horizontal spline with decorative rotation.

## Contact behavior

The lingering wall applies the authored Firewall payload on a rate limit:

```text
Health damage:     2
Stance damage:     1
Status:            Burning, 1.4 seconds
Repeat interval:   0.45 seconds per target
Thermal energy:    520 J/s at contact ticks
```

Collinear visual pieces are merged into longer contact segments before physics queries are issued. A smooth line may contain dozens of visual samples but only a few oriented contact boxes.

## Performance contract

Firewall uses one node for the entire lifecycle:

```text
Drawing:
1 laser mesh
1 surface-line MultiMesh
1 centered reticle
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

F7 should show one `SPELL FX` while drawing. After release, the same node becomes one `PERSISTENT` effect. Both return to baseline after expiration or replacement.

## The Ember Scriptorium

Launch:

```text
res://scenes/levels/prototypes/prototype_firewall_spell_trial_v1.tscn
```

### I. The Flat Script

Hold Cast, look down, and sweep the centered brush across the three marked floor bands. Release to ignite it.

The trial requires a sufficiently long path whose samples remain primarily on the floor and inside the first chamber.

### II. The Turned Script

The second alcove contains a continuous floor, vertical wall, and ceiling underside.

Draw one uninterrupted path in this order:

```text
FLOOR → WALL → CEILING
```

Begin with the camera pitched down. Sweep upward while the brush is active, allowing Grace and the camera to turn through the full route. The trial requires at least two recorded surface transitions and verifies that the ordered sequence survived the corner bridges.

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
- ordinary camera pitch and look limits;
- Firewall selection;
- both progression gates;
- trial counters and completion state;
- all active Firewall drawing and lingering nodes;
- the temporary mastery flag.

## Focused playtest

1. Open the Ember Scriptorium and equip Firewall.
2. Hold Cast and confirm the reticle stays centered.
3. Confirm mouse or right-stick input turns Grace and the camera at reduced sensitivity.
4. Look sharply down and draw near Grace's feet.
5. Sweep quickly across a long floor section and confirm the glowing trace remains connected.
6. Complete the Flat Script.
7. In the second alcove, look down at the floor, sweep up the wall, then continue onto the ceiling underside.
8. Inspect both corners for seam-following continuity rather than diagonal cuts through the blocks.
9. Release and confirm the camera returns to its pre-cast pitch.
10. Cast while Surf is active and confirm movement continues while the camera brush paints.
11. Walk an enemy or thermal object into the wall and confirm Burning and repeated heat.
12. Watch F7 through drawing, ignition, expiration, and recasting.
13. Enter the mastery seal and press F8 to verify the complete reset.
