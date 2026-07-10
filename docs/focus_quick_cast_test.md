# Focus Quick-Cast Test

## Goal

Make spell combo casting feel good on controller and keyboard by allowing Grace to cast directly from the focus selector while time is slowed.

This turns the old loop:

```txt
hold focus -> choose spell -> equip -> release focus -> cast
```

into:

```txt
hold focus -> choose spell -> cast -> choose another spell -> cast -> release focus
```

## Changed files

- `scripts/abilities/ability_caster.gd`
- `scripts/systems/focus_time.gd`

## Controls to test

### Controller

- Hold `ZL` / left trigger: open focus selector.
- D-pad left/right: change element.
- D-pad up/down: change spell within the selected element.
- Press `ZR` / right trigger while focus is held: quick-cast highlighted spell.
- Press `A` / accept while focus is held: equip highlighted spell without casting, if the controller maps it to `ui_accept`.
- Release `ZL`: close focus selector.
- Press `ZR` outside focus: cast currently equipped spell.

### Keyboard / mouse

- Hold `Shift` or right mouse: open focus selector.
- Left/right arrows: change element.
- Up/down arrows or mouse wheel: change spell.
- Press `Q` or left click while focus is held: quick-cast highlighted spell.
- Press Enter or Space while focus is held: equip highlighted spell without casting.
- Release focus: close selector.
- Press `Q` outside focus: cast currently equipped spell.

## Combo recipe

Use `Hazard Combo Lab`:

1. Press `F9` / `F10` until `Hazard Combo Lab` is selected.
2. Press `F6` to spawn enemies.
3. Hold focus.
4. Select `Poison -> Poison Cloud`.
5. Press `ZR` / `Q` to quick-cast it.
6. While still holding focus, select `Fire -> Fire Field`.
7. Press `ZR` / `Q` to quick-cast it overlapping the poison cloud.
8. Look for `Toxic Ignition!`.
9. Repeat with `Air -> Wind Gust` to test Cloud Spread / Fanned Flames.

## Expected behavior

- The focus selector stays open after quick-casting.
- Time stays slowed while chaining spells.
- `ZR` / `Q` quick-casts the highlighted spell while focus is held.
- `ZR` / `Q` still casts the equipped spell normally after focus is released.
- Enter / Space / accept still equips without casting.
- Focus time is slower than before, making combos less rushed.

## Tuning notes

- `AbilityCaster.focus_quick_cast_lock_duration` controls how fast quick-casts can chain.
- `FocusTime.minimum_time_scale` is now lower for easier testing.
- If quick-casting feels too spammy, increase `focus_quick_cast_lock_duration`.
- If quick-casting feels sluggish, decrease `focus_quick_cast_lock_duration` or raise `minimum_time_scale` slightly.
