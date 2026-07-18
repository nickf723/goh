# Enemy Threat Awareness v1 Test

## Goal

Verify that Grace's sword attacks advertise honest combat threats and that enemies can perceive, evaluate, and answer those threats through the existing committed-action architecture.

The first reactive behavior is intentionally narrow:

- Grace's heavy sword attacks broadcast a threat during startup.
- The Gremlin sensor waits through a reaction delay.
- The sensor confirms the Gremlin is still inside the predicted swing geometry.
- Backstep competes as a compatible response.
- Fast light cuts remain too quick for Backstep v1 once reaction latency is paid.

## Architecture

### CombatThreat

A transient snapshot describing:

- source and display name
- locked attack direction
- startup time until impact
- active duration
- range, cone, forward offset, and close-range radius
- severity
- normalized tags such as `weapon`, `melee`, `heavy`, and `sword`

### WeaponThreatBroadcaster

A child of Grace's `WeaponController` that listens to `attack_started`, builds a threat from the real weapon attack definition, and broadcasts it to the `combat_threat_sensors` group.

### EnemyThreatSensor

A reusable enemy component that:

- receives nearby threats
- waits through reaction latency
- removes expired or cancelled threats
- checks current predicted geometry
- exposes the most urgent actionable threat

### EnemyThreatAwareActionBrain

Extends the ordinary action selector. Before choosing routine offense or spacing behavior, it asks the sensor for an actionable threat and scores compatible response options.

### EnemyActionOption threat metadata

Actions may declare:

- whether they answer threats
- required and optional threat tags
- minimum and maximum time-to-impact windows
- response score bonus
- a threat-specific decision commit time

## Current Backstep response

- Required tags: `weapon`, `melee`, `heavy`
- Time-to-impact window: `0.14s - 0.45s`
- Threat decision time: immediate after sensor reaction delay
- Invulnerability: none
- Result: physical distance only

## Manual playtest

1. Pull `agent/enemy-threat-awareness-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene and approach the Gremlin with the practice sword equipped.
4. Enable developer/debug data if useful.

### Heavy sword reaction

1. Stand within roughly one meter of the Gremlin.
2. Press the heavy-attack input for `Guardbreaker`.
3. Confirm the Gremlin does not react on the exact input frame.
4. After a brief perceptual delay, confirm it selects `Backstep`.
5. Confirm the blue defensive tell appears.
6. Confirm it moves backward before the sword reaches its active frame when spacing permits.
7. Confirm the Backstep deals no damage and has no invulnerability.

### Light sword pressure

1. Reset to close range.
2. Use `Opening Cut` with the light-attack input.
3. Confirm the Gremlin does not consistently Backstep from the light cut.
4. Confirm fast pressure can still catch it before a safe defensive response window opens.

### Geometry honesty

1. Begin a heavy attack while facing away from the Gremlin.
2. Confirm it does not Backstep from a swing that does not predictively include it.
3. Face the Gremlin and repeat.
4. Confirm the same heavy startup now creates a response.

### Range honesty

1. Start Guardbreaker outside its practical threat area.
2. Confirm the Gremlin does not react merely because a heavy input occurred somewhere nearby.
3. Move into close range and repeat.
4. Confirm the threat becomes actionable.

### Existing combat rhythm

1. Let the Gremlin Pounce, Bite, and use its ordinary cooldown-driven Backstep.
2. Confirm threat awareness does not remove its existing non-reactive action choices.
3. Confirm Bite, Pounce, and Backstep retain independent cooldowns.

## Debug fields

The threat-aware brain adds:

- `threat`
- `threat_response`
- `threat_time`

The sensor exposes:

- `threats`
- `threat_received`
- `threat_actionable`
- `reaction_delay`

## Known limitations

- Threat direction is snapshotted when the attack begins.
- Weapon attack cancellation is inferred from the controller state rather than a dedicated cancellation signal.
- Backstep only responds to heavy melee weapon threats in v1.
- Backstep has no invulnerability frames.
- Threat occlusion and line of sight are not checked yet.
- Enemies do not coordinate or reserve escape space.

## Creative review

Judge whether the reaction feels like perception rather than input reading. The Gremlin should appear to notice the large sword commitment, think for a fraction of a second, and escape when it has enough warning. Fast cuts should still feel capable of overwhelming it.
