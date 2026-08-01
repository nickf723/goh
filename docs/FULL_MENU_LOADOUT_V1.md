# Full Menu Shell and Loadout v1

## Purpose

This slice turns Loadout into a compact dashboard instead of one continuous catalog. It keeps the existing equipment, spell, item, familiar, mastery, and settings systems intact while giving Loadout focused nested pages.

## Menu structure

The Loadout overview contains six categories:

- Equipment
- Weapon Infusion
- Spell Ring
- Quick Belt
- Divine Special
- Familiar Blueprint

Selecting a category opens one focused page. `B` or `Esc` returns to the Loadout overview before closing the full menu.

The top-level tab contract remains:

- `LB` / `RB` or `Q` / `E`: change tabs
- D-pad, left stick, or WASD: navigate
- `A` or Enter: open, equip, assign, or select
- `B` or Esc: back one level, then close
- Tab, M, or Menu: close directly

## HUD and input isolation

Opening the full menu:

- pauses the scene tree;
- hides the legacy GameUI children;
- hides Player HUD v2;
- hides the separate Divine Special HUD;
- leaves only the full menu visible;
- blocks D-pad Down from entering the Divine Special tap/hold grammar.

Closing the menu restores each HUD element to its previous visibility state.

## Manual test

1. Pull `agent/menu-shell-loadout-v1`.
2. Open `res://scenes/levels/prototypes/prototype_familiar_training_yard_v1.tscn`.
3. Run the scene and open the full menu with Tab, M, or the controller Menu button.
4. Confirm the gameplay HUD, command dock, and Divine Special HUD disappear.
5. Confirm the Loadout overview shows six category tiles without a long initial scroll.
6. Navigate the six tiles with the D-pad or left stick.
7. Open Equipment, then press B. Confirm B returns to the Loadout overview instead of closing the entire menu.
8. Open Weapon Infusion and change the active edge.
9. Open Spell Ring, select a slot, assign a learned spell, and confirm the menu returns to Spell Ring.
10. Open Quick Belt, select a direction, assign an item, and confirm the menu returns to Quick Belt.
11. Open Divine Special and select a different unlocked Ruvia Special. Confirm selection does not spend charge or activate it.
12. Open Familiar Blueprint and change role, temperament, command, or techniques.
13. While the menu is open, tap and hold D-pad Down. No Divine Special radial or activation should occur.
14. Close the menu. Confirm every HUD element returns and the configured choices work immediately in gameplay.
15. Reopen the menu and confirm top-level tab focus remains stable.

## Focused smoke test

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/full_menu_loadout_v1_smoke_test.tscn
```

Expected marker:

```text
FULL_MENU_LOADOUT_V1_SMOKE_TEST: PASS
```

## Deliberate boundaries

- This pass completes the shared shell behavior and the Loadout information architecture.
- The other seven tabs retain their current content and will be rebuilt one at a time.
- A persistent side-by-side detail inspector is deferred until the shared browser pattern is applied to Magic and Items.
- Final glyph assets, audio cues, transitions, and accessibility narration remain later polish.
