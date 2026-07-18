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
- `EnemyLungeActionBrain`
  - Reuses the same action runner for committed gap-closing movement.
  - Separates the range where an enemy may begin a lunge from the close contact range that can actually hit.
  - Moves along the direction locked at windup start.
  - Can stop movement after registering a hit while preserving recovery.
- Attack definitions and attack classes
  - Add active duration.
  - Add movement multipliers for windup, active, and recovery.
  - Add per-phase interruption rules.
  - Preserve role tags for future action selection.
- Enemy telegraph
  - Adds a distinct active-phase flash and scale snap between windup and recovery.

## Migrated enemies

- Goblin Drone using `Goblin Claw` as the stationary melee baseline.
- Gremlin Drone using `Gremlin Pounce` as the first moving action.

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

## Gremlin pounce test

1. Stand roughly 2.5 to 3 meters from a Gremlin.
2. Confirm it can begin winding up before entering its 0.9-meter contact range.
3. Confirm its body crouches during windup, stretches during the active phase, and travels along one locked line.
4. Sidestep after the crouch begins.
5. Confirm the Gremlin passes or slides beside Grace instead of turning to follow her.
6. Confirm a missed pounce still enters the full recovery window.
7. Repeat without dodging and confirm the pounce damages Grace once when the Gremlin reaches contact range.
8. Confirm the Gremlin stops driving forward after a successful hit but still finishes recovery and cooldown.
9. Interrupt the windup with stun, freeze, stagger, or sufficient knockback and confirm no launch occurs.
10. Place Poison Bloom, Time Snare, and Dream Trap and confirm the skittish personality still affects approach and commitment before the pounce begins.

## Debug fields

The combat brain exposes:

- `action`
- `phase`
- `phase_time`
- `interruptible`
- `hit`

The lunge adapter also exposes:

- `lunge_start`
- `lunge_contact`

The runner exposes its last interruption reason.

## Definition tuning

Attack class resources can tune:

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

`Gremlin Pounce` uses a 2.75 active movement multiplier for 0.3 seconds. Its lunge adapter begins commitment at 3.1 meters but only registers contact inside 0.9 meters and a narrow locked cone.

## Known limitations

- Melee contact currently uses range-and-cone checks rather than a physics `Area3D` hitbox.
- The first version supports one committed action at a time but does not yet score or choose among multiple attacks.
- Lunge start and contact ranges currently live on the lunge brain instance rather than the attack resource.
- Personality changes when the enemy commits, but it does not rewrite timing after the action begins.
- Projectile, area, summon, and support deliveries still need execution adapters.

## Explicitly unchanged

- PR #106 personality profile values.
- Zone awareness and hazard steering.
- Player damage plumbing through `GameState.take_damage`.
- Existing enemy definitions, health, stance, resistances, and force receivers.
