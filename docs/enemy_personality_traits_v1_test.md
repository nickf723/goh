# Enemy Personality Traits v1 Test

## Goal

Verify that enemy zone behavior can be tuned through reusable personality profiles instead of one shared response for every enemy.

## Profiles added

- `balanced`: default behavior.
- `cautious`: notices zones earlier, avoids more strongly, commits to attacks more carefully.
- `bold`: accepts more risk and commits faster.
- `skittish`: avoids zones hardest and hesitates longer.
- `brute`: ignores softer control more often and commits through pressure.
- `opportunist`: avoids major danger while keeping attack pressure high.

## Scene setup

- `GoblinDrone` uses `personality_id = "cautious"`.
- `GremlinDrone` uses `personality_id = "skittish"`.

## Manual test

1. Pull branch `agent/enemy-personality-traits-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Confirm Goblins and Gremlins still chase and attack when no zones are active.
5. Place `Poison Bloom` between Grace and a Goblin.
6. Confirm the Goblin steers around the danger zone without freezing in place.
7. Place `Poison Bloom` between Grace and a Gremlin.
8. Confirm the Gremlin shows stronger avoidance than the Goblin when there is room.
9. Place `Time Snare` on a chase path.
10. Confirm enemies can hesitate or slow, with the Gremlin feeling more reluctant than the Goblin.
11. Place `Dream Trap` near the chase path.
12. Confirm enemies try to steer around, but can still trigger it if boxed in or if the trap is placed directly under/near them.
13. Enable developer/debug data and confirm enemies expose `personality`, `zone`, and `zone_wait` fields.
14. Confirm Firebolt, Ice Lance, Lightning Spark, and ground spells still behave normally.

## Inspector tuning check

Temporarily change an enemy brain `personality_id` in the inspector:

```txt
balanced
cautious
bold
skittish
brute
opportunist
```

Run the same zone test and confirm the behavior changes without changing the enemy scene structure.

## Known limitations

- This tunes local steering and attack commitment only.
- It does not yet choose different attacks, retreats, flanks, or team behavior.
- Personality entries are currently a hardcoded dictionary. They can become Resources later if we want designer-facing asset files.
- No navigation-mesh routing yet, so enemies can still be forced through hazards in tight corridors.
