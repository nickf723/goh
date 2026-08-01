# Grace Menu and Loadout v1

## Purpose

This slice combines the old Grace and Loadout tabs into one player-centered screen. Grace is visible as an equipment-aware procedural preview, the active field configuration sits beside her, and the ten favorite spells form one compact ribbon beneath her.

The screen answers one question:

> What will Grace bring into the world when the menu closes?

## Top-level menu

The full menu now has seven tabs:

- Grace
- Magic
- Items
- Relics
- Journal
- Codex
- System

Familiar configuration is intentionally absent from Grace. Creature mastery and Familiar Blueprints remain under Magic, where they can grow into the broader spell-customization workspace.

## Grace layout

The Grace tab contains:

- a procedural Grace preview;
- weapon, outfit, charm, and relic slots;
- weapon infusion;
- the quick-item cycle;
- the selected Divine Special;
- one horizontal ten-slot favorite spell ring.

The preview responds to equipped weapon and outfit IDs. Weapon infusion changes its weapon glow, while equipped charm and relic slots add visible accessories. Final character art and mesh-based wardrobe presentation can replace this preview without changing the menu contract.

## Controller contract

- `LB` / `RB`: change tabs
- D-pad or left stick: navigate
- `A` / right face: confirm
- `B` / bottom face: back or close
- Tab, M, or controller Menu: close directly

Nintendo controllers receive physical-face translation so the right face button confirms and the bottom face button cancels despite SDL logical-button normalization.

Controller input is routed in `_input` while the menu is open, before focused GUI Controls can consume shoulder or face-button events.

## Favorite spells and quick items

D-pad ownership outside Focus is:

```text
Up tap          Cycle quick items
Up hold         Use selected quick item
Left / Right    Cycle favorite spells
Down tap        Activate selected Divine Special
Down hold       Browse Divine Specials
```

The quick-item menu therefore presents four ordered cycle slots rather than pretending each item owns a separate D-pad direction.

The favorite spell ring is displayed as one `1 × 10` ribbon on the Grace page. Selecting any ribbon slot opens the existing learned-spell assignment flow and returns to the same slot afterward.

## HUD and input isolation

Opening the full menu:

- pauses the scene tree;
- hides legacy GameUI children;
- hides Player HUD v2 and the command dock;
- hides the Divine Special HUD;
- hides scene-specific HUD panels marked `menu_suppressed_hud`;
- blocks D-pad Down from entering Divine Special gameplay input.

The Familiar Training Yard mastery panel now uses the suppression group and no longer appears over the menu.

Closing the menu restores each HUD element to its previous visibility state.

## Manual test

1. Pull `agent/menu-shell-loadout-v1`.
2. Open `res://scenes/levels/prototypes/prototype_familiar_training_yard_v1.tscn`.
3. Open the full menu with Tab, M, or the controller Menu button.
4. Confirm the creature-mastery panel and all ordinary gameplay HUD layers disappear.
5. Confirm there is one Grace tab and no separate Loadout or Grace duplicate.
6. Confirm Grace appears on the left and her preview reflects weapon, outfit, charm, relic, and infusion changes.
7. Navigate with the D-pad. Confirm controller `A` selects and `B` backs out.
8. Move to Magic with `RB`, then return to Grace with `LB`.
9. Equip each equipment category and confirm the preview refreshes.
10. Change Weapon Infusion and confirm the preview weapon glow changes.
11. Open Quick Items and confirm the four entries are cycle slots, not D-pad directions.
12. Select each of the ten spell-ribbon slots and confirm assignment returns to that slot.
13. Confirm Familiar Blueprints remain available under Magic and are absent from Grace.
14. Select a Divine Special without activating it or spending charge.
15. Tap and hold D-pad Down while the full menu is open. No gameplay Special input should occur.
16. Close the menu and confirm all HUD layers return.

## Focused smoke test

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/full_menu_loadout_v1_smoke_test.tscn
```

Expected marker:

```text
FULL_MENU_LOADOUT_V1_SMOKE_TEST: PASS
```

The regression covers the seven-tab structure, removal of the duplicate Grace tab, the seventeen Grace actions, the single-row ten-spell ribbon, nested Back behavior, left-shoulder navigation, and Nintendo/Xbox confirm-cancel mappings.

## Deliberate boundaries

- The procedural Grace figure is a replacement-ready menu preview, not final character art.
- Familiar and spell customization will receive a dedicated Magic-tab rebuild next.
- The underlying quick-item inventory still stores four slots; this pass changes their presentation to ordered cycle positions.
- Final glyph assets, audio cues, transitions, comparison panels, and accessibility narration remain later polish.
