# Grow and Shrink v1

Grow and Shrink are mutually exclusive Body transformations. They persist until Grace casts the active form again, casts the opposite form, rests, is defeated, or a trial resets her.

## Shared form rules

```text
Grow active + cast Grow     → return to normal
Shrink active + cast Shrink → return to normal
Grow active + cast Shrink   → replace Grow with Shrink
Shrink active + cast Grow   → replace Shrink with Grow
```

Entering a new transformed form costs Mana. Returning to normal refunds the repeated form's cost, so ending a transformation is free.

Expansion is clearance checked. Grow, or a return from Shrink to normal size, is rejected when the larger capsule overlaps architecture. Rejected casts refund their Mana and preserve the current valid form.

Only one body form is active at a time. F7 therefore reports at most one Body transformation:

```text
Transformed:
SPELL FX     +1
PERSISTENT   +1

Normal:
Both return to baseline
```

## Grow

```text
Mana cost:             3
Visual/collision scale: 1.55×
Mechanism mass:        150 kg
Movement speed:        78%
Attack speed:          80%
Weapon damage:         150%
Weapon stance damage:  160%
Weapon knockback:      145%
Weapon reach:          120%
Stance damage received: 65%
Guard stamina cost:    80%
```

Grow changes both presentation and physics. Grace's capsule, visible model, weapon presentation, cast origin, camera framing, interaction range, floor snap, airflow mass, and mechanism mass all update together.

The increased mass allows Grace to operate weighted mechanisms that reject her ordinary 70 kg body. The larger collision is real, so Grow may prevent her from entering a low or narrow route.

Grow also receives a heavier dodge profile:

```text
Distance: 78%
Duration: 110%
Cooldown: 115%
Steering: reduced
Maximum chain: one fewer, minimum one
```

## Shrink

```text
Mana cost:              2
Visual/collision scale: 0.58×
Mechanism mass:         24 kg
Movement speed:         135%
Attack speed:           125%
Weapon damage:          72%
Weapon stance damage:   72%
Weapon knockback:       65%
Weapon reach:           82%
Stance damage received: 125%
Stamina recovery:       125%
```

Shrink is a traversal and agility form. Grace's smaller physical capsule fits beneath low ceilings and through narrow passages. Her lower mass also changes pressure-plate behavior and how strongly airflow can move her.

Shrink receives a nimble dodge profile:

```text
Distance: 125%
Duration: 78%
Cooldown: 68%
Steering: stronger and faster
Maximum chain: one additional dodge
```

## Weapon integration

The safe weapon controller resolves body-form channels at attack time. This keeps every weapon class compatible without mutating shared weapon resources.

Grow increases health damage, stance pressure, knockback, reach, and overall attack duration through the lower attack-speed channel. Shrink does the reverse, creating a fast but light attack rhythm.

Payloads receive a `body_form_grown` or `body_form_shrunk` tag, leaving a clean hook for future reactions, techniques, enemy responses, and form-specific upgrades.

## Haptics and presentation

Grow uses a rising heavy three-beat controller pattern. Shrink uses two quick, light pulses. Returning to normal uses one centered pulse.

The transformed form keeps a small animated Body aura active. The aura, collision, camera, and gameplay values update immediately, while the visible body scales through a short transition.

## Hall of Measure

Launch:

```text
res://scenes/levels/prototypes/prototype_body_forms_spell_trial_v1.tscn
```

The trial equips Grow on entry and regenerates 2 Mana per second.

### I. The Heavy Answer

The first pressure plate requires 120 kg.

```text
Normal Grace: 70 kg  → gate remains closed
Shrink:       24 kg  → gate remains closed
Grow:        150 kg  → gate opens
```

The plate is refreshed whenever body-form mass changes, including when Grace transforms while already standing on it.

### II. The Narrow Answer

The next passage has an underside around 1.28 meters above the floor.

```text
Normal collision height: about 1.92 m → cannot enter
Grow collision height:   about 2.98 m → cannot enter
Shrink collision height: about 1.11 m → fits
```

The finish checks the actual collision height and active form. Merely reaching the trigger through an unrelated movement trick does not complete the room.

### Mastery

Enter the gold seal:

```text
MASS • SCALE • ADAPT
```

Completion records:

```text
hall_of_measure_body_forms_trial_complete
```

F8 restores normal size, Grace's starting transform, resources, both gates, the pressure plate, stage state, Grow selection, and the temporary mastery flag.

## Reliable spell-trial gates

The Hall of Measure and repaired Rime Rink use the same reliability rule:

```text
Signals provide immediate response
        +
A bounded 0.08-second state retry verifies the completed physical result
```

The Rime Rink now retries all three doors:

- the curling gate accepts a valid right-curled route with sufficient span and either two nearby marks or a clear lateral bend;
- the frozen crossing checks Grace's far-shore position and a fresh water-supported route instead of relying on one `body_entered` frame;
- the momentum gate rechecks plate mass, a fresh Boulder, and a fresh ground-ice runway together, covering metadata that arrives one physics frame after the plate signal.

Every successful opening also verifies the gate's mechanism state and immediately disables blocking collision.

## Focused playtest

1. Open Body in Focus and confirm Grow uses `⇧+` and Shrink uses `⇩-`.
2. Cast Grow and inspect the larger model, capsule, camera framing, weapon reach, slower movement, and heavier attacks.
3. Stand on the Hall's 120 kg plate while normal, then cast Grow without leaving it. The first gate should open.
4. Cast Shrink and compare movement, attack cadence, dodge distance, dodge duration, and chaining.
5. Enter the low passage and confirm normal and Grow cannot fit while Shrink can.
6. Try to return to normal beneath the low roof. The cast should be rejected, the form should remain Shrunk, and Mana should be refunded.
7. Leave the roof and cast Shrink again. Grace should return to normal for free.
8. Switch directly from Grow to Shrink and confirm only one persistent effect remains.
9. Complete the gold seal, press F8, and confirm normal size and both closed doors are restored.
10. Revisit the Rime Rink and complete each room. All three doors should open and stop blocking Grace without requiring a second attempt.
