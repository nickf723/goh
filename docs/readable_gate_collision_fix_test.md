# Readable Gate Collision Fix Test

## Goal

Fix the mini-dungeon puzzle gate case where the gate visual disappears but the collision can remain active.

The readable gate now treats unlock as two separate actions:

```text
hide visual barrier
fully disable gate collision
```

## What changed

- `scripts/interaction/readable_magic_gate.gd`
  - Keeps hiding the configured barrier visual.
  - Clears the gate body's `collision_layer` and `collision_mask`.
  - Disables the named `BarrierCollision` node when present.
  - Recursively disables every child `CollisionShape3D` under the gate.
  - Uses `set_deferred` for collision changes so physics state updates safely.

## Why

The first combat gate worked, but the puzzle gate could hide the blue barrier while leaving collision behind. That made the gate look open while still blocking Grace, except for tiny squeeze gaps.

This patch makes unlock more robust across gate instances, inherited scenes, renamed collision shapes, or future nested gate collision pieces.

## How to test

1. Pull branch `agent/readable-gate-collision-fix-v1`.
2. Open Godot.
3. Open `scenes/levels/prototypes/prototype_mini_dungeon_chain_v1.tscn`.
4. Run Current Scene.
5. Clear Room 2 combat.
6. Confirm the first gate opens and is passable.
7. Activate the Water Lock with Water.
8. Activate the Fire Lock with Fire.
9. Confirm the final gate visual disappears.
10. Walk straight through the center of the final gate frame.
11. Confirm Grace does not need to squeeze through a side gap.
12. Step onto the final gold exit pad.

## Expected result

Both gates should behave the same way:

```text
locked = blue barrier blocks the path
unlocked = blue barrier disappears and path is fully passable
```

## Regression checks

- The gold gate frame should still stay visible after unlock.
- The combat gate should still open after both enemies are defeated.
- The puzzle gate should still open only after both element-lock targets are active.
