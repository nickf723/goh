# Earth Spike Targeting v1 Test

## Goal

Turn Earth Spike from a forward projectile into the first prototype ground-targeted AoE spell.

```text
equip Earth Spike -> press cast -> move circle -> press cast again -> spikes erupt from the ground
```

## What changed

- Earth Spike now enters a targeting mode instead of launching a projectile immediately.
- A translucent ground circle appears at a fixed starting distance in front of Grace.
- The right stick / camera look vector moves the circle across the floor.
- The circle is clamped to a short range around Grace.
- Cast / accept confirms the placement.
- Cancel backs out without spending resources.
- Confirming spends Earth Spike's normal mana cost.
- A small stone eruption visual appears at the target point.
- Enemies inside the circle receive the Earth Spike payload.
- While the targeting circle is active, the spell focus-menu flag is reused so controller camera movement pauses and right stick motion can drive the marker.

## How to test

1. Pull branch `agent/earth-spike-targeting-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Equip Earth Spike from the spell focus menu.
5. Press cast once.
6. Confirm a brown / earth targeting circle appears on the ground.
7. Move the right stick.
8. Confirm the circle moves instead of the camera.
9. Press cancel / Esc.
10. Confirm the marker disappears and no mana is spent.
11. Press cast once again to reopen targeting.
12. Move the circle over one or more training targets.
13. Press cast again to confirm.
14. Confirm stone spikes erupt.
15. Confirm targets inside the circle react to Earth Spike.
16. Confirm targets outside the circle are not hit.
17. Confirm Firebolt, Ice Lance, Lightning Spark, Chain Lightning, and Charged Firebolt still work.

## Notes

- This is the first reusable shape for ground spells like Poison Bloom, Meteor, Dream Trap, Time Field, and Life Grove.
- Mouse placement is not implemented yet. The first pass is controller/right-stick driven.
- The eruption visual is prototype geometry, not final art.
- The targeting mode currently lives in the menu-select caster wrapper so it can iterate quickly before a generalized targeting controller is extracted.
