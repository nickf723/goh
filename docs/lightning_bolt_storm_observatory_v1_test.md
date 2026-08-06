# Lightning Bolt and the Storm Observatory v1

## Purpose

Validate two related usability and spell-combat improvements:

1. The permanent ten-slot quick-spell belt now renders the same spell badges and glyphs used by the Focus library.
2. Lightning Bolt introduces delayed, ground-targeted precision damage delivered from the sky.

## Launch

Run:

```text
res://scenes/levels/prototypes/prototype_storm_observatory_spell_trial_v1.tscn
```

The scene equips Lightning Bolt automatically, restores Mana on entry, and regenerates Mana at 2 points per second between casts. Lightning Bolt costs 4 Mana per confirmed strike.

## Quick-spell symbol parity

Open Focus and assign several spells to slots 1–0. The permanent command dock should now show a real `SpellIconFactory` badge in every slot rather than relying on tiny spell-name text.

Confirm:

- Water Jet uses the same `≋` badge in Focus and the quick belt.
- Wave uses the same `≋` badge in both places.
- Lightning Bolt uses `ϟ` in both places.
- the number key remains visible above each badge;
- the currently equipped spell has the gold equipped treatment;
- the quick-slot cursor has the blue highlighted treatment; and
- empty slots retain a subdued placeholder rather than appearing broken.

The top line continues to show the equipped spell's glyph and name, while each individual slot prioritizes symbol recognition.

## Lightning Bolt controls

- Open Focus and choose Lightning Bolt under Lightning.
- Press Cast once to enter ground targeting.
- Move the storm marker with the right stick or normal ground-targeting controls.
- Press Cast again to confirm.
- Cancel backs out without spending Mana.

Mana is spent only when the target is confirmed, not when the marker first appears.

## Spell behavior

Lightning Bolt uses two concentric visual ideas:

```text
Outer storm ring: 1.8 m targeting and future-upgrade envelope
Bright center:     0.78 m direct bolt impact
```

After confirmation, the mark warns for approximately `0.38 seconds`. A bolt then descends from about `15 meters` above the target.

The direct strike currently delivers:

```text
Health damage: 5
Stance damage: 4
Status:        Stunned for 0.6 s
Mana cost:     4
```

Only targets inside the bright center receive the payload. Targets inside the outer ring but outside the bolt are intentionally unaffected in v1. The outer ring is reserved for a later upgrade such as static buildup, chain lightning, conductive exposure, or a weaker peripheral shock.

This gives Lightning two distinct early spells:

```text
Lightning Spark = fast aimed projectile, light damage, quick interruption
Lightning Bolt  = delayed ground mark, high direct damage, prediction and precision
```

## Room I: Still Rod

1. Place the storm marker under the stationary rod.
2. Confirm the target.
3. Observe the warning interval before impact.
4. Confirm no damage occurs during the warning.
5. Confirm the direct bolt defeats the five-health rod and opens the first gate.

This room teaches targeting, confirmation, delayed impact, and the center-strike rule.

## Room II: Moving Relay

The relay moves laterally across the channel.

1. Place the mark where the relay is currently standing and confirm.
2. Confirm the relay can move out before impact, causing the strike to miss.
3. Predict its route and place the mark ahead of it.
4. Confirm the relay enters the center as the bolt lands.
5. Confirm the second gate opens.

This room makes the warning delay a gameplay verb rather than cosmetic hesitation.

## Room III: Center Judgment

A five-health core stands between two twelve-health peripheral sensors. Both sensors are inside the outer 1.8-meter storm ring but outside the 0.78-meter direct strike.

1. Center the marker on the middle core.
2. Confirm the bolt.
3. Confirm the core is struck.
4. Confirm both peripheral sensors retain full health.
5. Confirm the final gate opens.

A direct hit on a peripheral sensor can still damage it. The test is about accurate center placement, not invulnerable scenery.

## Mastery

Cross the final gate and enter the gold mastery seal. Completion records:

```text
storm_observatory_spell_trial_complete
```

The mastery summary is:

```text
MARK • LEAD • STRIKE
```

## Reset behavior

F8 restores:

- Grace's position, velocity, full Mana, and Lightning Bolt selection;
- all five training targets and their statuses;
- the moving relay's route and phase;
- all three gates;
- every active Lightning Bolt strike and targeting marker;
- stage counters;
- the mastery flag; and
- the trial objective.

## Automated regression

Run:

```text
godot --headless --path . res://scenes/tests/lightning_bolt_storm_observatory_smoke_test.tscn
```

The regression covers:

- Lightning Bolt presence in Grace's spell library;
- four-Mana confirmed-cast cost;
- ground-targeting registration;
- no Mana cost while merely placing the marker;
- delayed impact with no early damage;
- high direct health and stance payload values;
- creation of the sky-strike action scene;
- direct-center damage;
- no v1 peripheral effect inside the outer ring;
- moving-target misses and predictive hits;
- trial progression and reset;
- ten real quick-slot icon badges; and
- exact Focus-to-quick-belt glyph parity.

## Known limitations

- The bolt is a procedural vertical lightning column and branch stack rather than final authored particles, branching geometry, screen flash, thunder audio, haptics, and camera response.
- Open-sky validation is not yet required. The spell can currently target stable ground beneath overhangs.
- The outer ring has no gameplay effect in v1 by design.
- The trial uses development training totems and compressed prototype architecture.
- Final damage balance, elemental scaling, aim assist, enemy prediction, accessibility timing, and upgrade behavior remain tunable.
