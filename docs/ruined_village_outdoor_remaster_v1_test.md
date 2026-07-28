# Ruined Village Approach Outdoor Remaster v1 Manual Test

Scene:

```text
scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn
```

## Purpose

Prove that the modular environment, Authored Set Composer, Grace spatial profile, and spatial-readability contracts can carry a large outdoor story route without replacing its working exploration, combat, elemental puzzles, Sound discovery, persistence, checkpoint, or Church Trial handoff.

## Preserved route

```text
Teleport Impact Hollow
→ Abandoned Armory
→ Outer Foundations and Clues
→ Village Square and optional Sound memory
→ Goblin / Gremlin Ambush
→ Two ravine solutions
→ Church Hill
→ Church Grounds checkpoint
→ Church Trial entrance
```

## Outdoor modular family

The remaster should visibly use the reusable outdoor vocabulary:

- weathered village-road modules;
- low ruined walls;
- ruined wall corners;
- ruined doorway façades;
- timber fences;
- nonblocking rubble clusters;
- olive-tree clusters.

Repeated construction should read as one village family rather than isolated primitive boxes. Story landmarks such as the crater, displaced foundation, dry well, empty hearth, fallen angel statue, ravine puzzle structures, and church silhouette remain authored for this level.

## Route and readability checks

1. From Grace's starting point, identify the road into the village and the church silhouette beyond it.
2. Walk from the crater to the abandoned armory without jumping over decorative lips.
3. Follow the main village road through the outer foundations. The route should remain broad enough for a full camera sweep.
4. Approach the arrival crater, lifted foundation, and empty hearth from several angles. Modular walls, rubble, trees, and fences must not occupy their interaction halos.
5. Enter the village square and circle the dry well with the camera close behind Grace.
6. Fight the three-enemy ambush using ordinary movement and dodge space. Props and vegetation must stay outside the protected combat clearing.
7. Find and reveal the optional Sound memory. Its side path should feel discoverable without competing with the primary road.
8. Test both ravine routes. The elemental targets, bridge edges, and ascent routes must remain readable after the visual remaster.
9. Climb the church hill without jumping over stair or road transitions.
10. Reach the save bed and Church Trial entrance without a modular prop blocking either approach.

## Collision ownership

- Original terrain, broad foundations, ramps, ravine structures, and other proven traversal geometry remain the support shell.
- Their obsolete meshes may be hidden while collision remains active.
- Modular architecture placed over support geometry should use disabled duplicate collision.
- Freestanding low walls and fences may retain collision only when deliberately used as boundaries.
- Rubble and vegetation dressing should be nonblocking unless the route plan explicitly assigns a physical role.
- No module seam should cause vibration, invisible lips, or recovery during ordinary play.

## Gameplay regression

Confirm that the remaster does not change:

- three environmental clues;
- optional Sound-memory reveal;
- village-square encounter composition and completion reward;
- Fire solution for the debris gate;
- Ice plus Heavy solution for the debris gate;
- Water then Ice bridge solution;
- persistent route restoration after save reload;
- church-ground checkpoint;
- deliberate Church Trial transition;
- weather and concentration systems;
- the shared player loadout and controller bindings.

## Visual review

Judge the route on these questions:

1. Does the church remain visible as a destination without turning the village into a straight corridor?
2. Do open road, detail clusters, combat clearing, ravine, and church approach have distinct visual rhythms?
3. Is vegetation framing the route rather than forming a hedge around Grace?
4. Do ruined corners and façades suggest interrupted homes without obscuring the clean-cut absence central to the village story?
5. Does the village feel materially related to the Drowned Chapel kit while retaining a drier outdoor identity?
6. Are there enough quiet spaces between ruins, trees, rubble, and labels?

## Acceptance

The pass succeeds when the full route is comfortably playable without debug shortcuts, the church and major clues remain legible, the square supports combat, both ravine solutions remain understandable, and the modular outdoor family looks reusable beyond this one village. Any repeated snag, blocked prompt, hidden clue, overcrowded route, or misleading landmark should be treated as an outdoor-kit or layout defect rather than patched with another gameplay exception.

Automated coverage:

```text
scenes/tests/ruined_village_approach_smoke_test.tscn
```

The smoke test includes the outdoor-remaster regression fixture, but human playtesting remains authoritative for long sightlines, camera comfort, vegetation density, combat space, and overall visual rhythm.
