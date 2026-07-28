# Drowned Chapel Benchmark Remaster v1

Scene:

```text
scenes/levels/prototypes/prototype_drowned_bell_v1.tscn
```

## Purpose

Prove that the Weathered Cloister modular environment kit can carry a complete authored quest space rather than only a dedicated showroom. The remaster changes the chapel's repeated architecture and prop presentation while preserving the finished Drowned Bell quest, Global Playability contracts, swimming routes, interactions, Listener encounter, persistence, and three resolution paths.

The later Spatial Readability pass protects travel lanes, camera breathing room, interaction approaches, and Grace's screen-space silhouette without changing the quest.

## Construction boundary

The remaster uses reusable modular scenes for visible repeated architecture:

- causeway and chapel floors;
- stacked exterior and interior masonry walls;
- entrance and crypt arches;
- nave pillars and timber frames;
- wall sconces;
- water-transition trim;
- altar stairs and presentation pedestals;
- crates and barrels.

The existing authored environment remains underneath as a continuous support shell. Replaced support meshes are hidden, but their collision stays active. Modular architecture over that shell disables duplicate collision. Freestanding props retain their own collision.

The following landmarks remain bespoke:

- the memorial arcade;
- the bell frame and bell;
- the rose window;
- the broken pew arrangement;
- the pool shape and swimming exits;
- the burial mechanism and tuning plate;
- the crypt and Listener chamber story machinery.

## Spatial readability contract

Canonical files:

```text
data/player/grace_spatial_profile.tres
data/set_layouts/drowned_chapel_readability_v1.json
scripts/environment/authored_set_readability_auditor.gd
scripts/levels/drowned_bell_spatial_readability_pass.gd
```

The chapel now deliberately uses:

- four visible nave pillars rather than five;
- two major timber frames rather than three;
- four wall sconces rather than six;
- two wall-staged physical storage props rather than three route-adjacent props;
- fewer repeated resonance rings inside the crypt passage.

The middle west pillar, middle timber frame, middle sconce pair, memorial-aisle crate, and two tunnel rings remain named but visually retired with collision disabled. The remaining crate and barrel are moved toward the walls.

Protected routes and zones cover:

- the entrance-to-altar golden path;
- the flooded side-chapel approach;
- plaque, mechanism, tuning-plate, and crypt interactions;
- the bell-rope breathing room;
- the bell frame and rose window landmarks.

## Full quest route

1. Speak with Orin and accept the investigation.
2. Cross the modular weathered causeway and use the listening point.
3. Enter through the modular chapel arch.
4. Inspect the memorial plaque, severed rope, and submerged mechanism.
5. Recover the tuning plate from its presentation pedestal.
6. Open the crypt and descend to the Listener.
7. Complete the Calm, Free, or Fight route.
8. Recover the burial register and return to Orin.

## Architecture and composition checks

- The causeway should read as repeated weathered slabs over one continuous route, not a sequence of disconnected boxes.
- The chapel entrance should frame Grace cleanly without narrowing the proven doorway collision.
- Side and front walls should read as stacked masonry courses with trim and variation.
- Repeated walls should join without bright seams, doubled surfaces, or flickering overlap.
- The nave's remaining pillars and timber frames should reinforce the original sightlines without creating a structural picket fence.
- The center of the nave should contain a visible patch of breathing room.
- The memorial plaque, bell rope, pool mechanism, altar, tuning plate, crypt seal, and rose window should remain immediately recognizable.
- The flooded side chapel should feel architecturally connected through wet stone, overflow-channel language, steps, rim, and retaining walls.
- Four warm sconces should create localized pools of light without washing out the cool moonlit chapel.
- The two remaining storage props should add scale and history while sitting outside required approaches.
- The crypt passage should communicate resonance without filling the camera with overlapping rings.

## Grace silhouette checks

- Grace's robe should remain clearly robe-shaped, but the hem should no longer dominate narrow passages.
- Her torso, arms, cuffs, hands, sash, and boots should read slightly slimmer without becoming spindly.
- Her face, hair, palette, age, outfit identity, animation hierarchy, and equipment presentation should remain unchanged.
- The physical capsule should match `grace_spatial_profile.tres` and remain believable relative to the visual model.
- Camera retraction in the crypt should leave more environment visible around Grace.

## Traversal and camera checks

- Walk the causeway and chapel threshold without jumping.
- Circle every remaining modular pillar and timber post with the camera close behind Grace.
- Walk between both nave aisles, the bell frame, altar, and pool without snagging.
- Approach the plaque, rope, mechanism, tuning plate, and crypt from several angles.
- Enter and leave the flooded side chapel through both established exits.
- Descend into and return from the crypt normally.
- Swim the rebuilt burial passage along its center and both edges.
- Blink toward modular walls, arches, floor edges, the pool rim, and the crypt threshold.
- Deliberately press against module joins and verify the continuous support shell prevents seam falls.
- Confirm global recovery remains a last resort rather than normal navigation.

## Optional readability debug view

Set `show_debug_zones = true` on `SpatialReadabilityPass` to display travel lanes, camera envelopes, interaction zones, and landmark zones. Return it to `false` for normal play.

## Collision ownership checks

- Visible floor, wall, arch, pillar, timber, stair, and water-transition modules should report `uses_support_shell = true`.
- Their internal collision objects should be inactive inside the chapel benchmark.
- The hidden authored support floor and walls should remain physical.
- The two retained freestanding props should keep physical collision.
- Retired props and structure should have no active collision.
- No duplicate collision should cause Grace to vibrate, stop at invisible lips, or become trapped against the walls.

## Quest and persistence regression

- All three resonance clues remain usable.
- The tuning plate remains recoverable and consumable at the crypt seal.
- The Listener begins passive and supports Calm, Free, and Fight resolutions.
- The burial register and Orin's token remain persistent rewards.
- Reloading after completion preserves the quiet chapel, opened crypt, resolved route, and absent Listener.

## Acceptance

The remaster succeeds when the chapel feels materially closer to a reusable game environment than a debug set, while the full quest remains as reliable as before. It should feel detailed but not upholstered wall-to-wall. Any repeated collision snag, blocked prompt, hidden clue, unreadable threshold, crowded camera lane, or modular seam is a benchmark defect and should be corrected in the kit, spatial profile, layout plan, or readability pass rather than patched with another quest-specific safety rule.

Automated coverage:

```text
scenes/tests/drowned_bell_environment_smoke_test.tscn
scenes/tests/drowned_bell_crypt_smoke_test.tscn
scenes/tests/global_playability_framework_smoke_test.tscn
```
