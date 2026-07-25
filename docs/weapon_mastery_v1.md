# Weapon Mastery v1

Weapon mastery is persistent progression attached to a weapon class rather than an individual item. Every sword contributes to Sword mastery; replacing a Practice Sword with a better sword preserves the learned forms.

## Classes

Sword, Lance, Axe, Bow, Hammer, Mace, Daggers, Whip, Chains, Gauntlets, Flail, Halberd, Boomerang, Scythe, Staff, and Shuriken share the same progression contract while retaining class-specific upgrades.

## Earning proficiency

Only attacks that connect with at least one payload-capable target award progress.

- Connected attack: 1 point
- Heavy technique: +1 point
- Third or later attack in a combo: +1 point
- Critical result: +1 point

One swing awards once even if it catches several targets. Whiffing never grants progress.

## Ranks

| Rank | Threshold | Purpose |
|---|---:|---|
| Initiate | 0 | Base moveset |
| Familiar | 8 | Improved handling, efficiency, or reach |
| Adept | 22 | Class signature mechanic |
| Master | 45 | Stronger combo finisher identity |

Ranks unlock automatically. There are no mutually exclusive choices in v1.

## Runtime integration

`GameState` owns mastery points, emits progress/rank signals, resets mastery with a new run, and stores the mastery dictionary in save version 10. `WeaponController` resolves mastery when calculating stamina, attack speed, reach, target count, and outgoing payload properties.

The compact Mastery HUD appears when the equipped class gains proficiency or changes rank. It hides automatically so normal exploration remains uncluttered.

## Current class identities

- Sword: flowing deep combos and forceful Heavy finishers.
- Lance: reach, narrow-tip precision, and driving thrusts.
- Axe: committed Heavy cleaves and wider finishers.
- Bow: deliberate Heavy precision and efficient finishers.
- Hammer: armor-breaking stance damage and shattering Heavy finishers.
- Mace: dazing stance pressure and crushing cadence.
- Daggers: fast handling, flurries, and critical openings.
- Whip: reach, tip cracks, and binding finishers.
- Chains: tension force, stance pressure, pulling, and wider orbits.
- Gauntlets: fast pressure strings and body-breaking finishers.
- Flail: stored momentum, knockback, and unbroken circles.
- Halberd: reach, hooking pressure, pulling, and formation sweeps.
- Boomerang: returning rhythm and double-passage tags.
- Scythe: reach, multi-target harvest arcs, and execution criticals.
- Staff: stamina efficiency, resonance, and spellweaving tags.
- Shuriken: fast volleys, combo precision, and marking finishers.

Some identities expose semantic payload tags before their full receivers exist. This is intentional: future binding, pulling, returning-strike, mark, resonance, and spellweave consumers can plug into the existing payload grammar without changing mastery saves.

## Playtest

Equip any existing weapon and strike a valid enemy or training target. The mastery card should appear after each connected attack. Heavy attacks and deep combos should advance it faster. At 8 points, the class becomes Familiar and handling improves. Save at a bed, reload, and verify the points remain.
