# Spatial Portal Laboratory v1

## Purpose

Validate that a linked portal pair transforms position, orientation, linear velocity, rigid-body angular velocity, and projectile direction through the same reusable spatial mapping.

## Launch

Run:

`res://scenes/levels/prototypes/prototype_spatial_portal_lab_v1.tscn`

The laboratory is also available from the Development Control Center as **Spatial Portal Laboratory**.

## Controls

- **Move / Camera:** normal traversal controls.
- **Interact:** cycle the moving orange exit and relaunch the blue momentum crate.
- **Cast:** fire the equipped Firebolt.
- **Reset:** reload the complete laboratory.

## Manual route

1. Watch the blue momentum crate enter the central blue portal at approximately 12 m/s.
2. Confirm it emerges from the orange exit in the exit's new forward direction without an obvious speed loss.
3. Press **Interact** twice. Each press must relocate and rotate the orange exit, update its world label, and relaunch a fresh crate.
4. Run Grace through the central blue portal. She must emerge upright near the orange exit with her movement redirected.
5. Move to the left station and watch the steel orb fall through the floor portal.
6. Confirm the orb emerges from the overhead portal still moving downward and continues to accelerate over repeated loops.
7. Move to the gold casting marker in the right station.
8. Aim through the blue portal and use **Cast**.
9. Confirm Firebolt emerges from the gold portal traveling sideways toward the wooden target.
10. Read the compact HUD. Its latest crossing, absolute speed difference, current exit configuration, and loop-orb speed should update.
11. Use **Reset** and confirm the player, portals, orb, crate, and target return to their initial state.

## Automated contract

Run:

`res://scenes/tests/spatial_portal_smoke_test.tscn`

The test verifies:

- round-trip position and orientation mapping;
- vector-magnitude conservation;
- CharacterBody velocity transformation and reentry cooldown;
- GenericProjectile velocity and direction transformation;
- all three linked pairs and their visible laboratory fixtures.

## Intentional limitations

- Portal interiors are readable emissive surfaces, not recursive rendered views.
- Portals are authored whole surfaces; they do not cut arbitrary openings into level meshes.
- Characters remain upright after traversal because the current player controller assumes world-up gravity.
- Ropes, chains, Metal Tether, gas volumes, navigation agents, and enemy decision-making do not cross portal boundaries in v1.
- Collision continuity is teleport-based; an object cannot straddle both spaces at once.
