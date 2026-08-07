# Spell Aim Modes v2

Precision spells now share one reticle component but may choose between two different look-input models.

## Mode A: independent pointer

Flash uses a free screen-space pointer because it asks the player to choose one direction and then commit.

```text
Mouse motion / right stick
        ↓
Moves the pointer across the screen
        ↓
Camera remains stable
        ↓
Spell samples the pointer's camera ray
```

The logical pointer may continue beyond the visible viewport. Its visible indicator clamps to the edge and becomes a directional arrow while the projected ray keeps growing steeper. R3 / Lock-On recenters it.

This remains the correct model for one-point or one-direction decisions such as Flash.

## Mode B: camera brush

Firewall is a continuous drawing spell, so it no longer moves an independent reticle while freezing the camera.

```text
Hold Cast
    ↓
Centered reticle remains fixed
    ↓
Mouse / right stick rotates Grace and the camera
    ↓
Camera pitch temporarily expands
    ↓
The center ray paints the current surface
```

The brush uses reduced look sensitivity and temporarily widens the normal camera pitch from its ordinary third-person limits to approximately 84 degrees upward and 78 degrees downward. This lets a single stroke begin on the floor, travel up a wall, and continue onto a ceiling while Grace visibly turns through the route.

When drawing ends, the pre-cast camera pitch and normal limits are restored. Yaw remains where the player turned, so the world direction of the completed stroke is preserved.

R3 restores the pre-cast pitch while the brush is active.

## Adaptive stroke reconstruction

Continuous drawing cannot assume that every rendered frame produces a nearby surface contact. Fast mouse movement, controller acceleration, low frame rate, and perspective depth can move the center ray several meters between samples.

Firewall now compares the previous and current camera rays. If either the ray angle or camera origin moved too far, it inserts a bounded set of intermediate rays before applying the ordinary surface-gap rule.

```text
Previous camera ray
        ↓
Intermediate ray bundle
        ↓
Current camera ray
        ↓
Surface hits are resampled into one path
```

The bundle is capped at twelve rays per drawing sample. All recovered points are added as one batch, so the surface-line MultiMesh rebuilds only once rather than once per intermediate ray.

This fills legitimate fast sweeps across one surface or around a visible edge without allowing the line to leap through empty air. Invalid intermediate rays remain invalid, and implausible surface jumps are still rejected.

## Shared reticle responsibilities

Both modes reuse the same player-owned reticle for:

- ownership arbitration;
- color and validity state;
- surface or direction status text;
- screen-safe presentation;
- cleanup when the owner is replaced or freed.

Only independent-pointer mode captures look input. Camera-brush mode leaves look input with Grace's camera controller while keeping the reticle centered.

## Flash integration

Flash keeps its hold-and-release lifecycle:

```text
Press Cast   → enter independent pointer aim, spend no Mana
Hold Cast    → choose a full 3D direction
Release Cast → pay Mana and resolve Flash instantly
Cancel       → spend no Mana
```

The pointer reports strongly upward and downward lines. Flash still performs no safe-landing search.

## Firewall integration

Firewall now uses the camera brush:

- the laser begins at Grace's casting hand;
- the centered reticle reports floor, wall, ceiling, or an invalid surface;
- camera look is slowed for deliberate drawing;
- vertical pitch expands for floor-to-wall-to-ceiling strokes;
- adaptive ray subdivision fills fast legitimate sweeps;
- the final surface sample is captured before release;
- ordinary camera pitch returns as soon as the wall erupts.

## Performance contract

```text
Inactive reticle:
0 processing callbacks
0 visible pointer UI

Independent pointer active:
1 CanvasLayer
1 guide Line2D
1 reticle panel
2 labels
0 physics polling

Firewall camera brush:
same reticle UI
1 surface ray per ordinary sample
up to 12 rays only when motion requires recovery
1 surface-line rebuild per sample batch
```

## Regression scenes

```text
res://scenes/tests/spell_aim_pointer_smoke_test.tscn
res://scenes/tests/lightning_flash_smoke_test.tscn
res://scenes/tests/firewall_spell_smoke_test.tscn
```

Coverage includes:

- independent-pointer overflow above and below camera pitch;
- edge-clamped off-screen indicators;
- mouse pointer motion and recentering;
- Firewall camera-brush ownership;
- temporary expanded pitch and restoration;
- adaptive recovery of a fast floor sweep;
- Flash aim without upfront Mana spending;
- committed and cancelled Flash behavior;
- Flash collision, open range, upward travel, Surf preservation, and cleanup.

## Focused playtest

1. Equip Firewall and hold Cast.
2. Confirm the reticle remains centered while mouse or right-stick input rotates the camera.
3. Compare the slower brush sensitivity with ordinary camera movement.
4. Begin looking sharply down, draw across the floor, sweep up the wall, and continue toward the ceiling.
5. Move the camera quickly across a long floor section and confirm the glowing trace remains connected.
6. Release and confirm the camera returns to its pre-cast pitch.
7. Equip Flash and hold Cast.
8. Confirm Flash still moves the independent pointer while the camera stays stable.
9. Push the Flash pointer above and below the visible screen, then tap R3 to recenter.
10. Confirm both modes return ordinary camera control immediately after release or cancellation.
