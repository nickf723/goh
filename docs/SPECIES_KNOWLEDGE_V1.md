# Species Knowledge and Animal Study v1

Grace gains persistent species knowledge by discovering distinct behaviors and forming relationships. Repeating the same observation does not farm points.

The system is intentionally shared substrate. Field study, familiar forms, animal capabilities, transformations, the save slot, and the Field Kit Codex all read the same species record instead of maintaining parallel checklists.

## Goose progression

- Rank 0: Goose Codex
- Rank 1: Goose Familiar Form
- Rank 2: Alarm Cry Capability
- Rank 3: Migratory Flight Capability
- Rank 4: Goose Transformation

The current Goose study records movement, food preference, trust, and alarm behavior. More species can be added to the same definition table without changing the journal or save architecture.

## Persistent record contract

`SpeciesKnowledge` now exposes a versioned snapshot containing:

- knowledge points by species;
- unique discovery IDs and their player-facing labels.

Earned unlocks are rebuilt from the saved point totals, so the save file does not carry a second potentially contradictory progression list.

`GameState` stores this snapshot under:

```text
species_knowledge
```

Old saves without that section remain valid and begin with an empty field-study record. `reset_run()` clears all species observations along with the rest of the run state.

Primary APIs:

```text
SpeciesKnowledge.get_snapshot()
SpeciesKnowledge.apply_snapshot(snapshot)
SpeciesKnowledge.reset_all()
SpeciesKnowledge.get_all_species_rows()
SpeciesKnowledge.get_summary()
```

## Field Kit Codex

Open the Field Kit with `Tab` or `M`, then choose **Codex**.

The Field Studies section shows:

- each registered species;
- observation status;
- rank title and rank progress;
- distinct discoveries;
- earned capabilities;
- the next species unlock.

The same Codex keeps the authored elemental-reaction grammar below the field notes. This is a presentation integration, not a replacement for `ComboRuleRegistry`.

## Context controls

D-pad Down is reserved for special context.

- Tap: perform the context's primary action
- Hold until the compact context menu opens, then release: the menu stays open
- Press Left/Up/Right to select one of three actions
- Press Down again to cancel
- Keyboard equivalent: hold then release Tab; use Left/Up/Right or 1/2/3, and Tab again to cancel

Contexts currently include familiar commands, mounts, and animal study. Controller quick items retain D-pad Up, Left, and Right. All four quick-item slots remain available through keyboard shortcuts.

## Laboratory

Run:

```text
scenes/levels/prototypes/prototype_goose_study_lab_v1.tscn
```

Study movement, food preference, trust, and alarm behavior across three geese. Open the Field Kit after each new observation and confirm that the Goose card grows rather than duplicating the same note.

## Automated checks

```text
scenes/tests/species_knowledge_smoke_test.tscn
scenes/tests/field_inventory_smoke_test.tscn
```

The focused species test verifies duplicate prevention, ranks, unlocks, snapshot restoration, and menu-row summaries. The registered Field Inventory test verifies that the live Journal and Codex render quest and species records through the actual Field Kit shell.

## Current limitations

- Goose is the only authored species definition.
- Species entries use text and icon presentation rather than final illustrations.
- Elemental reactions are currently shown as known system grammar rather than discovery-gated research.
- Familiar customization and full animal transformation remain separate future authored uses of the existing unlock IDs.
