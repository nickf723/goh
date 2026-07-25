# Enemy Animation and Combat Readability v1 — Manual Test

## Purpose

Verify that Goblins and Gremlins communicate movement, intent, impact, vulnerability, and defeat through body motion while the existing AI, attack runner, telegraph colors, collision, and damage timing remain authoritative.

## Recommended scenes

- `res://scenes/levels/prototypes/prototype_combat_survival_trial_v1.tscn`
- `res://scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn`
- `res://scenes/levels/prototypes/prototype_enemy_personality_lab_v1.tscn`

## Goblin route

1. Let a Goblin idle. Confirm its breathing and head movement are restrained and heavy.
2. Enter detection range. Confirm it leans into pursuit with broad, weighty strides and counter-swinging arms.
3. Wait for an attack. Confirm the red windup now has a raised cleaver and coiled torso.
4. Watch the gold active frame. Confirm the body, weapon arm, jaw, and cleaver snap through the strike.
5. Dodge or block and watch recovery. Confirm the Goblin visibly regains its balance before pursuing again.
6. Damage Health or Stance. Confirm the body recoils independently of the existing flash and combat feedback.
7. Break Stance. Confirm a larger off-balance silhouette persists into the critical opening.
8. Defeat it. Confirm it falls, becomes non-interactive, and remains visible briefly before cleanup.

## Gremlin route

1. Let a Gremlin idle. Confirm quicker head twitches, ear motion, jaw movement, and tail sway distinguish it from the Goblin.
2. Enter detection range. Confirm the Gremlin crouches forward and uses faster, longer limb arcs.
3. Observe circling, retreating, and backstepping. Confirm the legs and arms respond to actual velocity while the head tracks Grace.
4. Trigger Bite or Pounce. Confirm the windup compresses the creature and the active pose throws its head, jaws, claws, and body forward.
5. Hit or break its Stance. Confirm the lighter creature reacts more sharply than the Goblin.
6. Defeat it. Confirm it falls to the opposite side from the Goblin and cleans up after the presentation delay.

## Shared contract

- Red remains windup, gold remains active, and normal color remains recovery.
- Presentation never changes attack range, contact time, damage, AI decisions, navigation, or authoritative movement.
- Head, hand, chest, and feet marker paths remain stable and now follow the animated pivots.
- Defeated enemies immediately leave the enemy group, disable collision and behavior, then remain visible for approximately `0.55` seconds so the fall can read.

## Automation

Run:

`res://scenes/tests/enemy_animation_presentation_smoke_test.tscn`

The smoke test instantiates both visual profiles and verifies their articulated hierarchy and windup, active, hit, stagger, and defeat state contracts.

## Known limits

- These remain transform-driven procedural models rather than final skinned meshes.
- Foot planting, inverse kinematics, facial morphs, authored clips, and animation blending trees are deferred.
- Gremlin tail and ears rotate as rigid presentation pieces.
- The short death delay is visual cleanup, not ragdoll simulation.
