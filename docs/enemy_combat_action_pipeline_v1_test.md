# Enemy Combat Action Pipeline v1 Test

## Goal

Verify that enemy attack decisions become committed, readable actions with a reusable phase contract:

`DECIDING -> WINDUP -> ACTIVE -> RECOVERY -> COOLDOWN`

The enemy brain still decides when to attack. `EnemyActionRunner` owns the selected attack, locked direction, phase timing, interruption rules, and one-hit registration until the action finishes.

## Systems added

- `EnemyActionRunner`
  - Stores the committed attack.
  - Locks the attack direction when windup begins.
  - Advances through windup, active, and recovery phases.
  - Exposes phase time, interruption state, hit registration, and debug data.
- `EnemyCombatActionBrain`
  - Extends the existing personality and zone-aware brain.
  - Uses the runner instead of applying damage directly at the windup boundary.
  - Checks the locked melee shape throughout the active window.
  - Prevents one action from hitting Grace more than once.
  - Starts cooldown after recovery.
  - Allows sufficient force or an action-blocking status to interrupt windup.
- Attack definitions and attack classes
  - Add active duration.
  - Add movement multipliers for windup, active, and recovery.
  - Add per-phase interruption rules.
  - Preserve role tags for future action selection.
- Enemy telegraph
  - Adds a distinct active-phase flash and scale snap between windup and recovery.

## Migrated enemies

- Goblin Drone using `Goblin Claw`.
- Gremlin Drone using `Gremlin Bite`.

Both preserve their PR #106 personality profiles and zone-aware behavior.

## Manual playtest

1. Pull `agent/enemy-combat-action-pipeline-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Enable the developer/debug overlay.
5. Approach a Goblin and confirm the phase changes through:
   - `DECIDING`
   - `WINDUP`
   - `ACTIVE`
   - `RECOVERY`
   - `COOLDOWN`
6. During windup, move sideways or behind the Goblin.
7. Confirm the Goblin continues facing its committed direction instead of tracking Grace through the swing.
8. Confirm leaving the locked range/cone before or during the active window causes a miss.
9. Remain in the locked attack shape and confirm the attack damages Grace exactly once.
10. Confirm the Goblin remains vulnerable and unable to immediately attack during recovery and cooldown.
11. Apply `stunned`, `frozen`, or `staggered` during windup and confirm the telegraph resets and the attack does not land.
12. Hit the Goblin with enough knockback to exceed `force_interrupt_threshold` during windup and confirm the attack is interrupted.
13. Repeat with the Gremlin and confirm its faster bite timing is still readable.
14. Place Poison Bloom, Time Snare, and Dream Trap and confirm PR #106 personality and zone steering still work before an action begins.

## Debug fields

The combat brain exposes:

- `action`
- `phase`
- `phase_time`
- `interruptible`
- `hit`

The runner also exposes its last interruption reason.

## Definition tuning

Attack class resources can now tune:

```text
windup_time
active_time
recovery_time
cooldown
windup_move_speed_multiplier
active_move_speed_multiplier
recovery_move_speed_multiplier
interruptible_during_windup
interruptible_during_active
interruptible_during_recovery
```

Movement multipliers are zero for the first claw and bite actions. Future lunges and gap closers can move along the locked action direction without adding a new brain state machine.

## Known limitations

- Melee contact currently uses the existing range-and-cone model as a locked active-window shape rather than a physics `Area3D` hitbox.
- The first version supports one committed action at a time but does not yet score or choose among multiple attacks.
- Personality changes when the enemy commits, but it does not rewrite timing after the action begins.
- Projectile, area, summon, and support deliveries still need their own execution adapters.

## Explicitly unchanged

- PR #106 personality profile values.
- Zone awareness and hazard steering.
- Player damage plumbing through `GameState.take_damage`.
- Existing enemy definitions, health, stance, resistances, and force receivers.
