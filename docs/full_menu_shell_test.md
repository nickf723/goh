# Field Kit Journal and Codex v2 Test

## Goal

The pause-style Field Kit should expose Grace's actual records rather than decorative placeholders.

This pass integrates three existing systems:

```text
GameState quests        → Journal
SpeciesKnowledge        → Codex / Field Studies
ComboRuleRegistry       → Codex / Elemental Reactions
```

It does not introduce a second quest database, bestiary database, or reaction registry.

## Opening and navigation

Open the Field Kit with:

```text
Tab or M
```

Close it with:

```text
Tab, M, or Esc
```

Switch tabs with the displayed keyboard or controller tab controls. The current shell contains:

- Loadout
- Magic
- Items
- Relics
- Grace
- Journal
- Codex
- System

## Journal

The Journal reads `GameState.get_quest_rows()` every time it is rebuilt.

It shows:

- the authoritative current objective;
- active, completed, and failed quest counts;
- separate sections for each quest state;
- quest title and description;
- live objective;
- player-facing stage progress;
- current stage text for active quests;
- completed optional-goal count.

A zero-based stored stage such as `stage = 1` in a three-stage quest is presented as:

```text
Step 2/3
```

No hard-coded main-thread placeholder remains.

## Codex

### Field Studies

The first Codex section reads the live `SpeciesKnowledge` rows. Each species card can show:

- observed or unobserved state;
- knowledge rank and rank title;
- points toward the next threshold;
- distinct observation labels;
- earned capabilities;
- the next insight.

Goose is currently the only authored species.

### Elemental Reactions

The second section continues to read `ComboRuleRegistry.get_debug_matrix_rows()`, but formats those rows as player-readable reaction cards.

For example:

```text
toxic_ignition → Toxic Ignition
wet_conduction → Wet Conduction
fanned_flames  → Fanned Flames
```

Trigger tags, target requirements, status requirements, and area radius remain visible without exposing raw underscored IDs as the primary title.

## Automated validation

The registered Field Inventory smoke test now drives the real shell through:

```text
scenes/tests/field_inventory_smoke_test.tscn
```

In addition to inventory and quick-belt behavior, it seeds:

- one staged active quest;
- two distinct Goose observations.

It then verifies that the Journal renders the live title, objective, and `Step 2/3`, and that the Codex renders Goose observations plus readable elemental reactions.

The focused species snapshot test remains:

```text
scenes/tests/species_knowledge_smoke_test.tscn
```

## Manual test: Journal

1. Run `scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn`.
2. Speak to Tamsin and accept **The Relay Response**.
3. Open the Field Kit and choose **Journal**.
4. Confirm the current objective matches the HUD.
5. Confirm **The Relay Response** appears under **Active Quests**.
6. Advance the mission through the eastern relay.
7. Reopen the Journal after each stage and confirm the objective and step advance.
8. Complete the quest.
9. Reopen the Journal and confirm it moved to **Completed** without losing its final objective.

## Manual test: Codex

1. Run `scenes/levels/prototypes/prototype_goose_study_lab_v1.tscn`.
2. Open the Codex before studying a Goose.
3. Confirm Goose appears as **Unobserved** with no field observations.
4. Record Walking Gait.
5. Reopen the Codex and confirm one observation appears.
6. Repeat Walking Gait and confirm it is not duplicated.
7. Record Preferred Food.
8. Confirm the rank, capability list, knowledge total, and next insight update.
9. Scroll into **Elemental Reactions**.
10. Confirm reaction names are readable and retain their trigger and target requirements.

## Manual test: persistence

1. Earn at least one Goose observation.
2. Save at a bed in a scene using the standard `GameState` save flow.
3. Restart or reload from that save.
4. Open the Codex.
5. Confirm the Goose points, distinct observations, and derived capability unlocks return.
6. Load an older save without a `species_knowledge` section and confirm it still loads with empty species records.

## Expected limitations

- Journal and Codex entries are read-only.
- Goose is the only species definition.
- There is no search, filtering, map pinning, illustration gallery, or unread badge.
- Elemental reactions are currently globally visible rather than discovered one by one.
- Final typography, icons, creature art, and parchment treatment are future presentation work.
