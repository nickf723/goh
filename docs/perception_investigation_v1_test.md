# World-Aware Perception and Investigation v1 Playtest

## Scene

`res://scenes/levels/prototypes/prototype_perception_investigation_lab_v1.tscn`

## Purpose

Validate reusable enemy perception built from uncertain evidence rather than a permanent direct reference to Grace. Enemies can see through a field of view and line-of-sight query, hear temporary world-space stimuli, lose visual contact, pursue a remembered position, search, and return to their post. Smoke density reduces effective vision while sound remains independently useful.

The laboratory compares the same Gremlin family under Cautious, Bold, Skittish, and Brute perception tuning.

## Controls

- Move: left stick or WASD
- Camera: right stick or mouse
- Interact with noise beacon: mapped Interact input
- Light or heavy attack: break the wooden noise crates
- Focus spell menu: LT or mapped Focus input
- Cast selected ability: RT or Q
- Toggle perception geometry: V
- Toggle Smoke density voxels: B
- Reset laboratory: F8 in the editor

The laboratory equips the existing Gas Lab loadout, with **Gust** selected first and **Flight** available second.

## Debug language

Each observer draws:

- A vision-cone outline.
- A hearing reference circle.
- A line and cross marking its current last-known position.
- An overhead state label and suspicion value.

State colors:

- Green: Unaware
- Yellow: Suspicious
- Orange: Investigating
- Red: Alerted
- Violet: Searching
- Blue: Returning

The large readout reports awareness, suspicion, visibility strength, local Smoke density, and the brain's current action summary.

## Expected route

1. Launch the scene and remain near the entrance.
   - All four observers should begin Unaware.
   - Their vision cones and hearing circles should differ slightly by personality.
2. Walk directly into one observer's cone.
   - Suspicion should climb rather than snapping instantly to omniscient pursuit at long range.
   - Close visual contact should alert the observer rapidly.
3. Step behind that lane's sightline wall.
   - The observer should move toward Grace's last visible position.
   - It should not continuously update toward Grace through the wall.
   - After memory expires, it should Search, then Return to its post.
4. Interact with a lane's noise beacon while outside the observer's vision.
   - A temporary Distraction stimulus should be emitted at the beacon.
   - The observer should investigate the beacon's location.
   - It should not know which direction Grace left after the sound.
5. Break a wooden crate outside direct sight.
   - Cracking should emit a moderate Impact stimulus.
   - Breaking should emit a louder Break stimulus.
   - Nearby personalities should react according to hearing sensitivity and suspicion gain.
6. Walk or run near the lanes while hidden.
   - Grace's movement component should emit repeated Footstep stimuli while she moves on the floor.
   - Skittish should normally react from farther away than Brute.
7. Observe the central Smoke curtain.
   - Smoke density should reduce visual range and visibility strength through the plume.
   - Hearing should continue to function through Smoke.
8. Cast Gust through the Smoke curtain.
   - Gust should move the existing Gas density through the Airflow system.
   - Observer visibility should respond to the redistributed density rather than to a fixed concealment trigger.
9. Compare personalities.
   - Cautious should investigate more slowly and search carefully.
   - Bold should acquire suspicion quickly and close decisively.
   - Skittish should hear the widest area and remain searching longer.
   - Brute should miss softer evidence more often and abandon searches sooner.
10. Press V and B.
    - Hiding debug geometry or Smoke voxels must not disable perception, stimuli, or Gas simulation.
11. Press F8.
    - Stimuli, Smoke, crate state, enemy awareness, Grace's position, health, and mana should reset.

## Reusable architecture

### PerceptionStimulus

A short-lived world-space evidence record containing an id, position, loudness, category, duration, source, priority, and tags.

### PerceptionStimulusManager

Owns active stimuli and exposes spatial queries. Sound emitters do not need references to individual enemies.

### EnemyPerceptionSensor

Samples:

- Distance and field-of-view angle.
- Physics line of sight.
- Smoke density along five points between eye and target.
- Temporary sound stimuli with distance falloff and wall attenuation.

### EnemyPerceptionInvestigationBrain

Converts observations into:

`Unaware → Suspicious → Investigating / Alerted → Searching → Returning`

Alerted enemies retain only a last-known position after losing sight. Sound creates a location to investigate, not a live target lock.

### Emitters

- `PerceptionMovementEmitter` translates actor movement into Footstep stimuli.
- `PerceptionBreakableEmitter` translates Crack and Break signals into sound stimuli.
- `PerceptionNoiseBeacon` provides an authored distraction source through the ordinary interaction system.

## Current limitations

- Hearing uses direct distance with a single wall-attenuation ray rather than propagated acoustics or portal graphs.
- Vision uses one target ray and does not yet sample separate head, torso, and limb visibility.
- Smoke reduces sight according to sampled density but solid geometry does not yet redirect Gas flow.
- Enemies use direct steering rather than a navigation mesh, so the lane geometry is deliberately simple.
- Investigation does not yet notify allies, reserve search sectors, recognize footprints, distinguish friendly sounds, or reason about doors.
- Perception observers do not attack Grace in this laboratory; combat integration remains available through the inherited action brain and will be tested separately.
