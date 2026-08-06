# Ice Lance and the Rime Armory v2

## Purpose

Replace the original generic ice projectile with a spell that behaves like a conjured lance.

```text
Old Ice Lance = small ice projectile with Chill
New Ice Lance = long physical spear that pierces, drives, and embeds
```

## Launch

Run:

```text
res://scenes/levels/prototypes/prototype_rime_armory_spell_trial_v1.tscn
```

The development trial equips Ice Lance automatically, restores Mana on entry, and regenerates Mana at 2 points per second between casts.

## Spell identity

Ice Lance now costs 2 Mana and creates a dedicated `IceLanceProjectile` rather than the shared generic projectile.

The base lance:

- forms as a 3.8-meter crystalline spear;
- travels at approximately 23 meters per second;
- pierces up to three unique payload targets in one line;
- loses some health and stance force after every pierced body;
- begins at 3 health damage and 5 stance damage;
- applies Chill;
- carries the `force` tag, allowing it to shatter an already Frozen target through the shared reaction engine;
- drives struck actors away from Grace;
- reacts to shared airflow, but less strongly than a light magical bolt;
- stops on hard architecture;
- embeds in static or animated surfaces for approximately eight seconds; and
- enables a temporary collision body while embedded, allowing the spear to serve as a narrow ledge, bridge, barrier, or projectile blocker.

The lance then shatters and removes its temporary geometry.

The existing `piercing_ice_lance` progression upgrade remains compatible. Its modified payload raises the runtime pierce limit, speed, stance pressure, and Chill duration beyond the base spell.

## Room I: The Long Point

Three fragile marks stand in one straight line.

1. Equip Ice Lance.
2. Align Grace, the three marks, and the center of the camera.
3. Cast once.
4. Confirm the complete spear appears rather than a small orb.
5. Confirm the first mark is struck.
6. Confirm the same lance continues through the second and third marks.
7. Confirm later hits are slightly weaker but still real.
8. Confirm the first gate opens only after all three marks are pierced.

The room establishes that line geometry is part of the spell. Ice Lance rewards positioning before the cast rather than smart-targeting enemies after launch.

## Room II: The Lodged Edge

A glowing Rime Anchor waits in the second chamber.

1. Aim at the center of the anchor.
2. Cast Ice Lance.
3. Confirm the lance stops at the hard surface.
4. Confirm it remains visibly embedded instead of disappearing on impact.
5. Walk into or onto the shaft and confirm it has solid collision.
6. Confirm the mastery gate opens only when the lance is embedded in the authored anchor surface.
7. Wait and confirm the embedded lance eventually fades, shatters, and removes its collision.

Although the trial uses one designated anchor to verify progression, the runtime lance can embed in ordinary static architecture unless a surface explicitly rejects lodging.

## Mastery

Enter the gold seal after the anchor gate opens.

Completion records:

```text
rime_armory_spell_trial_complete
```

The mastery summary is:

```text
PIERCE • EMBED • ENDURE
```

## Reset behavior

F8 restores:

- Grace's starting transform, velocity, full Mana, and Ice Lance selection;
- all three line targets;
- both gates;
- the trial stage and objective;
- the completion flag; and
- every flying or embedded Ice Lance, including its temporary collision.

## Automated regression

Run:

```text
godot --headless --path . res://scenes/tests/ice_lance_rime_armory_smoke_test.tscn
```

The regression covers:

- dedicated ability-scene integration;
- two-Mana casting cost;
- physical-lance delivery metadata;
- force, Chill, stance, and damage identity;
- decreasing payload force along the line;
- shared AbilityCaster creation of `IceLanceProjectile`;
- one cast piercing three aligned targets;
- unique-target filtering;
- gate progression;
- hard-surface lodging;
- temporary collision geometry;
- finite embedded lifetime;
- mastery persistence; and
- full reset behavior.

## Known limitations

- The lance uses procedural crystal geometry rather than final authored mesh, particles, audio, camera shake, and controller haptics.
- Travel collision currently uses a fast centerline sweep. The long visual is intentionally forgiving through the trial's aligned targets, but a future shape sweep can give the spear its exact physical thickness.
- Embedded lances do not yet inherit motion from a moving surface.
- Fire-driven melting, weapon-driven shattering, stacked-lance limits, and authored climbing affordances are future upgrades.
- The base spell pierces three targets, so the older `Piercing Ice Lance` upgrade now extends an existing identity rather than introducing piercing from zero.
