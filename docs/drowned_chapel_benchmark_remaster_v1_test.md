# Drowned Chapel Benchmark Remaster v1

Scene:

```text
scenes/levels/prototypes/prototype_drowned_bell_v1.tscn
```

## Purpose

Prove that the Weathered Cloister modular environment kit can carry a complete authored quest space rather than only a dedicated showroom. The remaster changes the chapel's repeated architecture and prop presentation while preserving the finished Drowned Bell quest, Global Playability contracts, swimming routes, interactions, Listener encounter, persistence, and three resolution paths.

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
- The nave's modular pillars and timber frames should reinforce the original sightlines rather than crowding the route.
- The memorial plaque, bell rope, pool mechanism, altar, tuning plate, crypt seal, and rose window should remain immediately recognizable.
- The flooded side chapel should feel architecturally connected through wet stone, overflow-channel language, steps, rim, and retaining walls.
- Warm modular sconces should create localized pools of light without washing out the cool moonlit chapel.
- Crates and barrels should add scale and history without becoming navigation traps.

## Traversal and camera checks

- Walk the causeway and chapel threshold without jumping.
- Circle every modular pillar and timber post with the camera close behind Grace.
- Walk between both nave aisles, the bell frame, altar, and pool without snagging.
- Enter and leave the flooded side chapel through both established exits.
- Approach every required interactable from several angles.
- Descend into and return from the crypt normally.
- Blink toward modular walls, arches, floor edges, the pool rim, and the crypt threshold.
- Deliberately press against module joins and verify the continuous support shell prevents seam falls.
- Confirm global recovery remains a last resort rather than normal navigation.

## Collision ownership checks

- Visible floor, wall, arch, pillar, timber, stair, and water-transition modules should report `uses_support_shell = true`.
- Their internal collision objects should be inactive inside the chapel benchmark.
- The hidden authored support floor and walls should remain physical.
- Freestanding modular crates and barrels should retain physical collision.
- No duplicate collision should cause Grace to vibrate, stop at invisible lips, or become trapped against the walls.

## Quest and persistence regression

- All three resonance clues remain usable.
- The tuning plate remains recoverable and consumable at the crypt seal.
- The Listener begins passive and supports Calm, Free, and Fight resolutions.
- The burial register and Orin's token remain persistent rewards.
- Reloading after completion preserves the quiet chapel, opened crypt, resolved route, and absent Listener.

## Acceptance

The remaster succeeds when the chapel feels materially closer to a reusable game environment than a debug set, while the full quest remains as reliable as before. Any repeated collision snag, blocked prompt, hidden clue, unreadable threshold, or modular seam is a benchmark defect and should be corrected in the kit or remaster pass rather than patched with another quest-specific safety rule.

Automated coverage:

```text
scenes/tests/drowned_bell_environment_smoke_test.tscn
scenes/tests/drowned_bell_crypt_smoke_test.tscn
scenes/tests/global_playability_framework_smoke_test.tscn
```
