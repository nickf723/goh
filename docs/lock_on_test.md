# Lock-On v1 Test

## Goal

Add the first enemy targeting pass so controller combat can stop feeling like spell billiards.

## Controls

- `R3` / right stick click: lock onto nearest visible enemy.
- `T`: keyboard fallback lock-on toggle.
- Press the same control again: release lock-on.

The lock-on input is registered at runtime for this prototype, so it does not require manual Project Settings changes.

## How to test

1. Pull branch `agent/lock-on-v1`.
2. Run the usual dev scene.
3. Use `F9` / `F10` to select a combat scenario, such as `Goblin Duel`, `Zombie Duel`, or `Hazard Combo Lab`.
4. Press `F6` to spawn enemies.
5. Press `R3` or `T`.
6. Confirm Grace locks onto a nearby visible enemy.
7. Confirm a small golden marker appears above the target.
8. Move with the left stick while locked on.
9. Cast a projectile or hazard spell and confirm aiming is biased toward the target.
10. Press `R3` / `T` again and confirm lock-on releases.

## Expected behavior

- Lock-on picks a nearby enemy that is roughly in front of the camera.
- Grace turns toward the target while locked on.
- The camera stays biased toward the target.
- The target marker follows the enemy.
- If the target dies or gets too far away, lock-on clears itself.
- Focus spell selector still works normally.

## Known risks

- Some controller drivers may report right-stick click as a different button index. If `R3` does nothing but `T` works, the lock-on action needs a controller button remap.
- V1 uses camera/player facing to bias spell direction. A later pass can route exact locked-target vectors into every action shape.
