# Ruined Village Field Progression v1

Scene:

`res://scenes/levels/prototypes/prototype_ruined_village_field_progression_v1.tscn`

## Purpose

This is the first field route designed to make the progression systems operate together during ordinary play rather than inside isolated laboratories.

The route layers new progression content over the existing Ruined Village approach while preserving its original traversal, square encounter, environmental clues, ravine solutions, checkpoint, and Church Trial entrance.

## Route

### 1. Herbalist garden

- Read the Weathered Herbalist Ledger.
- The Story Quest advances toward the flooded square.
- The Side Quest `The Herbalist's Satchel` begins.
- Study Moonveil Fern for a new Flora record.
- Gather Life Bloom, Echo Reed, and Springwater.

### 2. Flooded village square

- The original Goblin and Gremlin ambush remains intact.
- Three Water patches align with the encounter formation.
- One Oil patch offers an alternate Fire opportunity.
- A Gremlin study terminal records pack spacing.
- Combat may advance weapon mastery, creature knowledge, reaction discovery, Codex challenges, experience, and loot at once.

### 3. Ravine fork

The existing three-route structure remains the progression puzzle:

- Fire clears the root-choked debris.
- Ice followed by Force shatters the debris.
- Water followed by Ice creates the alternate frozen bridge.

All routes reach the far landing.

### 4. Herbalist satchel

The satchel rests on the eastern side of the far landing.

Recovering it:

- completes the Side Quest
- grants Life Bloom ×2
- grants Echo Reed ×2
- adds a Field Note discovery

### 5. Travel alchemy

The western landing contains a travel cauldron with Fire, Water, and Lightning treatments.

Three field formulas are displayed:

- Life Bloom + Springwater, Fire treatment
- Frost Salt + Springwater, Water treatment
- Spark Ore + Springwater, Lightning treatment

Brewing on the road completes the optional side objective and feeds the real recipe-discovery challenge.

### 6. Church-road showcase

Four enemies stand in a tight formation across several Water patches.

The arena gives recently unlocked mechanics an immediate stage, especially:

- Chain Lightning
- Piercing Ice Lance
- Charged Firebolt
- familiar techniques
- reaction-driven area effects

Completing the encounter finishes the Story Quest and records the route in Journal Field Notes.

## Progression summary

The route captures a session baseline after initialization. At completion it summarizes advances made during that playthrough, including:

- Codex challenge tracks advanced
- reaction and recipe discoveries
- weapon mastery gained
- Gremlin knowledge ranks gained
- satchel recovery
- field brewing

The summary is session-scoped. Persistent progression remains stored through the normal save systems.

## Menu and HUD integration

- The Story Quest is pinned automatically only when no other progression record is already tracked.
- Story, Side Quest, Challenge, and discovery notifications use the persistent progression feedback HUD.
- The full menu hides the field feedback layer and restores it on close.

## Manual test route

1. Launch `Ruined Village Field Progression` from the Development Control Center.
2. Read the herbalist ledger.
3. Inspect Moonveil Fern and gather the nearby ingredients.
4. Open Codex and confirm both Story and Side Quests exist.
5. Enter the square and experiment with Water, Lightning, Oil, Fire, weapons, and Gremlin study.
6. Cross the ravine through any existing route.
7. Recover the satchel.
8. Brew at least one potion at the travel cauldron.
9. Continue to the church road.
10. Test newly unlocked mechanics against the clustered formation.
11. Confirm the completion summary, completed Story Quest, completed Side Quest, and Journal Field Note.
12. Save at the church-ground bed and verify the route restores correctly after reload.

## Automated validation

`res://scenes/tests/ruined_village_field_progression_smoke_test.tscn`

Expected:

`RUINED_VILLAGE_FIELD_PROGRESSION_SMOKE_TEST: PASS`
