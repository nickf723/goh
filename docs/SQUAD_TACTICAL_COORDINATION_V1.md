# Squad Tactical Coordination v1

## Purpose

The squad coordination layer allows tactical actors to announce short-lived intentions without sharing hidden information or replacing their local decision logic.

The system coordinates four reservation kinds:

- `setup`
- `payoff`
- `lane`
- `emergency`

Reservations are scoped by squad and target. They expire automatically and are released when an action completes, is interrupted, is cancelled, or its owner leaves the scene.

## Core ordering

```text
Observe visible state
-> read squad reservations and broadcasts
-> score local action candidates
-> reserve selected phase or lane
-> execute through the existing actor controller
-> release or expire the reservation
```

The blackboard never executes combat actions. It changes utility scores and guards exclusive slots only.

## Reaction plans

A reaction plan contains two compatible phases:

```text
setup:  apply the required target state
payoff: deliver the incoming effect that triggers the reaction
```

Setup and payoff use different exclusive slots. One actor may reserve each phase, allowing a complete plan while preventing duplicate setup or duplicate payoff.

Example:

```text
Goblin A reserves setup wet_conduction
Goblin B reserves payoff wet_conduction
Goblin C sees both claims and selects another action
```

## Engagement lanes

The first implementation exposes a target-specific `melee` lane. A second squad member evaluating another direct approach sees the occupied lane and prefers ranged pressure, defense, or a different target.

This is intentionally simple. Future lanes may distinguish front, flank, rear, aerial, or support positions.

## Emergency override

Critical defense is allowed to override the owner's own setup, payoff, and lane reservations. It does not steal another actor's reservation.

This prevents a low-health actor from dying merely because it previously promised to complete a combo.

## Intent broadcasts

Intent broadcasts are non-exclusive and short lived. They contain public tags rather than future predictions.

Ruvia currently broadcasts Grace's selected spell tags to the `grace_party` squad. A future Water-capable companion can therefore value Wet setup while Grace has Lightning selected.

## Fairness boundary

Actors may coordinate from:

- visible statuses
- public hazard tags
- currently selected or announced actions
- shared squad reservations
- explicit companion intent

They do not receive:

- hidden player cooldowns
- unseen inventory
- future inputs
- private AI state from other squads
- guaranteed knowledge that an announced action will succeed

## Runtime integrations

### Enemies

`EnemyThreatAwareActionBrain` now inherits through `EnemySquadTacticalActionBrain`.

The squad layer preserves:

- personality scoring
- distance fitting
- cooldowns
- threat responses
- action execution
- telegraphs

It adds coordination context before scoring and reserves the selected reaction phase or melee lane afterward.

### Ruvia

`ReactionAwareRuviaControlDriver` retains the authored halberd plan as its default. A reaction spell override must still exceed the existing tactical threshold and must successfully reserve its payoff.

Grace's selected spell is broadcast as intent, not as an exclusive claim.

## Debug data

Enemy tactical debug data now includes:

- squad ID
- selected reservation results
- active squad plans
- occupied lanes
- claimed setup and payoff reactions

Ruvia's debug data includes the same squad identity and her latest coordination result.

## Regression

Run:

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/squad_tactical_coordination_smoke_test.tscn
```

Expected:

```text
SQUAD_TACTICAL_COORDINATION_SMOKE_TEST: PASS
```

The regression verifies:

1. duplicate payoff claims are rejected
2. setup and payoff form one complete plan
3. interruption releases claims
4. expired claims disappear
5. squads remain isolated
6. emergency defense overrides a plan
7. occupied melee lanes change action selection
8. Grace's announced Lightning intent raises Water setup value
9. enemy and companion runtime adapters remain installed
