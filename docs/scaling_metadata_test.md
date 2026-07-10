# Scaling Metadata Test

## Goal

Add build identity metadata without adding damage formulas yet.

This pass answers:

```text
What stats does this spell or weapon care about?
```

It does **not** answer yet:

```text
How much damage does that stat add?
```

## What changed

### AbilityDefinition

Adds pure metadata fields:

```gdscript
@export var scaling_stats: Array[String] = []
@export_multiline var scaling_note: String = ""
```

Adds helpers:

```gdscript
get_scaling_stats()
get_default_scaling_stats()
get_scaling_note()
```

If a spell does not explicitly set `scaling_stats`, it gets a prototype default from its element.

Examples:

| Element | Default scaling identity |
|---|---|
| Fire | Arcana / Fire |
| Earth | Power / Earth |
| Metal | Dexterity / Metal |
| Dreams | Intelligence / Dreams |
| Body | Power / Body |
| Space | Focus / Space |
| Time | Focus / Time |

### WeaponDefinition

Adds pure metadata fields:

```gdscript
@export var scaling_stats: Array[String] = ["power", "dexterity"]
@export_multiline var scaling_note: String = "Prototype weapon scaling identity only. Damage formulas are not active yet."
```

Practice Sword therefore displays as:

```text
Scaling: Power / Dexterity
```

### Full menu

The Loadout tab now shows scaling for:

- Spell cards
- Weapon card

## Test branch

```text
agent/scaling-metadata-v1
```

## Parser checks

Open Godot and confirm no parser errors from:

- `scripts/abilities/ability_definition.gd`
- `scripts/weapons/weapon_definition.gd`
- `scripts/ui/full_menu_director.gd`
- `scripts/ui/full_menu_shell.gd`

## Menu checks

1. Run the usual dev scene.
2. Open the full menu with `Tab` or `M`.
3. Open `Loadout`.
4. Confirm spell cards now show a line like:

```text
Scaling: arcana / fire
```

5. Confirm the weapon card shows:

```text
Scaling: power / dexterity
```

6. Switch tabs with `1-5` and confirm nothing broke.
7. Close the menu and confirm gameplay resumes.

## Spell examples to spot-check

| Spell | Expected scaling identity |
|---|---|
| Firebolt | Arcana / Fire |
| Earth Spike | Power / Earth |
| Metal Needle | Dexterity / Metal |
| Body Burst | Power / Body |
| Dream Snare | Intelligence / Dreams |
| Time Snare | Focus / Time |
| Space Blink | Focus / Space |

## Gameplay regression checks

- Cast Firebolt.
- Cast Water Jet.
- Cast Earth Spike.
- Swing Practice Sword.
- Confirm damage behavior feels unchanged.

## Design notes

This is intentionally build metadata, not balance math.

Later passes can add actual formula hooks, such as:

```text
final_damage = base_damage + arcana_bonus + fire_bonus
cast_startup = base_startup - dexterity_bonus
menu_slow = focus curve
proc_chance = luck/skill curve
```

For now, this is a visible compass for future spell, weapon, augment, and equipment design.
