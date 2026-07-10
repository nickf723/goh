# Full Menu Shell v1 Test

## Goal

Add a structured, pause-style menu that can become the home for loadouts, weapons, augments, journals, quests, codex entries, and system options.

This is a structure pass, not a full inventory/loadout editing pass.

## What exists now

Open the full menu with:

```text
Tab or M
```

Close it with:

```text
Tab, M, or Esc
```

Switch tabs with:

```text
A/D, Left/Right, Up/Down, or 1-4
```

## Current tabs

### Loadout

Shows equipped spells as physical menu cards. Each spell card includes:

- Slot number
- Display name
- Element
- Delivery type
- Targeting style
- Trait profile
- Costs
- Roles
- Combo tags
- Status tags
- Design notes

Also shows the currently equipped weapon if the player has a `WeaponController` with an `equipped_weapon`.

### Journal

Shows:

- Current objective from the existing UI
- Placeholder main quest/clue structure

### Codex

Shows current `ComboRuleRegistry` rows so the reaction grammar is visible in-game.

This should include generic and hazard combo rules, such as:

- Fire + oily -> ignite oil
- Lightning + wet -> wet conduction
- Ice + wet -> wet freeze
- Force + frozen -> shatter
- Air + poison cloud -> cloud spread
- Air + fire field -> fanned flames
- Fire + poison cloud -> toxic ignition

### System

Shows placeholder controls/settings structure.

## Architecture

- `scripts/ui/full_menu_shell.gd`
  - Visual shell and tab layout.
  - Renders Loadout, Journal, Codex, and System tabs.
- `scripts/ui/full_menu_director.gd`
  - Autoload director.
  - Adds the shell to the existing `game_ui` CanvasLayer.
  - Opens/closes the menu.
  - Pauses gameplay while open.
  - Builds menu data from the current scene.
- `project.godot`
  - Registers `FullMenuDirector` as an autoload.

## Test steps

1. Pull branch `agent/full-menu-shell-v1`.
2. Open the project in Godot.
3. Confirm no parser errors from:
   - `full_menu_shell.gd`
   - `full_menu_director.gd`
4. Run the usual dev scene.
5. Press `Tab` or `M`.
6. Confirm the menu opens and gameplay pauses.
7. Switch through Loadout, Journal, Codex, and System.
8. Confirm the Loadout tab shows the current spell cards.
9. Confirm the Codex tab shows combo rule rows.
10. Press `Esc`, `Tab`, or `M` to close.
11. Confirm gameplay resumes.

## Expected known limitations

- No actual swapping yet.
- No augments yet.
- No inventory screen yet.
- No quest database yet.
- The current goal is structure and visibility so future systems have an obvious place to attach.
