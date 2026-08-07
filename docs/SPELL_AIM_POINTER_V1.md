# Spell Aim Pointer v1

The spell aim pointer decouples precision spell direction from the ordinary third-person camera pitch limits.

## Core behavior

When an owning spell enters pointer aim:

```text
Mouse motion / right stick
        ↓
Moves the pointer across the screen
        ↓
Camera remains stable
        ↓
Spell samples the pointer's camera ray
```

The pointer begins near screen center and captures the same look inputs that normally rotate the camera. R3 / the existing Lock-On input recenters it while aim is active.

The pointer is one reusable player component. Spells claim and release it by owner rather than creating separate reticles or competing input modes.

## Virtual off-screen aim

The logical pointer may continue beyond the visible viewport.

```text
Visible pointer reaches screen edge
        ↓
Indicator becomes an arrow
        ↓
Logical pointer continues beyond the edge
        ↓
Camera projection extrapolates a steeper ray
```

This is the key to escaping the camera's ordinary vertical range. A pointer pushed well above the screen can approach a near-vertical upward ray; one pushed below can target ground almost beneath the camera.

The visible indicator remains clamped inside a configurable screen margin, so the UI never disappears even when the authored ray is off-screen.

## Inputs

### Mouse

Captured mouse motion moves the pointer directly while an owning spell is aiming. Camera rotation resumes when the pointer is released.

### Controller

The right stick moves the pointer at a screen-space speed with deadzone remapping. It does not rotate the camera while pointer aim is active.

### Recenter

The existing Lock-On input recenters the pointer during aim instead of changing target lock.

## Firewall integration

Firewall claims the pointer when its drawing channel begins.

- The laser still originates at Grace's casting hand.
- Surface samples come from the pointer's camera ray.
- Pointer color and status report floor, wall, ceiling, or rejected surface.
- The pointer remains active through the final release sample.
- Camera control returns as soon as eruption begins.

This lets Firewall trace near-ground surfaces, tall walls, ceiling undersides, and off-screen transitions without dragging the entire camera through the same motion.

## Flash integration

Flash now uses a hold-and-release lifecycle:

```text
Press Cast   → enter pointer aim, spend no Mana
Hold Cast    → move the pointer through full 3D direction space
Release Cast → pay Mana and resolve Flash instantly
Cancel       → spend no Mana
```

The pointer reports when the line is strongly upward or downward. The warning is informational only. Flash still performs no safe-landing search.

A quick tap remains valid: it produces a near-center Flash after the minimum aim grace.

## Performance contract

```text
Inactive:
0 processing callbacks
0 visible pointer UI

Active:
1 CanvasLayer
1 guide Line2D
1 reticle panel
2 labels
0 physics polling
```

The pointer updates only on input, status changes, or viewport resizing. Firewall continues sampling at its existing bounded interval; Flash performs its real capsule-profile sweep only after release.

## Regression scenes

```text
res://scenes/tests/spell_aim_pointer_smoke_test.tscn
res://scenes/tests/lightning_flash_smoke_test.tscn
```

Coverage includes:

- upward and downward rays beyond the camera-center pitch;
- edge-clamped off-screen indicators;
- mouse pointer motion and recentering;
- Firewall ownership and release;
- Flash aim without upfront Mana spending;
- committed and cancelled Flash behavior;
- Flash collision, open range, upward travel, Surf preservation, and effect cleanup.

## Focused playtest

1. Equip Firewall and hold Cast.
2. Move the right stick or mouse without rotating the camera.
3. Push the pointer below the screen edge and draw on the floor near Grace.
4. Carry it up a wall and beyond the top edge toward a ceiling underside.
5. Release and inspect the corner continuity.
6. Equip Flash and hold Cast.
7. Move the pointer above and below the visible screen.
8. Tap R3 to recenter.
9. Release horizontally into a wall, then test a steep upward line somewhere recoverable.
10. Cancel a Flash aim by switching spells and confirm no Mana was spent.
11. Confirm ordinary camera controls return immediately after Firewall release, Flash release, or cancellation.
