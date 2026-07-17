# Charged Firebolt Impact v1 Test

## Goal

Make Charged Firebolt feel visually heavier when it lands.

```text
full charge -> release -> hit target -> visual burst + flash + hitstop + camera nudge
```

## What changed

- `scripts/combat/charged_firebolt_impact_feedback.gd`
  - Adds a dedicated impact feedback utility for Charged Firebolt.
  - Detects charged Firebolt payloads by source name or by fire + charged/firebolt tags.
  - Spawns a larger fire/gold impact burst.
  - Spawns a brief target flash at the hit target.
  - Spawns a short ember mark near the impact point.
  - Requests a short HitStop pulse.
  - Nudges the current camera with a quick offset tween.
- `scripts/actions/generic_projectile.gd`
  - Routes projectile hits through the charged-impact utility.
  - Normal projectiles still use the existing generic elemental impact.

## Fast test scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

## Charged impact test

1. Pull branch `agent/charged-firebolt-impact-v1`.
2. Run the prototype upgrade lab scene.
3. Press `F6` or use the Charged Firebolt pedestal.
4. Equip Firebolt.
5. Hold cast until full charge.
6. Release into a passive target.
7. Confirm the charged projectile still fires.
8. Confirm impact shows a larger gold/fire burst.
9. Confirm the target briefly flashes.
10. Confirm a small ember mark appears near the impact.
11. Confirm there is a tiny hitstop pause.
12. Confirm the camera gives a small nudge.
13. Confirm the heavy impact haptic from Feedback Integration still happens.

## Normal Firebolt regression

1. Tap cast without charging.
2. Hit a passive target.
3. Confirm normal Firebolt uses the smaller generic impact.
4. Confirm normal Firebolt still uses the lighter hit collision haptic.
5. Confirm no big camera nudge happens for normal Firebolt.

## Stack regression

- Spell focus menu should still equip without firing.
- Controller-aware prompts should still switch between keyboard/mouse and controller.
- Charged Firebolt charge meter and full-charge haptic should still work.
- F5 feedback tester should still cycle presets.
- F8 lab reset should still work.

## Stack note

This PR is stacked on `agent/controller-ux-v1`. Merge order should be:

```text
1. #89 Integrate gameplay feedback haptics
2. #90 Make spell menu equip without casting
3. #91 Add controller-aware UI prompts
4. This PR
```

## Known limitations

- The ember mark is a prototype mesh decal, not a true terrain decal.
- Camera nudge is intentionally tiny and uses `Camera3D.h_offset` / `v_offset` for low-risk polish.
- Charged impact visuals are procedural placeholder meshes, not final VFX.
- I could not run Godot here, so parser and scene validation are needed.
