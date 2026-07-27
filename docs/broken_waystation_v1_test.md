# Broken Waystation / Relay Response Manual Test

Run:

```text
res://scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn
```

## Opening encounter

1. Speak with Tamsin beside the damaged relay.
2. Confirm the conversation uses the standard dialogue interface and presents Metal, Earth, and Lightning repair choices through actual affinity requirements.
3. Complete one repair method and confirm the damaged arm, foundation, or conduits visibly transform.
4. Confirm the beacon core lights, the relay arm settles, and Tamsin receives post-repair dialogue.

## Relay Response

1. Speak with Tamsin again and accept the eastern relay investigation.
2. Confirm six signal stakes illuminate along the authored trail.
3. Cross the stone bridge and inspect the optional Space overlook route.
4. At the eastern relay, confirm the lookout and mechanist are staged separately.
5. Defeat the first wave and confirm the captain enters from the maintenance ledge.
6. Test the corrupted conduit interaction with Metal or Lightning affinity.
7. Recover the cracked signal prism only after the site is secured.
8. Return to Tamsin and confirm her dialogue reflects the repair method, conduit result, and overlook discovery.

## Quest and persistence

1. Open the Journey journal and confirm The Relay Response advances through trail, encounter, prism, and return stages.
2. Confirm the cracked prism appears as quest evidence and Tamsin's chart appears as a key-item reward.
3. Confirm the completion summary lists Grace's actual choices and rewards.
4. Reload the scene after completion.
5. Confirm the eastern gate remains open, the repair camp is packed, the supply cache is visible, the remote relay is stable blue, and Tamsin uses post-quest dialogue.

## Combat regression

- Lock onto an enemy, defeat it, and immediately continue attacking another enemy.
- Confirm no freed-target error occurs and lock-on clears or advances safely.

## Quality reference

This quest should meet the authored-content bar established by Mara and Tamsin: character context, readable staging, proper prompts, physical feedback, persistent consequences, and no debug-only choice flow.

## Known limitations

- Environment and character visuals remain procedural prototypes.
- Goblin and Gremlin actors stand in for future location-specific enemies.
- The eastern continuation ends at the opened route rather than a connected production region.
