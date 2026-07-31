# Creature Mastery and Familiar Training Yard v1

## Purpose

Creature Mastery connects field study, species records, familiar loadouts, summoning, friendly group AI, and future transformation forms.

Training scene:

```text
res://scenes/levels/prototypes/prototype_familiar_training_yard_v1.tscn
```

## Live observation loop

Gremlin knowledge now comes from events Grace actually experiences:

1. See a Gremlin within observation range: **First Encounter**, +1
2. Witness Backstep enter its active movement: **Witnessed Backstep**, +1
3. Remain alive after a Gremlin Pounce resolves against Grace: **Survived Pounce**, +1
4. Witness a two-or-more-member Gremlin squad create a tactical reservation or intent: **Pack Coordination**, +2
5. trigger Wet Conduction on a Gremlin: **Conduct Susceptibility**, +4
6. Defeat the final living member of a previously observed Gremlin pack: **Defeated Wild Pack**, +1
7. Study scavenging habitat through authored world evidence: **Scavenging Habitat**, +1
8. Form a stable familiar bond by summoning successfully: **Stable Familiar Bond**, +4

Every discovery is unique. Repeating Backstep, Conduct, or another known event does not award more knowledge.

The study plinths remain in the south archive as duplicate-safe developer shortcuts. They are no longer required for the first six combat discoveries.

## Unlock rhythm

Gremlin rank thresholds are 0, 2, 5, 9, and 14 knowledge.

- Two points unlock the Gremlin Familiar.
- Five points unlock Pounce.
- Nine points unlock Mire Spit.
- Fourteen points unlock the future Gremlin Transformation form.

A natural Training Yard route can unlock the familiar by seeing the pack and surviving or studying one additional behavior. Conduct provides a large reward because it demonstrates knowledge of both the creature and the elemental sandbox.

## Familiar loadout

Open the full menu and select the Magic tab. Familiar Blueprints appear after spellcasting mastery.

The Gremlin blueprint supports:

- Roles: Skirmisher or Primer
- Temperaments: Cautious, Balanced, or Bold
- Opening commands: Rally, Focus, Assist, or Hold
- Up to three equipped techniques
- Bite
- Backstep
- Pounce
- Mire Spit

The summon spell creates the prepared blueprint immediately. Casting the summon spell while a familiar is active dismisses it; the following cast resolves the latest equipped blueprint.

## Shared creature abilities

Wild Gremlins and Gremlin familiars share the existing EnemyActionOption and EnemyCombatActionDefinition resources. The familiar driver interprets those resources for friendly control. A future transformation driver can consume the same creature ability catalog.

Gremlin Pounce now has the stable action ID `gremlin_pounce`. Backstep already uses `gremlin_backstep`. Stable IDs are used by field observations, telemetry, replay, familiar configuration, and future transformation input maps.

## Observation architecture

The observation service is created lazily under the scene tree root when the first observable creature enters a scene.

Combat systems publish neutral events:

- creature identity and defeat from EnemyActor
- action lifecycle events from the observation-aware Gremlin brain
- squad-reservation events from tactical decisions
- reaction IDs from the Gremlin payload receiver

The observation rule catalog converts matching events into SpeciesKnowledge discoveries. Combat code does not decide progression rewards.

## Friendly group AI

Assist mode uses the shared target-allocation blackboard under the `grace_familiars` squad. The familiar:

- evaluates hostile targets
- avoids crowded or overkilled targets
- uses role-aware target scoring
- claims attention, melee pressure, damage, or setup
- uses Mire Spit as a Wet setup when configured as Primer
- respects Grace's lock-on target in Focus mode

## Training Yard layout

- South archive: six duplicate-safe study terminals
- Center: durable training dummies
- North pen: two live wild Gremlins
- East ring: familiar deployment area
- West gate: reserved transformation prototype area
- Violet console: combat reset without erasing creature knowledge

## Manual live-observation test

1. Reset Gremlin mastery using a debug route or a fresh save.
2. Enter the Training Yard and face the north pen. First Encounter should record automatically.
3. Fight without using the study plinths.
4. Let the Pouncer complete Pounce while Grace remains alive.
5. Watch either Gremlin perform Backstep.
6. Allow the pair to begin coordinated combat. Pack Coordination should record from a real tactical reservation.
7. Apply Wet to a Gremlin, then Lightning. Conduct Susceptibility should record.
8. Defeat one Gremlin. Defeated Wild Pack must remain unrecorded.
9. Defeat the final Gremlin. Defeated Wild Pack should record once.
10. Repeat any known event. Knowledge points must not increase.

New discoveries display a field-insight message and update SpeciesKnowledge immediately.

## Controls

- Standard movement, combat, spells, Focus, and summon controls
- Tab or M: open full menu
- Magic tab: configure Familiar Blueprint
- Interact: study terminals or reset console
- F8 in editor: reset combat while preserving mastery

## Automated tests

```powershell
$godot = "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe"

& $godot --headless --path . res://scenes/tests/species_knowledge_smoke_test.tscn
& $godot --headless --path . res://scenes/tests/creature_mastery_familiar_smoke_test.tscn
& $godot --headless --path . res://scenes/tests/familiar_polish_smoke_test.tscn
& $godot --headless --path . res://scenes/tests/creature_observation_smoke_test.tscn
```

Expected:

```text
SPECIES KNOWLEDGE SMOKE TEST PASSED
CREATURE_MASTERY_FAMILIAR_SMOKE_TEST: PASS
FAMILIAR_POLISH_SMOKE_TEST: PASS
CREATURE_OBSERVATION_SMOKE_TEST: PASS
```

## Known limitations

- Presence capacity is one in v1, although definitions already expose presence cost and maximum active count.
- Only Gremlin has a complete creature familiar and live observation implementation.
- Study terminals remain authored debug shortcuts rather than world-integrated evidence objects.
- Familiar navigation uses direct CharacterBody movement rather than NavigationAgent pathfinding.
- Transformation support is represented in the shared definition and ability catalog, but player possession is not implemented yet.
- The wild and familiar Gremlin visuals are replacement-ready prototypes.
