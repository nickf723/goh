# Progression Challenge Laboratory v1

Scene:

`res://scenes/levels/prototypes/prototype_progression_challenge_lab_v1.tscn`

## Purpose

This laboratory places every starter progression challenge and its runtime reward in one room. It reuses the real elemental reaction surfaces, alchemy cauldron, creature-knowledge service, Codex challenge tracker, spell modifier registry, and familiar technique loadout.

## Stations

1. **Trial by Flame**
   - Cast Firebolt at the Oil station.
   - Challenge target: Ignite Oil once.
   - Reward: Charged Firebolt.

2. **Live Wire**
   - Apply Water, then Lightning at the Conduct station three times.
   - Reset the station between repetitions with the entry reset console or F8.
   - Reward: Chain Lightning.

3. **Shatterproof**
   - Prepare Frozen at the Freeze station with Water then Ice.
   - At the Shatter station, freeze the target and strike it with a weapon five times across resets.
   - Reward: Piercing Ice Lance.

4. **Kitchen Chemistry**
   - Gather the ingredients surrounding the cauldron.
   - Brew three formulas:
     - Life Bloom + Springwater, Fire treatment.
     - Frost Salt + Springwater, Water treatment.
     - Spark Ore + Springwater, Lightning treatment.
   - Reward: Alchemy Recipe Insight.

5. **Pack Scholar**
   - Record Pack Spacing, Pounce Wind-up, and Recovery Window at the three study terminals.
   - Each record grants three knowledge points, reaching Gremlin rank 3 exactly.
   - Reward: Gremlin Pounce.

## Entry consoles

- **Refill Supplies** restores player resources and stocks alchemy ingredients.
- **Reset Stations** restores surfaces, targets, the cauldron, and ingredient pickups while preserving challenge progress.
- **Clear Progress** clears the five challenge counters, their rewards, potion discoveries, and Gremlin study progress.
- **Complete All** completes all five challenges immediately so their runtime rewards can be tested.

## Keyboard shortcuts

- F1: Trial by Flame
- F2: Live Wire
- F3: Shatterproof
- F4: Kitchen Chemistry
- F5: Pack Scholar
- F8: Reset stations
- F9: Clear progression
- F10: Complete all challenges

Controller users can walk between stations and interact with the four entry consoles.

## Reward checks

After a challenge completes, open **Codex → Challenges** and confirm its runtime status says `ACTIVE`.

- Charged Firebolt: hold and release Firebolt.
- Chain Lightning: cast Lightning Spark into grouped enemies.
- Piercing Ice Lance: line up multiple targets.
- Recipe Insight: select two cauldron ingredients before applying treatment.
- Gremlin Pounce: open Magic → Soul → Summon Familiar → Gremlin → Techniques.

## Automated validation

`res://scenes/tests/progression_challenge_lab_smoke_test.tscn`

Expected output:

`PROGRESSION_CHALLENGE_LAB_SMOKE_TEST: PASS`
