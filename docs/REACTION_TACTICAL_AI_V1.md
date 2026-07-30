# Reaction-Aware Tactical AI v1

## Purpose

The tactical AI layer turns the spell capability manifest and elemental chemistry engine into readable action-selection guidance.

It does not replace enemy personality, spacing, cooldowns, telegraphs, threat reactions, or authored companion choreography. It contributes tactical bonuses, penalties, and vetoes to those systems.

## Decision pipeline

1. Capture an observable world snapshot.
2. Convert available actions or spells into normalized candidates.
3. Compare candidate payload identity with current target states and reaction rules.
4. Score immediate payoffs, setup opportunities, safety, redundancy, and resources.
5. Select deterministically by score, then action ID.
6. Preserve every candidate score and reason in a decision trace.

## Observable information

The v1 planner may inspect:

- actor and target health fraction
- active statuses and public tags
- authored action or spell capabilities
- action payload tags and applied states
- current nearby hazards
- an ally's currently selected spell tags
- reactions already claimed by an ally when supplied by coordination context

It may not inspect hidden future inputs, random outcomes, unrevealed player inventory, or future animation state.

The goal is tactical awareness, not omniscience.

## Core types

### TacticalWorldSnapshot

Captures actor state, target state, nearby reactive hazards, path danger, ally payoff tags, and claimed reactions.

Hazards are discovered through the existing `hazard_reactive` group and `get_hazard_tags()` contract.

### TacticalActionCandidate

Normalizes either an `EnemyActionOption` or a spell-manifest record into:

- action identity and kind
- role and incoming tags
- applied states
- broad capabilities
- movement mode
- affordability
- authored distance window

### TacticalOpportunityEvaluator

Adds or subtracts utility for:

- immediate elemental reaction payoffs
- setup for an allied follow-up
- duplicate status application
- low-health defense or retreat
- dangerous approach paths
- ranged actions across dangerous terrain
- friendly-fire risk
- finishing a weakened hostile target

### ReactionTacticalPlanner

Scores every candidate, applies deterministic tie-breaking, and returns a complete trace.

The trace includes valid state, base score, tactical delta, total score, reasons, penalties, and reaction opportunities.

## Runtime adapters

### EnemyTacticalActionBrain

Extends the existing action-selection brain and adds tactical deltas to its normal personality and distance score.

`EnemyThreatAwareActionBrain` now inherits through this layer, so existing threat-aware enemy scenes gain tactical scoring without replacing their threat response logic.

### ReactionAwareRuviaControlDriver

Extends Ruvia's authored companion driver.

Ruvia's existing halberd choreography remains the default. The reaction planner may override a planned attack only when:

- she is free to choose an action,
- the spell cooldown is ready,
- the target is within spell range,
- she is not dodging, recalling, repositioning, or completing a planned weave,
- and the tactical reaction score exceeds a high threshold.

Fire hazards are ignored for her route-danger scan because her manifestation has Fire authority.

## Initial behavioral contracts

The smoke test verifies:

1. Wet target plus Lightning option selects Conduct.
2. Frozen target plus Force option selects Shatter.
3. Burning ally plus Water support selects Quench.
4. Low-health actor prefers defense over ordinary aggression.
5. A severe poison route vetoes melee approach and prefers ranged pressure.
6. An ally preparing Lightning increases the value of applying Wet.
7. The tactical spell library reuses the canonical manifest cache.
8. Threat-aware enemies and Ruvia install their runtime adapters.

## Test command

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/reaction_tactical_ai_smoke_test.tscn
```

Expected:

```text
REACTION_TACTICAL_AI_SMOKE_TEST: PASS
```

## Future expansion

Later versions can add:

- shared ally reaction reservations
- estimated area target counts
- friendly-fire geometry
- resource and cooldown forecasting
- personality-specific tactical weights
- retreat destination sampling
- enemy knowledge limits and remembered observations
- multi-step plans with expiration and reassessment

The planner should remain a utility service. Animation execution, navigation, and authored combat grammar stay with their existing owners.
