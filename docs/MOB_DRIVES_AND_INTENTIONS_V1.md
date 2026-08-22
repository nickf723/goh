# Mob Drives and Intentions v1

## Purpose

The Mob Engine foundation can answer which move is best in one isolated decision context. This layer gives an animal memory across those decisions.

Two reusable systems now sit between perception and move selection:

1. **Drives** preserve internal pressures such as hunger and fear.
2. **Intentions** keep a creature pursuing a behavioral goal while nearby scores fluctuate.

Together they prevent animals from feeling like a roulette wheel that forgets its previous thought every decision tick.

## Persistent drives

`MobDriveState` stores six normalized values from zero to one:

- Hunger
- Fatigue
- Fear
- Social need
- Curiosity
- Territorial pressure

A drive state belongs to one individual creature. It is seeded from the creature's resolved personality, then changes over time and in response to context.

Examples:

- Low courage raises fear faster and lets it decay more slowly.
- High sociability causes isolation to build social need.
- Safe time slowly restores curiosity.
- Intruders raise territorial pressure according to territoriality.
- Hunger and fatigue increase continuously until compatible behavior satisfies them.

External systems may directly set or add drive values through `MobBrainComponent` for scripted events, status effects, feeding, resting, bonding, weather, familiar commands, or ecology simulation.

## Context observation

A drive state observes immediate context without replacing perception.

Perception may still supply tags such as:

- `attacked`
- `cornered`
- `predator_near`
- `hungry`
- `exhausted`
- `intruder`
- `territory_breached`

Observation converts those events into persistent internal pressure. A sheep can therefore remain frightened briefly after a predator leaves sight instead of becoming perfectly calm in one frame.

## Drive-generated context

Before evaluation, the brain asks its drive state to enrich the current `MobDecisionContext`.

The drive layer may add state tags including:

- `hungry`
- `starving`
- `tired`
- `exhausted`
- `frightened`
- `panicked`
- `lonely`
- `curious`
- `defending_territory`

It also exposes every drive through `scalar_values` and contributes to generic utility modifiers.

## Generic score modifiers

`MobDecisionContext` now supports three optional modifier dictionaries:

### Exact move modifiers

`move_score_modifiers` adjusts one move ID.

Example:

```gdscript
{"graze": 0.5}
```

### Move-tag modifiers

`tag_score_modifiers` adjusts every move carrying a semantic tag.

Example:

```gdscript
{"forage": 0.8, "attack": -0.2}
```

### Policy-tag modifiers

`policy_tag_score_modifiers` adjusts species-specific roles without changing the shared move definition.

Example:

```gdscript
{"pack_support": 0.6, "desperation_attack": 0.2}
```

This bridge is deliberately generic. Drives use it now, but weather, orders, morale, elemental conditions, social roles, injuries, quests, and boss phases can reuse the same channel later.

## Current drive biases

The first pass uses semantic move tags rather than species-specific move IDs.

- Hunger promotes `forage` and `recovery`.
- Fatigue promotes `calm` and `recovery` while discouraging strenuous attack and movement.
- Fear promotes `retreat`, `survival`, and `defense` while suppressing ordinary aggression.
- Social need promotes `social`, `support`, and `pack` actions.
- Curiosity promotes `habitat`, `ambient`, and light movement behavior.
- Territorial pressure promotes `attack`, `defense`, and `control` while discouraging retreat.

Because these are additive utility pressures, personality and species policy still matter. Hunger does not make a sheep use a move it anatomically lacks, and fear does not unlock an attack forbidden by its species policy.

## Satisfying drives

When the actor commits a move, the brain feeds the resolved move data back into its drive state.

Examples:

- Foraging reduces hunger.
- Calm and recovery actions reduce fatigue.
- Retreat slightly reduces fear.
- Pack and support behavior reduce social need.
- Habitat exploration reduces curiosity pressure.
- Defensive or offensive territorial action slightly releases territorial pressure.

This remains a lightweight feedback loop: drive satisfaction is applied when a move commits. The shared move lifecycle now distinguishes startup, active, recovery, successful completion, and interruption, so future ecology tuning can defer particular drive rewards until a successful outcome without changing the evaluator.

## Behavioral intentions

`MobIntentionResolver` maps selected moves into reusable goals:

- Forage
- Survive
- Socialize
- Seek habitat
- Recover
- Defend
- Engage
- Observe

The mapping uses move tags and policy tags. A sheep Headbutt marked as `conditional_defense` becomes a Defend intention even though the shared move is still an attack.

## Commitment and switching

`MobBrainComponent` keeps the current intention for a configurable duration.

While commitment is active, the best eligible move sharing that intention may remain selected when its score is within a configurable tolerance of the overall best move.

This creates useful hysteresis:

- A grazing animal does not instantly switch to wading because the two scores traded places by a tiny amount.
- A fleeing animal does not oscillate between escape and aggression as distance changes around a threshold.
- A pack creature can finish a social response before resuming ordinary pressure.

A clearly superior action still breaks commitment. Intentions are guidance, not a hard lock.

## Brain configuration

New `MobBrainComponent` options include:

- `use_drive_state`
- `drive_overrides`
- `drive_tick_interval`
- `intention_commitment_seconds`
- `intention_score_tolerance`

The brain also exposes:

- `set_drive()`
- `add_drive()`
- `get_drive()`
- `get_drive_snapshot()`
- `reset_drives()`

Selected decisions and debug data now include drive and intention metadata.

## Automated validation

Scene:

`res://scenes/tests/mob_drives_and_intentions_smoke_test.tscn`

Expected output:

`MOB_DRIVES_AND_INTENTIONS_SMOKE_TEST: PASS`

The regression verifies:

- Exact-move, move-tag, and policy-tag score modifiers
- Score-modifier serialization
- Hunger shifting a hot capybara from Wade to Graze
- Fear shifting a bold cornered sheep from Headbutt to Flee
- Social need shifting a close-range wolf from Bite to Pack Howl
- Intention retention for small score changes
- Intention switching for clearly superior actions
- Brain-level drive injection
- Drive satisfaction after move commitment
- Drive and intention debug data

## Next runtime layer

The strongest next step is a generic animal actor and executor that can visibly perform a small shared vocabulary:

- Idle or look around
- Move toward a point or habitat tag
- Graze or interact with forage
- Flee from a threat
- Follow or regroup with allies
- Execute contact attacks

That actor would turn the current decision machinery into a live sheep, capybara, or wolf sandbox without sacrificing the reusable policy architecture.
