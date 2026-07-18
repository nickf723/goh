# Ground Targeting Framework v1 Test

## Goal

Extract the shared right-stick ground placement logic used by Earth Spike and Poison Bloom into a reusable controller.

```text
ground-targeted spell -> start placement -> move marker -> confirm/cancel -> spell-specific result
```

## What changed

- Adds `scripts/abilities/ground_targeting_controller.gd`.
- The controller owns marker creation, movement, range clamp, floor raycast, pulse visuals, and cleanup.
- `ability_caster_menu_select.gd` now routes Earth Spike and Poison Bloom through the controller.
- Earth Spike still confirms into an instant spike AoE.
- Poison Bloom still confirms into a placed poison cloud.
- Spell-specific payload and effect logic remains in the caster for now.
- This is a framework extraction, not a new spell.

## How to test

1. Pull branch `agent/ground-targeting-framework-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Equip Earth Spike.
5. Press cast once.
6. Confirm the brown targeting circle appears.
7. Move the right stick and confirm the marker moves instead of the camera.
8. Press cancel / Esc / right click and confirm no mana is spent.
9. Enter Earth Spike targeting again.
10. Place the marker over a target.
11. Press cast again.
12. Confirm stone spikes erupt and targets inside react.
13. Equip Poison Bloom.
14. Press cast once.
15. Confirm the green targeting circle appears.
16. Move the marker with the right stick.
17. Press cast again.
18. Confirm the poison cloud blooms at the marker.
19. Confirm poison ticks still work.
20. Cast Firebolt into the cloud and confirm toxic ignition still works.
21. Cast Wind Gust into the cloud and confirm cloud spread still works.
22. Confirm Firebolt, Charged Firebolt, Ice Lance, Piercing Ice Lance, Lightning Spark, and Chain Lightning still behave normally.

## Known limitations

- Mouse-hover placement is still not implemented.
- The caller still owns confirm behavior. A future `GroundTargetedSpellAction` can move this fully out of the caster.
- Marker art is still prototype geometry.
