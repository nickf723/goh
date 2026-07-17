# Menu UX Rebuild v1 Test

## Goal

Make the full menu easier and more fun to scan.

The old menu was mostly text lists. This pass turns it into a compact field kit:

```text
Loadout -> Magic -> Relics -> Grace -> Journal -> Codex -> System
```

## What changed

- `scripts/ui/full_menu_shell_key_items.gd`
  - Replaces the old key-item-only subclass with a compact full menu shell.
  - Uses icon-led tabs:
    - Loadout
    - Magic
    - Relics
    - Grace
    - Journal
    - Codex
    - System
  - Keeps spell hotkey assignment working.
  - Adds compact summary cards at the top of important tabs.
  - Shows Relics grouped as:
    - Blessings
    - Key Items
    - World Permissions
  - Shows progression unlocks directly from `GameState`.
  - Shows Guard in the Grace resource summary.
  - Reduces long placeholder paragraphs into shorter cards.

## How to test

1. Pull branch `agent/menu-ux-rebuild-v1`.
2. Open Godot.
3. Open `scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn`.
4. Run Current Scene.
5. Press `Tab` or `M` to open the full menu.
6. Confirm the left tabs show:

```text
Loadout
Magic
Relics
Grace
Journal
Codex
System
```

7. Navigate with `A/D`, left/right, mouse, or number keys `1-7`.
8. Confirm Loadout still shows spell hotkeys.
9. Choose a spell hotkey, then assign a learned spell from Magic.
10. Confirm spell assignment still works.
11. Press `F8` for a fresh save if needed.
12. Defeat the Animated Armor.
13. Claim the Church Trial Sigil.
14. Open the menu again.
15. Confirm Relics shows:

```text
Armor Trial Blessing under Blessings
Church Trial Sigil under Key Items
Church Trial Doors under World Permissions
```

16. Sleep at a save bed after gaining the blessing.
17. Confirm Grace tab shows Guard in the resource summary.
18. Confirm no parser errors from `full_menu_shell_key_items.gd`.

## What this does not do yet

- Final custom art icons.
- Expandable lore/detail panels.
- Mouse hover tooltips.
- Controller-specific UI polish.
- Dedicated inventory item database.

## Why this matters

The game is moving toward lots of mechanics and unlocks. This menu gives those rewards a clean display case instead of burying them in text sludge.
