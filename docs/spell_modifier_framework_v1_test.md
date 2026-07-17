# Spell Modifier Framework v1 Test

## Goal

Move simple spell upgrade behavior out of one-off spell hooks and into a shared registry.

```text
spell_id + unlock_id -> payload changes + projectile changes
```

This pass keeps Charged Firebolt's hold/release behavior in `AbilityCaster`, because charge timing depends on input state. It moves the simpler Piercing Ice Lance payload/projectile changes into `SpellModifierRegistry` so future upgrades can follow the same pattern.

## What changed

- Added `scripts/abilities/spell_modifier_registry.gd`.
- Refactored `scripts/abilities/ability_caster_menu_select.gd` to ask the registry for active payload modifiers.
- Refactored `scripts/actions/generic_projectile.gd` to ask the registry for projectile runtime modifiers.
- Preserved Piercing Ice Lance behavior:
  - source name becomes `Piercing Ice Lance`
  - payload gains `piercing`, `upgrade`, `ice_lance`, and `piercing_ice_lance` tags
  - health and stance pressure increase slightly
  - projectile becomes faster
  - projectile can hit up to 4 targets
  - projectile uses a tighter trail interval
  - impact pop is slightly larger
- Preserved Charged Firebolt's custom charge behavior and impact polish.

## Test scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

## Regression test: Ice Lance before unlock

1. Run Current Scene.
2. Press F8 for a clean lab state if needed.
3. Equip Ice Lance from the focus spell menu.
4. Aim down the center target line.
5. Cast Ice Lance before unlocking `piercing_ice_lance`.
6. Confirm it hits only one target.
7. Confirm the message still says `Ice Lance` rather than `Piercing Ice Lance`.

## Framework test: Piercing Ice Lance after unlock

1. Use the Piercing Ice Lance pedestal, or press F6.
2. Confirm `Piercing Ice Lance` appears in Relics / Spell Upgrades.
3. Equip Ice Lance again if needed.
4. Aim down the center target line.
5. Cast Ice Lance.
6. Confirm the projectile can hit multiple targets.
7. Confirm hit messages use `Piercing Ice Lance`.
8. Confirm the projectile still disappears after the pierce limit or lifetime.
9. Use Target Reset and retest.

## Fire regression

1. Equip Firebolt.
2. Tap cast.
3. Confirm normal Firebolt still casts normally.
4. Unlock Charged Firebolt if needed.
5. Hold cast until full charge.
6. Release into a target.
7. Confirm Charged Firebolt still charges, rumbles, hits, and uses the charged impact visuals.

## Reset regression

1. Press F8 or use Progress Reset.
2. Equip Ice Lance.
3. Cast down the lined targets.
4. Confirm Ice Lance goes back to non-piercing behavior.

## Known limitations

- This is not the final modifier engine yet.
- Charge-style upgrades still need custom timing code.
- The registry currently covers payload and projectile runtime changes.
- Future versions can add status changes, area changes, summon changes, cooldown changes, and visual presets.
