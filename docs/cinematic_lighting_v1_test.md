# Cinematic Lighting v1

## Showcase

Run:

`scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn`

The Ruined Village Approach now uses a reusable cinematic lighting rig with:

- a gold late-afternoon key light and cool sky fill
- procedural dusk sky color
- distance and height fog
- Forward+ volumetric fog with directional scattering
- six art-directed light shafts
- three drifting dust-mote volumes
- glow around emissive story landmarks
- ambient occlusion for stronger contact and ruin depth
- warm church and memory accents
- a cool ravine fill

## Visual route

1. Begin in the arrival crater and look toward the stairway. Broad rays should layer across the cool cliff shadow.
2. Walk through the outer ruins. The sky should transition from warm horizon to deep blue overhead.
3. Enter the village square. Dust should drift through two overlapping sun shafts.
4. Look down into the ravine. The cool fill should separate it from the warm square.
5. Climb toward the church. Its doorway and rose window should bloom subtly through the haze.
6. Orbit the camera around the church approach. Shafts should read as atmosphere, not opaque geometry.

## Quality API

The rig exposes:

`set_quality(0)` — Low: stylized shafts and light dust remain; volumetric fog and SSAO are disabled.

`set_quality(1)` — Balanced: shorter volumetric range, moderate dust, and reduced post effects.

`set_quality(2)` — Cinematic: full volumetric range, dust, glow, and SSAO.

The scene defaults to Cinematic for visual evaluation.

## Smoke test

Run:

`scenes/tests/cinematic_lighting_smoke_test.tscn`

It verifies environment reuse, volumetric fog, glow, SSAO, shadowed sun, shaft and dust construction, and quality switching.

## Performance checks

Compare the same view on all three quality levels. Low should preserve the composition while removing the expensive volumetric and ambient-occlusion passes. The local accent lights do not cast shadows, and particle counts remain deliberately modest.
