# Poison Bloom v1 Test

## Goal

Turn Poison Cloud into a ground-targeted field spell using the Earth Spike targeting foundation.

```text
equip Poison Bloom -> press cast -> move green circle -> press cast again -> poison cloud blooms
```

## Setup

1. Pull branch `agent/poison-bloom-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Press F8 if you want a clean lab state.

## Ground targeting flow

1. Equip `Poison Bloom` from the spell focus menu.
2. Press cast once.
3. Confirm a green targeting circle appears on the ground.
4. Move the right stick.
5. Confirm the circle moves instead of the camera.
6. Press cancel / Esc / right click.
7. Confirm the marker disappears and no mana is spent.
8. Press cast again to enter targeting.
9. Move the circle over the target lane.
10. Press cast again to confirm.
11. Confirm a lingering poison cloud appears at the selected position.
12. Confirm targets inside the cloud receive poison status ticks.
13. Confirm the cloud fades after its normal lifetime.

## Regression checks

1. Equip Earth Spike.
2. Confirm Earth Spike still uses the brown ground marker and instant spike eruption.
3. Equip Firebolt and confirm normal projectile casting still works.
4. Unlock Charged Firebolt and confirm charge/release still works.
5. Equip Ice Lance and confirm normal/piercing behavior still works.
6. Equip Lightning Spark and confirm normal/Chain Lightning behavior still works.
7. Cast Poison Bloom, then cast Firebolt into the cloud.
8. Confirm the existing poison cloud toxic-ignition reaction still works.
9. Cast Poison Bloom, then cast Wind Gust into the cloud.
10. Confirm the existing cloud-spread reaction still works.

## Expected behavior

- Poison Bloom uses the same right-stick placement feel as Earth Spike.
- The player camera should pause while the green marker is active.
- Confirming spends Poison Bloom's normal mana cost.
- Canceling should not spend resources.
- The cloud should spawn where the marker was placed, not simply in front of Grace.

## Known limitations

- Mouse hover placement is still not implemented.
- The cloud visual is the existing prototype PoisonCloud visual.
- Ground targeting still lives in the caster wrapper. A future pass should extract a shared ground-targeting controller/action.
