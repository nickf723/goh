# Piercing Ice Lance v1 Test

## Goal

Give Ice its first real upgrade path and prove that the upgrade framework works beyond Firebolt.

```text
unlock Piercing Ice Lance -> equip Ice Lance -> cast through lined targets -> several targets react
```

## What changed

- Adds `piercing_ice_lance` to the unlock catalog.
- Adds a `Piercing Ice Lance` pedestal to the prototype upgrade lab.
- Adds `piercing_ice_lance` to the editor F6 lab shortcut.
- Adds a casting hook in `ability_caster_menu_select.gd`.
  - If Ice Lance is equipped and the unlock is active, the spell uses a duplicate payload named `Piercing Ice Lance`.
  - The payload gains `piercing`, `upgrade`, and `ice_lance` tags.
  - The payload gets slightly stronger health / stance pressure.
- Adds generic projectile support for piercing Ice Lance payloads.
  - Faster projectile speed.
  - Smaller trail interval.
  - Hit limit raised to 4.
  - Projectile does not vanish on the first target.
  - Slightly larger ice impact pop.
- Adds lined test targets in the upgrade lab.

## How to test

1. Pull branch `agent/piercing-ice-lance-v1`.
2. Open `scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn`.
3. Run Current Scene.
4. Equip Ice Lance from the spell focus menu.
5. Cast Ice Lance at the center target line before unlocking.
6. Confirm it hits only the first target.
7. Use the `Piercing Ice Lance` pedestal, or press F6.
8. Confirm the unlock appears in the Relics / Spell Upgrades list.
9. Equip Ice Lance again if needed.
10. Stand roughly centered with the three center targets.
11. Cast Ice Lance down the line.
12. Confirm it can hit multiple targets before vanishing.
13. Confirm Firebolt and Charged Firebolt still behave normally.
14. Use Target Reset and confirm the lined targets can be tested again.
15. Use Progress Reset / F8 and confirm Ice Lance goes back to non-piercing.

## Expected feel

- Normal Ice Lance should still feel like a single-target control spell.
- Piercing Ice Lance should feel faster, sharper, and better for lined-up enemies.
- This is not meant to be Chain Lightning-level smart targeting yet. It is a straight-line projectile rule.

## Known limitations

- Prototype visuals only use the existing ice projectile and a slightly larger impact pop.
- There is no unique icy trail mesh yet.
- Piercing is implemented as a small upgrade hook in the menu-select caster wrapper, not the final modifier engine.
- Lined target testing depends on positioning Grace and the camera cleanly.
- Godot validation needed.
