# Weathered Cloister Modular Environment Showcase v1 Manual Test

Scene:

```text
scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn
```

## Purpose

Evaluate the first reusable environment and prop kit as one coherent walkable set. This is a visual, collision, scale, and camera benchmark. It adds no quest, combat, progression, or traversal mechanic.

## Route

1. Walk through the weathered entrance arch without jumping.
2. Follow either side of the central water channel.
3. Cross between both cloister walks and inspect floor-to-channel transitions.
4. Circle the stone pillars and timber frames with the camera close behind Grace.
5. Walk continuously up the broad stair run without jumping or stopping at each riser.
6. Interact with the glowing gate lever.
7. Wait for the gate to open fully, then walk through the doorway without colliding with an invisible panel.
8. Inspect the pedestal, crate, barrel, and rear wall modules.
9. Return to the entrance using the opposite side of the cloister.

## Visual checks

- Stone floors should read as layered slabs while walking on continuous collision.
- Wall courses, trim, pilasters, moss, and shader variation should prevent the walls from reading as naked BoxMeshes.
- The arch should read as a built stone opening with visible voussoirs and a keystone.
- Pillars should have bases, shafts, bands, capitals, and stable collision.
- Timber frames should have posts, braces, pegs, and iron feet.
- The water channel should meet its stone basin cleanly without a floating plane or collision hole.
- Sconces should provide localized warm pools against the cooler environmental light.
- The stairs should look stepped while the traversal surface feels continuous under Grace.
- The gate should retain collision while closing, clear the doorway when fully open, and never leave a stale invisible blocker.
- Crate, barrel, and pedestal silhouettes should remain readable without floating labels.

## Collision and camera abuse

- Walk every floor seam and both edges of the water channel.
- Press against walls, arches, pillar bases, timber posts, gate piers, and the raised platform.
- Walk slowly and sprint up and down the stairs without jumping.
- Circle the gate while it is moving, then pass through from both directions after it opens.
- Try to wedge Grace between every prop and wall.
- Walk backward down the stairs with the camera close to the side cheeks.
- Deliberately leave the outer set boundary and confirm global recovery remains a last resort.
- Blink toward the arch, water channel, gate, raised platform, and exterior bounds.

## Acceptance

The pass succeeds when the set is comfortably traversable, visually more intentional than the procedural debug environments, and useful as a reference for future asset replacement. Grace must walk up the stairs without jumping and pass through the fully opened gate without touching stale collision. It does not need final production fidelity. Any repeated snag, visible collision mismatch, unreadable transition, or camera trap should be treated as a kit defect rather than patched only in the showcase.

Automated coverage:

```text
scenes/tests/modular_environment_showcase_smoke_test.tscn
```
