# Spatial Readability and Grace Silhouette v1

This milestone separates three ideas that were previously tangled together:

1. **physical clearance**, meaning Grace's capsule can pass;
2. **camera and composition clearance**, meaning the room remains comfortable to read;
3. **visual silhouette**, meaning Grace does not occupy more screen space than her role requires.

The Drowned Chapel is the first story-integrated reference.

## Canonical Grace spatial profile

```text
data/player/grace_spatial_profile.tres
scripts/player/player_spatial_profile.gd
scripts/player/player_spatial_profile_controller.gd
```

The shared player now carries one explicit profile for:

- capsule radius and height;
- safe-destination margin;
- visual silhouette measurements;
- robe, torso, arm, hand, sash, and boot proportions;
- land, swimming, and camera-comfort clearance;
- primary-route, camera-route, interaction, landmark, and combat radii.

`player.tscn` serializes the same capsule dimensions directly, then the controller reapplies the profile at runtime. This makes a fresh import, an instantiated player, the safe-destination query, and authored-space tooling agree about Grace's physical envelope.

The v1 silhouette narrows the robe hem and upper body pieces without changing Grace's face, hair, palette, outfit identity, animation hierarchy, or equipment hooks.

## Readability plans

A set may now declare protected routes and composition zones in compact JSON:

```json
{
  "routes": [
    {
      "id": "PrimaryRoute",
      "points": [[0, 0, 0], [0, 0, 12]],
      "clear_radius": 1.35,
      "camera_radius": 2.55,
      "max_physical_intrusions": 0,
      "max_visible_modules": 4
    }
  ],
  "zones": [
    {
      "id": "QuestObjectApproach",
      "kind": "interaction",
      "center": [2, 0, 8],
      "radius": 1.8,
      "max_physical_props": 0,
      "max_visible_modules": 3
    }
  ]
}
```

The plan does not choose the level's composition. It records the composition the authored level intends to protect.

## Readability auditor

```text
scripts/environment/authored_set_readability_auditor.gd
```

The auditor checks:

- active collision intruding into protected travel lanes;
- freestanding props occupying interaction or landmark approach zones;
- visible modular density inside camera envelopes;
- malformed route or zone data;
- the spatial profile used for the audit.

Physical intrusions are errors. High visual density is a warning because a numerical budget cannot fully judge whether a pillar, arch, tree, or shrine belongs in a composition.

Repeated floor, wall, arch, stair, and water-edge modules may be ignored by a plan so the audit focuses on tall structure, furniture, lights, and other objects that compete with the player or camera.

## Optional debug overlay

```text
scripts/environment/authored_set_readability_debug.gd
```

The debug overlay can draw:

- green travel lanes;
- blue camera envelopes;
- amber interaction zones;
- violet landmark zones;
- red combat zones.

It is off by default. Set `show_debug_zones` on a level's readability pass when tuning a layout, then disable it for normal play.

## Drowned Chapel application

```text
scripts/levels/drowned_bell_spatial_readability_pass.gd
data/set_layouts/drowned_chapel_readability_v1.json
```

The chapel pass waits for the modular benchmark and data-driven crypt passage, then:

- retires the middle west nave pillar;
- retires the middle timber frame;
- reduces six repeated sconces to four;
- removes the crate crowding the memorial aisle;
- moves the remaining crate and barrel into wall-side staging;
- reduces repeated resonance rings in the crypt passage;
- audits the nave route, pool approach, all required interaction approaches, and the two major chapel landmarks.

The removed objects remain named in the scene tree with collision disabled and `readability_retired` metadata. This keeps debugging and regression checks possible without leaving invisible blockers.

## Quality rules

For future authored spaces:

1. Define Grace's intended route before placing clutter.
2. Keep physical props outside the route's protected radius.
3. Leave a clear approach around every required interaction.
4. Protect at least one readable view of each major landmark.
5. Use density budgets as warnings, not as automatic art direction.
6. Prefer moving or removing repeated dressing before widening every room.
7. Keep final judgment in a human playtest, especially with the camera close behind Grace.

## Manual Drowned Bell check

Run:

```text
scenes/levels/prototypes/prototype_drowned_bell_v1.tscn
```

Then verify:

- Grace reads narrower from behind without looking stretched or losing the robe identity;
- the nave's center has visible breathing room;
- the memorial plaque no longer competes with a nearby crate;
- the bell rope and tuning plate have clean approach space;
- the camera can rotate through the nave without repeatedly colliding with the middle frame;
- the crypt passage uses fewer overlapping signal rings;
- the complete quest, swimming exits, Listener encounter, rewards, and aftermath remain unchanged.

## Next use

Apply the same profile and readability-plan contract to the Ruined Village Approach. That outdoor proof should determine whether the next reusable needs are ruined corners, low walls, road edges, terrain transitions, vegetation-density zones, or open combat-space declarations.
