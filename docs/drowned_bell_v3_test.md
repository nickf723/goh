# The Drowned Bell v3: The Bell Below

Scene:

```text
scenes/levels/prototypes/prototype_drowned_bell_v1.tscn
```

## Purpose

Complete the authored Drowned Bell quest through the crypt beneath the chapel. This milestone reuses the Authored Quest Framework, Global Playability Framework, Authored Environment Composition, Modular Environment and Prop Kit, Authored Set Composer, shared swimming, ordinary combat payloads, key items, persistence, and conversation systems. It does not introduce another generic quest or creature-interaction framework.

The chapel's production-facing modular benchmark has its own detailed environment contract:

```text
docs/drowned_chapel_benchmark_remaster_v1_test.md
```

The data-driven set-composition contract is documented at:

```text
docs/AUTHORED_SET_COMPOSER_V1.md
```

## Full route

1. Speak with Orin and accept the investigation.
2. Listen from the causeway.
3. Enter the chapel and inspect the memorial plaque, severed bell rope, and submerged burial mechanism.
4. Recover the Corroded Tuning Plate.
5. Set the plate into the crypt seal behind the altar.
6. Descend the burial stair.
7. Swim through the composed collapsed burial passage and exit into the lower chamber.
8. Use the listening circle before approaching the creature.
9. Resolve the false call by one of three routes:
   - **Calm:** play the true two-note sequence at the western pedestal.
   - **Free:** shatter the corrupted resonator at the eastern pedestal.
   - **Fight:** attack and defeat the Listener. Its telegraphed throat pulse damages and pushes Grace.
10. Recover the Drowned Chapel Burial Register.
11. Return to Orin and complete the quest.

## Expected authored sequence

- The modular causeway, chapel shell, nave structure, wet-stone transitions, lighting, and props remain visually coherent over the continuous authored support shell.
- The crypt seal consumes the carried tuning plate and opens a real passage.
- The burial stair leads continuously below the chapel without a collision gap.
- The submerged passage uses the shared swimming controller and has exits at both ends.
- The tunnel, chamber opening, water volume, exit stair, modular trim, and drained return walkway are generated from `data/set_layouts/drowned_bell_crypt_passage_v1.json`.
- The Listener remains passive until Grace observes it and only becomes hostile after being attacked.
- The two physical mechanisms remain usable after combat begins, allowing Grace to de-escalate.
- Resolving the call drains the lower passage, opens the creature's escape route, and rings the chapel bell once in its correct tone.
- The burial register becomes available only after the call is resolved.
- Orin's return dialogue reflects the calm, freed, or fought route.
- Completion grants Orin's Marsh-Passage Token and 75 experience.
- Reloading preserves the opened crypt, chosen resolution, recovered register, quiet chapel, and completed quest state.

## Composed passage and clearance pass

- Enter the water from the upper landing without Blink, crouching, or scraping against an invisible wall.
- Swim down the center, then along both side walls.
- Rotate the camera through a full circle at the middle of the tunnel.
- Pass through the Listener-chamber opening while surfaced, submerged, and slightly off-center.
- Confirm the visible arch and the physical wall opening agree about the doorway location.
- Walk continuously up the chamber exit without jumping.
- After resolving the call, walk the widened drained passage in both directions.
- Verify both cyan water-exit anchors remain reachable from awkward approach angles.
- Confirm no old passage collision remains hidden inside the composed route.

The reusable clearance contract is:

```text
Swimming corridor: at least 5.5m wide × 5.0m high
Passage opening:   at least 5.5m wide with matching centerline
Stairs:            continuous ramp collision beneath visible steps
```

## Traversal and safety pass

- Walk the weathered causeway and chapel threshold without jumping.
- Circle the modular nave pillars, timber frames, freestanding props, bell frame, and pool rim with the camera close behind Grace.
- Walk from the altar through the crypt threshold without jumping.
- Descend and climb the burial stair with the camera close behind Grace.
- Enter the submerged passage from both ends.
- Surface near both exit markers and press Jump to verify assisted exits.
- Complete the drained return route without swimming.
- Press against the stair walls, chamber pillars, memorial niches, and escape arch.
- Deliberately fall below the crypt and confirm recovery returns Grace to the latest lower-chamber anchor.
- Blink toward modular joins, the pool rim, stair walls, tunnel ceiling, chamber perimeter, and opened escape passage.

## Combat pass

- Lock on to the Listener after observing it.
- Strike once and confirm its behavior changes from passive to agitated.
- Watch for the swelling throat and crypt-wide resonance telegraph.
- Stand inside the pulse once to confirm damage and knockback.
- Dodge or move beyond the pulse radius on the next attack.
- During combat, use either physical mechanism and confirm the encounter resolves without requiring the kill.
- On the fight route, confirm the defeated Listener does not leave a stale lock-on target.

## Readability pass

From the chapel entrance, identify without developer instructions:

- the memorial aisle on the left;
- the bell frame and severed rope in the nave;
- the flooded side chapel on the right;
- the raised altar and crypt threshold at the rear.

From the lower chamber entrance, identify:

- the Listener in the central pool;
- the cool two-note pedestal on the left;
- the violet corrupted resonator on the right;
- the sealed escape arch behind the creature;
- the burial-register lectern revealed after resolution.

## Automated coverage

```text
scenes/tests/drowned_bell_crypt_smoke_test.tscn
scenes/tests/drowned_bell_environment_smoke_test.tscn
scenes/tests/global_playability_framework_smoke_test.tscn
scenes/tests/drowned_bell_foundation_smoke_test.tscn
```

Automated checks prove the quest state, modular benchmark ownership, composed-set clearance metadata, route alternatives, actor contract, swimming exits, rewards, aftermath, and regressions. Manual playtesting remains authoritative for path clarity, camera comfort, environment quality, combat feel, and whether the Listener reads as frightened rather than villainous.
