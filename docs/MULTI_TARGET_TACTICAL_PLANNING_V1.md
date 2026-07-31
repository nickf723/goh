# Multi-Target Tactical Planning v1

## Purpose

Multi-Target Tactical Planning gives a tactical actor a second decision layer:

```text
Which target should receive the next action?
```

The first rollout is intentionally limited to the Storm Drain Pack. Existing enemies continue using their historical single-target behavior until they are deliberately migrated.

## Runtime chain

```text
combat targets
-> TacticalTargetCandidate snapshots
-> TargetAllocationBlackboard claims
-> RoleAwareTargetEvaluator scoring
-> Storm Drain target assignment
-> normal tactical action selection
-> normal attack, projectile, and reaction execution
```

Target selection happens between committed actions. Windup, active, and recovery phases keep their locked target.

## Target candidates

`res://scripts/ai/tactical_target_candidate.gd`

A candidate captures serializable combat information:

- target id, name, kind, and position
- distance from the evaluating actor
- current and maximum health
- stance state when available
- active statuses
- action-blocked and defeated state
- player, manifestation, and friendly-actor identity

The runtime node reference is removed before telemetry or replay serialization.

## Target claims

`res://scripts/ai/target_allocation_blackboard.gd`

Claims are short-lived squad commitments:

- `attention`
- `damage`
- `melee`
- `setup`
- `payoff`
- `control`

Each claim may include expected committed damage and control tags such as `wet` or `stunned`.

Claims release when:

- their duration expires
- the action finishes, cancels, or is interrupted
- the owner leaves the scene
- the target is defeated or removed
- the encounter resets

## Role-aware target scoring

`res://scripts/ai/role_aware_target_evaluator.gd`

### General rules

- favor useful distance windows
- slightly favor weakened targets
- strongly penalize targets whose committed damage already covers their remaining health
- penalize crowded targets
- allow an authored focus-fire target to override safety penalties

### Primer

- prefers a target without Wet
- avoids a target with an existing Wet or setup claim

### Payoff Specialist

- strongly prefers a Wet target
- follows an allied Wet setup claim before the status lands
- avoids duplicating another payoff claim

### Protector

- continues pressuring the primary aggressor
- avoids joining a heavily crowded target
- Guard Screech remains governed by nearby allied stance need

### Disruptor

- prefers an active target without an existing control claim
- avoids targets already stunned, frozen, or otherwise action-blocked

### Skirmisher

- prefers open melee pressure
- avoids crowded engagement targets
- favors targets that support mobile harassment

## Storm Drain integration

`res://scripts/enemies/storm_drain_pack_brain.gd`

The pack evaluates Grace plus nodes in the `enemy_targetable` group. Ruvia manifestations join that group while remaining excluded from Grace's ordinary `combat_targetable` lock-on set.

The brain's historical `player` field is treated as the current combat target. Switching that field preserves all existing systems:

- movement and facing
- attack ranges and cones
- pounce direction
- projectile direction
- threat reactions
- action caching
- elemental reaction evaluation

Contact attacks against Grace keep using player defense and `GameState`. Contact attacks against Ruvia call her native `receive_damage_payload()` method and use manifestation health.

## Telemetry

The tactical overlay now shows:

- selected target and target score
- target-selection reason
- rejected target candidates
- action-selection reason
- current squad target claims
- committed damage per target

The Storm Drain status panel also displays each surviving member's current target.

## Automated test

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/multi_target_allocation_smoke_test.tscn
```

Expected:

```text
MULTI_TARGET_ALLOCATION_SMOKE_TEST: PASS
```

The test covers:

- overkill prevention
- duplicate setup and control prevention
- Primer and Payoff target pairing
- Skirmisher target spreading
- authored focus-fire override
- live Grace and Ruvia target allocation
- enemy damage routing into Ruvia health

## Known limitations

- Target visibility and navigation reachability are approximated by distance in v1.
- Protector ally-selection is still separate from hostile target selection.
- Claims estimate damage from authored payload values rather than predicting full combo damage.
- Projectile flight can outlive its claim after the firing action completes.
- Only the Storm Drain Pack uses live target allocation in this rollout.
