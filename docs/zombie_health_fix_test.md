# Zombie Health Fix Test

## Goal

Fix the runtime zombie so `STANCE_THEN_HEALTH` can actually transition from stance damage to health damage.

## What changed

`DevRuntimeEnemyFactory` now sets:

```gdscript
hit_receiver.set("resets_stance_after_break", false)
```

Previously, the zombie used `STANCE_THEN_HEALTH` but also reset stance immediately after a stance break. That meant stance refilled forever and health damage never happened.

## How to test

1. Pull branch `agent/zombie-health-fix-v1`.
2. Run the usual dev scene.
3. Press `F6` to spawn the test wave.
4. Hit the zombie until its stance breaks.
5. Keep attacking.

Expected result:

- First hits reduce stance.
- After stance reaches 0, follow-up hits reduce health.
- Zombie eventually dies and disappears.

## Notes

This preserves the idea that zombies are tanky, but removes accidental immortality.
