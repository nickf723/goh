# Wind Well and the Hollow Spire v1

## Purpose

Validate a persistent Air spell that creates vertical airflow without dealing health or stance damage.

Wind Gust and Wind Well occupy different roles:

```text
Wind Gust = immediate horizontal shove
Wind Well = persistent vertical lift field
```

## Launch

Run:

```text
res://scenes/levels/prototypes/prototype_hollow_spire_spell_trial_v1.tscn
```

The scene equips Wind Well automatically, restores Mana on entry, and regenerates Mana at 2 points per second between casts. Wind Well costs 3 Mana and lasts approximately 6 seconds.

## Controls

- Move and camera: normal controls
- Focus spell library: normal Focus input
- Begin Wind Well targeting: Cast
- Move the circular marker: right stick or camera controls
- Confirm Wind Well: Cast again
- Cancel targeting: Cancel
- Reset the complete trial: F8 / RESET

## Spell behavior

Wind Well creates a bottom-anchored cylinder of rising air. The field:

- begins at the selected ground surface rather than fading out at its base;
- persists for approximately six seconds;
- fades near its radial edge and upper lip;
- lifts Grace while preserving aerial steering;
- lifts ordinary CharacterBody enemies and mobs without damage;
- applies mass-sensitive airflow to field-responsive objects;
- applies physical force to ordinary RigidBody3D props;
- registers with the shared AirflowManager so projectiles, gas, clouds, and other airflow-aware systems can sample the same field;
- deals zero health damage;
- deals zero stance damage; and
- suppresses reaction payloads entirely.

The Wind Well glyph is `↑`, while Wind Gust retains `↝`, so both Air spells remain distinguishable in Focus and the quick-spell belt.

## Room I: Feather and Stone

A 2 kg Featherstone and an 18 kg anchor begin together on the lower floor.

1. Place Wind Well beneath the two stones.
2. Confirm both are inside the visible updraft.
3. The Featherstone should rise decisively.
4. The anchor may tremble or become slightly lighter, but it should remain grounded.
5. Guide the Featherstone into the elevated catch.
6. Confirm the first gate opens only for the designated Featherstone.

This room proves that the same airflow field can produce different results through mass rather than spell-specific target rules.

## Room II: Ride the Current

A solid wall blocks the path to an elevated landing.

1. Place Wind Well on the circular Air channel before the wall.
2. Enter the current.
3. Confirm Grace rises without taking damage or entering a spell-channel lock.
4. Use ordinary movement input to steer while airborne.
5. Rise above the wall and move forward onto the upper landing.
6. Enter the gold mastery seal.

Completion records:

```text
hollow_spire_spell_trial_complete
```

The mastery summary is:

```text
PLACE • ENTER • STEER
```

## Reset behavior

F8 restores:

- Grace's starting transform, velocity, full Mana, and Wind Well selection;
- the Featherstone and anchor transforms, velocity, and force state;
- the first gate;
- the trial stage and goal counters;
- the completion flag;
- active ground-targeting state; and
- every active Wind Well field.

## Automated regression

Run:

```text
godot --headless --path . res://scenes/tests/wind_well_hollow_spire_smoke_test.tscn
```

The regression covers:

- Wind Well presence in Grace's spell library;
- three-Mana confirmed-cast cost;
- no Mana cost while positioning the marker;
- ground-target registration and action-scene creation;
- shared AirflowManager registration;
- zero health and stance damage;
- reaction suppression;
- distinct Wind Gust and Wind Well glyphs;
- a ground-level field base;
- upper field cutoff;
- light-versus-heavy airflow acceleration;
- direct Grace and combat-target lift;
- field duration and cleanup;
- Featherstone gate progression;
- upper-landing mastery; and
- complete reset behavior.

## Known limitations

- The visual field is a procedural ring-and-wisp stack rather than final particles, cloth response, refractive distortion, audio, and controller haptics.
- Direct CharacterBody lift is applied by the Wind Well action so actors without AirflowResponse can participate. Airflow-aware objects continue to use the shared vector-field simulation.
- The first trial contains Feather and Stone plus Ride the Current. Gas venting, projectile bending, airborne enemy vulnerability, and multi-spell chime puzzles remain future expansions.
- Bosses receive strong lift resistance rather than full immunity by default.
