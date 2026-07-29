# Ruvia Companion Tactics v1

## Why this pass exists

The first manifestation driver could identify enemies and select valid actions, but it had no combat cadence. Its decision cooldown began when an attack started and expired while the attack animation was still running. The instant the form ended, the driver requested another attack. At ideal range the result looked like a stationary loop of halberd impacts rather than a warrior reading the encounter.

This pass adds tactical memory and movement between commitments without replacing Ruvia's authored weapon, spell, movement, or Fire Authority systems.

## Combat rhythm

Autonomous Ruvia now follows this loop:

```text
observe spacing
    -> choose a short attack or spell plan
    -> commit to the current form
    -> reassess while moving
    -> reposition after repeated attacks
    -> establish or exploit Fire terrain
    -> change targets after sustained pressure
```

A successful attack no longer leads directly into another request. Ruvia receives a short post-action reassessment window. After two committed attacks she performs a longer reposition using one of three deterministic movement patterns:

- diagonal withdrawal;
- wide orbit;
- crossing reset.

These windows are movement-only. The driver cannot request another attack, spell, or dodge until the cadence phase finishes.

## Tactical memory

The Ruvia driver tracks:

- recent attack forms;
- attacks since the last reposition;
- attacks since the last spell;
- actions committed to the current target;
- queued two-form melee plans;
- current tactical mode;
- current movement plan;
- pending target switch;
- total repositions and target changes.

Recent-action memory prevents Fire-field exploits and finishers from repeating every available frame.

## Fire planning

Ruvia now creates Fire terrain proactively. If no owned field exists, she will establish one after a short melee sequence or when a cluster makes field control valuable.

Once a field exists, the priority system can choose:

```text
target near field       -> Reaping Hook
Ruvia inside field      -> Scorching Thrust
field beside a cluster  -> Ember Wheel or Wildfire Cleave
Burning cluster         -> Solar Descent
```

Cinder Sweep and Backdraft Return can still schedule blade-tip Firebolt weaves. Haft Check can still schedule the close Fire Field plant.

## Melee plans

Ordinary melee is selected as a short plan rather than an endless entry-attack loop.

Examples:

```text
close pressure     -> Haft Check, Rising Brand
long melee range   -> Rising Brand, Cinder Sweep
large cluster      -> Wildfire Cleave, Ember Wheel
balanced exchange  -> Cinder Sweep, Backdraft Return
heavy answer       -> Furnace Drop, Cinder Sweep
```

The plan is interrupted when a higher-value Fire interaction, escape, target switch, or recall becomes available.

## Target pressure

After sustained pressure on one enemy, Ruvia searches for another valid hostile within her combat radius. If one exists, she changes targets and repositions before attacking again. If no alternate target exists, the counter resets and she continues fighting the current threat with the normal cadence.

## Diagnostics

`RuviaManifestationControlDriver.get_debug_data()` now exposes:

```text
tactical_mode
movement_plan
post_action_reassessment
reposition_remaining
reposition_requested
attacks_since_reposition
attacks_since_spell
actions_on_target
target_switch_pending
target_switch_cooldown
total_repositions
total_target_switches
recent_actions
planned_attacks
```

The existing showcase HUD already displays the current decision reason, so the visible companion plan should alternate among commitment, reassessment, repositioning, field setup, approach, attack forms, and target shifts.

## Regression

The existing manifestation regression now verifies:

- a distant target receives pressure;
- no second action is requested while an attack is active;
- a completed form creates a movement-only reassessment;
- two attacks trigger a movement-only reposition;
- a melee sequence causes proactive Fire Field setup;
- sustained pressure changes to a second target;
- tactical memory and cadence diagnostics are present.

Run:

```text
scenes/tests/avatar_control_driver_manifestation_smoke_test.tscn
```

Expected marker:

```text
AVATAR_CONTROL_DRIVER_MANIFESTATION_SMOKE_TEST: PASS
```

## Manual review

Open the animation showcase and press `F10`.

Watch for this sequence rather than raw attack count:

1. Ruvia establishes formation or approaches a target.
2. She commits to one or two forms.
3. She visibly circles, withdraws, or crosses before attacking again.
4. She creates a Fire Field without requiring the target to crowd her first.
5. She uses field-aware forms instead of repeating the same sweep.
6. After several actions, she changes to another training dummy when one is available.
7. Her decision reason in the HUD changes with the tactical state.

The driver remains a deterministic gameplay state machine, not a navigation or machine-learning system. Obstacle-scale pathfinding and encounter-level cooperation with Grace remain future layers.
