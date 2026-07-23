# Tactical Navigation and Hazard-Aware Routing v1 Playtest

## Scene

`res://scenes/levels/prototypes/prototype_tactical_navigation_lab_v1.tscn`

## Purpose

Validate reusable enemy movement that follows Godot Navigation paths around solid architecture instead of steering directly into walls. The tactical layer compares multiple authored route anchors, queries actual Navigation paths through each candidate, measures path length, samples environmental hazard cost along the route, and chooses the lowest total cost for the enemy's personality.

The laboratory compares Cautious, Bold, Skittish, and Brute Gremlins in four isolated lanes. Each lane contains the same wall, a longer safe route on the left, and a shorter dangerous shortcut on the right.

## Controls

- Move: left stick or WASD
- Camera: right stick or mouse
- Start or restart the route trial: T
- Toggle shortcut danger: H
- Toggle route debug lines: V
- Reset laboratory: F8 in the editor

Grace is invulnerable and is not used as the enemies' live target in this laboratory. This prevents player movement from contaminating the controlled route comparison.

## Expected route

1. Launch the scene.
   - Four Gremlins should begin at the north end of their lanes.
   - The trial should start automatically after the NavigationServer has synchronized.
   - Each enemy should draw a path line that bends around its central wall.
2. Observe the first route choice while the green shortcut hazards are active.
   - Cautious should normally choose **SAFE LEFT**.
   - Skittish should normally choose **SAFE LEFT**.
   - Bold should normally choose **RISKY RIGHT**.
   - Brute should normally choose **RISKY RIGHT**.
3. Confirm wall navigation.
   - No enemy should continue pushing straight into the central wall.
   - The path should lead through the selected side opening and then toward the evidence beacon.
4. Let the enemies reach the evidence beacons.
   - They should transition from Investigating into Searching.
   - After the search timer expires, they should navigate back around the wall toward their original posts.
5. Press H while enemies are moving.
   - The green danger presentation should disappear.
   - Active route plans should be rescored immediately.
   - With danger disabled, the shorter right shortcut should dominate more often.
6. Press H again.
   - Shortcut danger returns.
   - Cautious and Skittish should prefer the longer safe route when they next replan.
   - Bold and Brute should continue accepting more risk.
7. Press T.
   - All four enemies should receive their lane-specific evidence destination again.
   - New route lines and scores should appear without requiring a scene reload.
8. Press V.
   - Route lines and route labels should hide.
   - Navigation, hazard scoring, searching, and returning should continue.
9. Press F8.
   - Enemies return to their starting posts.
   - Hazard state returns to active.
   - Grace, health, and mana reset.
   - A fresh route trial begins after Navigation synchronization.

## Debug readout

The large readout reports, per personality:

- awareness state
- selected route
- total route score
- geometric route distance
- integrated danger cost
- current stuck timer

Blue route lines indicate safe or left routes. Orange route lines indicate shortcut or right routes. Crosses mark active waypoints and the final evidence destination.

## Reusable architecture

### TacticalNavigationAgent

A reusable child component for `CharacterBody3D` actors. It owns a `NavigationAgent3D`, waits for the first physics-frame Navigation synchronization, requests paths through the default 3D navigation map, advances path points once per physics frame, detects stalled motion, and periodically replans.

For route selection it can score:

- a direct Navigation path
- any matching `TacticalRouteAnchor`
- geometric path distance
- sampled `TacticalNavigationHazard` cost
- optional route bias

The selected route is then followed through the ordinary `NavigationAgent3D` path logic.

### TacticalRouteAnchor

A world-space route hint with a route id, lane id, tags, enabled state, and optional score bias. Anchors do not move an actor directly. They provide candidate intermediate destinations that force the path query through meaningful alternatives such as a safe corridor or shortcut.

### TacticalNavigationHazard

A radial environmental cost field. Cost falls off with distance and is multiplied by personality tolerance:

- Cautious prices danger highly.
- Skittish prices it highest.
- Bold accepts substantial danger.
- Brute nearly ignores it.

Hazards can also be marked impassable for later dynamic blockers.

### EnemyTacticalNavigationBrain

Extends the existing Perception and Investigation brain. Visual pursuit, last-known-position pursuit, sound investigation, and return-home movement all use the tactical Navigation component when enabled. Combat remains inherited and can be enabled in a later integrated encounter.

## Current limitations

- The laboratory uses flat manually-authored NavigationMesh polygons rather than runtime baking.
- Route anchors are authored hints; v1 does not automatically discover every topologically distinct route in arbitrary level geometry.
- Dynamic hazard changes trigger cost replanning, but solid doors do not yet carve or rebake the NavigationMesh.
- Local separation is a lightweight steering blend rather than full RVO avoidance.
- Enemies do not jump, climb, fly, open doors, or break obstructions in v1.
- Hazard scoring samples along the candidate path and does not yet predict time-varying gas movement.
- Combat is disabled in this laboratory so route choice can be inspected without attack-state noise.

## Smoke test

`res://scenes/tests/tactical_navigation_smoke_test.tscn`

The smoke test checks the personality hazard-cost ordering, required Navigation regions, route anchors, hazards, tactical components, Navigation synchronization, nonempty paths, and the expected active-hazard route split.
