# Wave and the Tidal Causeway v1

## Purpose

Validate a broad Water control spell that displaces enemies, living mobs, and movable objects without dealing health or stance damage.

Wave and Water Jet occupy different roles:

```text
Water Jet = narrow projectile, single-target Wet setup, minor stance pressure
Wave      = broad moving front, zero damage, mass-aware displacement
```

## Launch

Run:

```text
res://scenes/levels/prototypes/prototype_tidal_causeway_spell_trial_v1.tscn
```

The scene equips Wave automatically, restores Mana on entry, and regenerates Mana at 1.5 points per second between casts. Wave costs 2 Mana per cast.

## Controls

- Move and camera: normal controls
- Focus spell library: normal Focus input
- Cast Wave: Cast
- Reset the complete trial: F8 / RESET

## Spell behavior

Wave creates a widening water front that travels roughly 9 meters from Grace. The front:

- pushes each valid target only once;
- can catch multiple targets across its width;
- stops at solid walls and closed gates;
- pushes ordinary enemies through `ForceReceiver`;
- pushes field-responsive props with mass-sensitive strength;
- applies a direct physics impulse to `RigidBody3D` props;
- pushes living `CharacterBody3D` mobs without requiring a combat receiver;
- applies Wet through the normal Water payload path when a target supports statuses;
- deals zero health damage; and
- deals zero stance damage.

Light field-responsive objects receive a larger velocity change than heavy ones. Bosses retain a strong push-resistance multiplier rather than becoming fully immune by default.

## Room I: Cargo Run

A 3 kg cargo block and an 18 kg anchor begin abreast in the first channel.

1. Stand behind both objects and cast Wave.
2. Confirm the broad front contacts both in one cast.
3. Confirm the 3 kg cargo travels faster and farther than the 18 kg anchor.
4. Continue pushing the cargo into the illuminated Cargo Basin.
5. Confirm the first gate opens only for the designated cargo; the anchor cannot complete the room.

This room proves broad contact, object force, and mass-sensitive displacement.

## Room II: Gentle Current

A capybara wanders near the center of the second channel.

1. Approach from behind and cast Wave.
2. Confirm the capybara is physically displaced without a damage response.
3. Use several gentle casts to guide it into the Sanctuary Pool.
4. Confirm the second gate opens.

This room proves that non-combat mobs can participate in force spells without needing enemy health or damage components.

## Room III: Break the Line

A harmless Goblin waits in the final current lane. Its attack resource and player target are disabled for this trial.

1. Note the Goblin's health before casting.
2. Cast Wave and confirm it is pushed down the lane.
3. Confirm its health and stance remain unchanged.
4. Confirm Wet may appear through the standard status system.
5. Push the Goblin into the Containment Basin.
6. Confirm the final gate opens without defeating the enemy.

This room proves that Wave is control rather than disguised damage.

## Mastery landing

Cross the final gate and enter the gold basin. Completion records:

```text
tidal_causeway_spell_trial_complete
```

The mastery summary is:

```text
MOVE • GUIDE • DISPLACE
```

## Reset behavior

F8 restores:

- Grace's position and full Mana;
- the light cargo and heavy anchor transforms and forces;
- the capybara's initial position, velocity, drives, and behavior memory;
- the Goblin's transform, velocity, health, stance, statuses, and force state;
- all three gates;
- trial stage counters;
- the completion flag; and
- any active Water Wave effects.

## Automated regression

Run:

```text
godot --headless --path . res://scenes/tests/water_wave_tidal_causeway_smoke_test.tscn
```

The regression covers:

- Wave presence in Grace's spell library;
- two-Mana cast cost;
- expanding-wave delivery identity;
- zero health and stance damage payloads;
- Wet setup identity;
- action-scene creation through `AbilityCaster`;
- broad contact with two objects;
- lighter cargo moving faster than the heavy anchor;
- direct CharacterBody mob displacement;
- enemy ForceReceiver displacement;
- unchanged enemy health and stance;
- Wet application;
- correct cargo, mob, enemy, and mastery progression; and
- complete reset behavior.

## Known limitations

- The current wave is a procedural water wall rather than a final particle, foam, refraction, spray, audio, and haptic stack.
- Ground travel assumes ordinary world-up gravity.
- The central travel ray stops the wave at walls, while the broad visual does not yet curl around corners or split around obstacles.
- CharacterBody mobs without ForceReceiver use their existing velocity smoothing to recover from the shove.
- Wave does not yet move fluid volumes, extinguish large fires by volume, create currents, or interact with ropes and cloth.
