# Spell Menu Select v1 Test

## Goal

Make the focus spell menu behave like a selection menu.

```text
open spell menu -> highlight spell -> confirm -> equip spell -> release menu -> cast normally
```

Before this pass, the confusing path was:

```text
highlight spell -> press cast -> selected spell immediately casts
```

That made equipping feel like it was secretly tied to firing the spell.

## What changed

- Adds `scripts/abilities/ability_caster_menu_select.gd`.
  - Extends the existing `AbilityCaster` so the main casting and Charged Firebolt logic stay untouched.
  - Overrides only focus-menu input.
  - `cast_spell`, `ui_accept`, `interact`, Enter, Space, and left click now equip the highlighted spell while the menu is open.
  - Confirming from the menu no longer spends mana.
  - Confirming from the menu no longer fires a projectile.
  - The menu closes after a successful equip.
  - Escape, cancel, or right click closes the menu.
- Updates `scenes/actors/player/player.tscn` so the Player's `AbilityCaster` uses the select-only wrapper.

## Fast test scene

Open:

```text
scenes/levels/prototypes/prototype_upgrade_lab_v1.tscn
```

## Test flow

1. Run Current Scene.
2. Hold the spell menu / focus input.
3. Move between elements.
4. Move between spells.
5. Highlight Firebolt or another learned spell.
6. Press cast / RT / Q while the menu is open.
7. Confirm the spell equips.
8. Confirm no projectile fires during menu selection.
9. Confirm mana does not decrease from selecting.
10. Release the menu input.
11. Press cast normally outside the menu.
12. Confirm the equipped spell casts normally.

## Regression checks

- Number hotkeys should still equip spells directly.
- Next ability should still cycle spells.
- Charged Firebolt should still charge when Firebolt is equipped and the upgrade is unlocked.
- The feedback PR's haptics should still work because this branch is stacked on `agent/feedback-integration-v1`.

## Known limitations

- The visual menu copy may still need a later wording polish in `GameUI` so it says `Selected` / `Equip` everywhere instead of older prototype language.
- This is intentionally a wrapper around the existing caster, so parser risk stays small.
- I could not run Godot here, so scene/script validation is needed.
