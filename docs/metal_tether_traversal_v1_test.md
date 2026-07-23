# Metal Tether Traversal v1

Run:

`scenes/levels/prototypes/prototype_metal_tether_traversal_lab_v1.tscn`

## Contract

Metal Tether is an equippable Metal spell using the normal Focus and Cast controls. It introduces a generic anchor interface and temporarily owns player locomotion through the same controller gateway used by Flight.

While attached:

1. Gravity and player input update Grace's velocity.
2. Velocity is decomposed into radial and tangential components relative to the anchor.
3. The taut tether removes outward radial motion and supplies centripetal acceleration.
4. Reeling changes the constraint length instead of teleporting Grace.
5. Airflow remains an external acceleration on the swinging body.
6. Tension is transferred to the selected anchor or its parent rigid body.
7. Releasing Cast preserves the current velocity as launch momentum.

The rendered filament is the shared `FlexibleTether3D` using a conductive, nonburnable Metal material profile. The gameplay constraint remains player-controller-owned so CharacterBody collision and authored input stay stable.

## Controls

- Focus / equip: `ZL` or right mouse
- Cast / tether: hold `ZR` or `Q`
- Swing input: left stick or `WASD`
- Jump from the ground: Jump
- Reel in: D-pad Up, `R`, or mouse wheel up
- Reel out: D-pad Down, `F`, or mouse wheel down
- Release: release Cast
- Emergency release: Dodge
- Reset laboratory: `F8` in editor builds

## Manual route

1. Aim at the Launch Anchor. Confirm its gold acquisition marker appears only with Metal Tether equipped and a clear line of sight.
2. Hold Cast. Confirm the metal filament appears and the HUD reports anchor, length, distance, tension, radial speed, and tangential speed.
3. Jump while attached and use left-stick input perpendicular to the tether. Confirm Grace pumps into a pendulum rather than flying directly toward the anchor.
4. Release Cast near the forward portion of the arc. Confirm Grace retains her velocity and launches toward the next platform.
5. Repeat through the Mid and Goal anchors, then land on the Foundry Beacon deck.
6. Reel inward during a swing. Confirm the orbit tightens, speed and tension rise, and Grace does not teleport.
7. Reel outward. Confirm the arc lengthens and tension generally falls.
8. Attach to the moving crane anchor. Confirm the endpoint follows it continuously while swing motion remains stable.
9. Enter the cyan crosswind volume. Confirm airflow acceleration appears in the HUD and bends the route without replacing tether tension.
10. From the load-test deck, attach to the 6 kg box. Confirm tension transfers into the rigid body and pulls it toward Grace.
11. Swing hard or reel aggressively from the Breakaway Anchor. Confirm it visibly fails near 900 N and Metal Tether releases.
12. Press Dodge while attached. Confirm the tether releases without stealing the Dodge input.
13. Press F8. Confirm Grace, the moving load, all anchors, the goal, and the spell state reset.

## Automated scene

`scenes/tests/metal_tether_traversal_smoke_test.tscn`

It validates the Metal ability metadata, conductive filament profile, normal and breakaway anchor contracts, player-scene channel integration, flexible runtime visual, release-momentum preservation, reel controls, crosswind station, HUD, and laboratory scene.

## Deferred

- wrapping the filament around arbitrary level geometry
- multiple simultaneous tethers
- enemy binding and hostile grapple resistance
- electrifying the tether through production Lightning payloads
- tethering while Flight is active
- anchor-specific traversal animations
- camera assistance and accessibility auto-release
