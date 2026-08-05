# Animated Armor: Prismatic Judgment v1

## Player-facing goal

The Animated Armor should now feel like the adaptive climax of the Church Trial rather than a two-attack pursuer. Grace breaks its stance, attacks the exposed core, and then adapts as the repaired shell changes elemental judgment.

The complete story route remains:

```text
combat → Chamber of Accord → Sound passage → Armor Trial bed
→ Prismatic Judgment → Church Trial Sigil → exit
```

## Fast test scene

Launch:

```text
res://scenes/levels/prototypes/prototype_church_trial_boss_finale_v1.tscn
```

This dedicated finale is a development laboratory. It refills Mana on entry and regenerates Mana continuously at 18 points per second. Stamina and Focus keep their ordinary rules. The integrated Church Trial does not receive this laboratory regeneration.

## Core combat loop

The armor begins in Neutral Judgment.

1. Damage its stance while the shell is intact.
2. When stance reaches zero, confirm the armor stops attacking and collapses into a readable exposed-core posture.
3. Confirm the shell aura gives way to a bright gold-violet core state.
4. Land a weapon melee attack before the critical window ends.
5. Confirm the critical strike deals amplified health damage.
6. Confirm the armor repairs its stance and changes to the next colored judgment.

The authored order is:

```text
Neutral → Scarlet → Azure → Indigo → Scarlet → ...
```

Spells may damage the exposed core, but a valid weapon-melee critical consumes the opening and immediately reforms the shell.

## Neutral Judgment

Neutral preserves the original teaching attacks:

- close judgment-hammer slam;
- violet radial pulse;
- Fire and Lightning weakness;
- Poison and Dreams resistance.

The first stance break awakens the colored cycle.

## Scarlet Judgment

Readability:

- scarlet core, eyes, hammer rune, aura, and attack markers;
- faster pursuit;
- heated overhead hammer pose;
- long rectangular fault line projected in front of the boss.

Behavior:

- the Scarlet Fissure damages only the marked forward lane;
- a lateral dodge should escape it;
- Water and Ice are effective against the shell;
- Fire and Poison are resisted.

## Azure Judgment

Readability:

- azure core and aura;
- slower, more deliberate spacing;
- open-arm windup;
- broad expanding floor wave.

Behavior:

- the Azure Wave covers a wide forward arc;
- a readable opening remains behind the armor;
- a hit uses the shared player-defense route and pushes Grace backward;
- Lightning and Ice are effective;
- Water and Fire are resisted.

## Indigo Judgment

Readability:

- indigo core and rapidly rotating rings;
- more cautious ranged movement;
- a circular rune locks onto Grace's current ground position.

Behavior:

- the rune stops following after the windup begins;
- leaving the marked circle avoids the strike;
- remaining inside receives Lightning damage;
- Earth and Metal are effective;
- Lightning and Sound are resisted.

## Final phase

Below 35 percent health, confirm:

- attack windups become shorter;
- recovery and cooldown become shorter;
- movement accelerates;
- every third signature opportunity may reuse the previous judgment's attack;
- all attack markers remain readable despite the faster cadence.

This phase combines learned attacks rather than adding an unexplained new move.

## Guard and dodge regression

The boss now sends `DamagePayload` objects through `PlayerDefenseController` rather than damaging `GameState` directly.

Test each attack with:

- no defense;
- ordinary Guard;
- Perfect Guard;
- dodge invulnerability;
- movement out of the telegraphed shape.

Confirm damage, stance damage, Guard costs, hit reactions, and Perfect Guard retaliation agree with the existing defense framework.

## Mana regeneration regression

In the dedicated finale scene:

1. Spend Mana repeatedly.
2. Confirm Mana begins returning without touching the bed or shrine.
3. Confirm the bar does not exceed maximum Mana.
4. Confirm no invisible regeneration credit accumulates while full.
5. Confirm Stamina and Focus are not refilled by this laboratory node.

Then launch the integrated Church Trial:

```text
res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn
```

Spend Mana and confirm the story dungeon retains its normal resource rules.

## Defeat and progression

1. Defeat the armor from any judgment.
2. Confirm collision disables immediately.
3. Confirm the prismatic core and procedural armor perform the existing collapse presentation.
4. Confirm the Judgment Gate unlocks once.
5. Confirm the `HitReceiver` awards the final Mana reward once.
6. Claim the Church Trial Sigil.
7. Confirm the final exit still requires the sigil.

## Automated regression

Run:

```text
godot --headless --path . res://scenes/tests/animated_armor_prismatic_smoke_test.tscn
```

The regression covers:

- stance-then-health configuration;
- neutral and colored weakness profiles;
- stance break and exposed-core presentation;
- amplified weapon critical damage;
- Scarlet, Azure, and Indigo cycle order;
- signature attack selection;
- line, arc, and delayed-target geometry;
- payload delivery through player defense;
- Azure push reaction;
- final-phase timing and movement changes;
- boss-gate unlock on defeat;
- explicit mana-only regeneration in the finale lab;
- reuse by the shared lab installer; and
- isolation from the production Church Trial.

## Known limitations

- Attack collision remains deterministic geometric gameplay logic rather than authored animation hit volumes.
- Visuals remain transform-driven procedural assets rather than a rigged production model.
- The first pass uses three colored judgments rather than all sixteen elements.
- Final audio, particles, camera treatment, balance tuning, and accessibility-specific telegraph alternatives remain future polish.
