# Creature Mastery and Familiar Training Yard v1

## Purpose

Creature Mastery connects field study, species records, familiar loadouts, summoning, friendly group AI, and future transformation forms.

Training scene:

```text
res://scenes/levels/prototypes/prototype_familiar_training_yard_v1.tscn
```

## Progression loop

Gremlin knowledge comes from unique discoveries rather than repeat farming:

1. First encounter
2. Survive Pounce
3. Witness Backstep
4. Observe pack coordination
5. Discover Conduct susceptibility
6. Study scavenging habitat
7. Form a stable familiar bond by summoning successfully

The first two observations unlock the Gremlin Familiar. Additional ranks unlock Pounce, Mire Spit, and the future Gremlin Transformation form.

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

The summon spell creates the prepared blueprint immediately. Configuration is not performed during combat.

## Shared creature abilities

Wild Gremlins and Gremlin familiars share the existing EnemyActionOption and EnemyCombatActionDefinition resources. The familiar driver interprets those resources for friendly control. A future transformation driver can consume the same creature ability catalog.

## Friendly group AI

Assist mode uses the shared target-allocation blackboard under the `grace_familiars` squad. The familiar:

- evaluates hostile targets
- avoids crowded or overkilled targets
- uses role-aware target scoring
- claims attention, melee pressure, damage, or setup
- uses Mire Spit as a Wet setup when configured as Primer
- respects Grace's lock-on target in Focus mode

## Training Yard layout

- South archive: six Gremlin study terminals
- Center: durable training dummies
- North pen: two live wild Gremlins
- East ring: familiar deployment area
- West gate: reserved transformation prototype area
- Violet console: combat reset without erasing creature knowledge

## Controls

- Standard movement, combat, spells, Focus, and summon controls
- Tab or M: open full menu
- Magic tab: configure Familiar Blueprint
- Interact: study terminals or reset console
- F8 in editor: reset combat while preserving mastery

## Automated tests

```powershell
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/species_knowledge_smoke_test.tscn
& "C:\Users\nickf\Downloads\Godot_v4.6.2-stable_win64.exe" --headless --path . res://scenes/tests/creature_mastery_familiar_smoke_test.tscn
```

Expected:

```text
SPECIES KNOWLEDGE SMOKE TEST PASSED
CREATURE_MASTERY_FAMILIAR_SMOKE_TEST: PASS
```

## Known limitations

- Presence capacity is one in v1, although definitions already expose presence cost and maximum active count.
- Only Gremlin has a complete creature familiar implementation.
- Familiar navigation uses direct CharacterBody movement rather than NavigationAgent pathfinding.
- Transformation support is represented in the shared definition and ability catalog, but player possession is not implemented yet.
- The wild and familiar Gremlin visuals are replacement-ready prototypes.
