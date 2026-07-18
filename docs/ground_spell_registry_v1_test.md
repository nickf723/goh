# Ground Spell Registry v1 Test

## Goal

Confirm the ground-targeted spell family now routes through one registry-backed caster path instead of stacking one wrapper per spell.

## Branch

`agent/ground-spell-registry-v1`

## What changed

- Added `scripts/abilities/ground_spell_registry.gd`.
- Moved spell matching, targeting marker config, payload shaping, and confirm messages for the current ground spells into that registry.
- Updated `scripts/abilities/ability_caster_menu_select.gd` so it asks the registry whether the equipped spell is ground-targeted.
- Swapped the player scene back to `ability_caster_menu_select.gd` as the single active caster script.
- Existing field scenes still own their own runtime behavior.

## Test plan

1. Pull `agent/ground-spell-registry-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Equip `Earth Spike`.
5. Confirm the brown marker appears, moves with right stick, cancels cleanly, and erupts on confirm.
6. Equip `Poison Bloom`.
7. Confirm the green marker appears, moves with right stick, cancels cleanly, and places the poison field on confirm.
8. Equip `Time Snare`.
9. Confirm the gold marker appears, moves with right stick, cancels cleanly, and places the slow field on confirm.
10. Equip `Dream Trap`.
11. Confirm the violet marker appears, moves with right stick, cancels cleanly, and places the trigger field on confirm.
12. Let an enemy enter Dream Trap and confirm the burst / stagger still happens.
13. Confirm Firebolt and Charged Firebolt still cast normally.
14. Confirm Ice Lance and Piercing Ice Lance still cast normally.
15. Confirm Lightning Spark and Chain Lightning still cast normally.
16. Confirm the focus spell menu still equips spells without firing while it is open.

## Expected behavior

All four ground spells should behave like they did before, but the player should now be using one caster script:

`res://scripts/abilities/ability_caster_menu_select.gd`

## Known limitations

- Mouse-hover placement is still not implemented.
- The field scene behaviors are still separate scripts.
- Future work can turn this into exported Resources instead of a hardcoded registry dictionary.
