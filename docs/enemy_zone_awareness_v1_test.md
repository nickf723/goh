# Enemy Zone Awareness v1 Test

Branch: `agent/enemy-zone-awareness-v1`

## Goal

Give Goblin and Gremlin enemies a first-pass awareness layer for active ground spell zones.

This does not add full pathfinding yet. It gives enemies simple local steering and hesitation so ground spells start influencing enemy decisions.

## Setup

1. Pull this branch.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Use the existing spell focus menu and controller casting flow.

## Smoke test

1. Confirm Goblins / Gremlins still spawn and chase Grace normally when no ground zones exist.
2. Confirm they still attack if Grace stands in range.
3. Confirm Firebolt, Charged Firebolt, Ice Lance, Piercing Ice Lance, Lightning Spark, and Chain Lightning still behave normally.

## Poison Bloom awareness

1. Place Poison Bloom between Grace and an enemy.
2. Let the enemy chase.
3. Confirm the enemy attempts to steer around the poison cloud rather than walking directly through it when there is room.
4. Confirm the enemy can still be poisoned if trapped in the cloud or if the route is too tight.
5. Check developer/debug data for a zone entry like `Poison Bloom / danger / ...m`.

## Time Snare awareness

1. Place Time Snare in the enemy's chase path.
2. Let the enemy enter or approach the field.
3. Confirm the enemy briefly hesitates in or near the slow field.
4. Confirm the normal `chill` slow carrier still applies while inside the field.
5. Check developer/debug data for a zone entry like `Time Snare / slow / ...m`.

## Dream Trap awareness

1. Place Dream Trap just off the enemy's chase path.
2. Confirm the enemy tries to steer around it when possible.
3. Place Dream Trap directly in a narrow path or very close to the enemy.
4. Confirm the enemy can still accidentally trigger it.
5. Confirm Dream Trap still applies `staggered` and cleans itself up after the burst.
5. Check developer/debug data for a zone entry like `Dream Trap / trap / ...m`.

## Regression checks

1. Confirm Earth Spike still uses ground targeting and instant AoE.
2. Confirm Poison Bloom still reacts to Firebolt with toxic ignition.
3. Confirm Poison Bloom still reacts to Wind Gust with spread if available in the scene.
4. Confirm Time Snare still places its gold field and expires.
5. Confirm Dream Trap still places, arms, triggers, and expires.
6. Confirm enemy overhead/debug data still includes state, distance, cooldown, and last action.

## Known limitations

- This is local steering, not navigation-mesh pathfinding.
- Enemies can still walk into fields if the route is narrow, if they are already committed, or if the avoidance vector loses against chase pressure.
- Zone behavior is currently wired into Goblin and Gremlin scenes through `EnemyZoneAwareBrain`.
- Future enemies can opt into the same subclass or the awareness can be folded into the base `EnemyBrain` once the behavior feels right.
