# Development Control Center v0.8 Test

## Scene

```text
scenes/ui/development_control_center_v1.tscn
```

## Purpose

Validate that the canonical feature registry drives both the controller-first launcher and automated validation without maintaining parallel feature lists.

## Load the branch

```powershell
git status
git fetch origin
git switch agent/development-control-center-v0-8
git pull
```

## Initial presentation

1. Run the Development Control Center scene.
2. Confirm the title reads `DEVELOPMENT CONTROL CENTER`.
3. Confirm the health banner reports a healthy registry with six total features and zero errors.
4. Confirm the visible list contains, in order:
   - Church Trial
   - Elemental Reaction Laboratory
   - Weapon Combat Arena
   - Runtime Stat Laboratory
   - Dev Interaction Sandbox
5. Confirm the Control Center does not list itself as a recursive launcher entry.

## Controller navigation

Use the controller's standard UI navigation rather than gameplay bindings.

1. Move through the list using NAVIGATE.
2. Confirm the highlight moves one entry at a time.
3. Confirm each entry updates the detail panel immediately.
4. Press SELECT on an entry and confirm its registered scene launches.
5. Restart the Control Center and press BACK.
6. Confirm BACK returns to the prototype title scene.

No new controller mapping should be created or existing mapping overridden.

## Registry-driven detail panel

For each visible feature, confirm the panel displays:

- display name;
- category;
- version;
- maturity/status;
- description;
- feature dependencies;
- semantic controls;
- temporary-state policy;
- story-integration status;
- manual test path;
- known limitations;
- validation readiness.

Compare several values directly with:

```text
data/features/feature_registry.json
```

The launcher must not contain hard-coded per-feature descriptions or paths.

## Launch matrix

Launch each entry at least once:

### Church Trial

- Correct integrated trial scene opens.
- No save is deleted by launching it from the Control Center.

### Elemental Reaction Laboratory

- Reaction stations and focused five-element loadout appear.
- Temporary laboratory state remains disposable.

### Weapon Combat Arena

- Sword, Hammer, and Spear racks appear.
- Current user LIGHT/HEAVY controller mappings remain intact.

### Runtime Stat Laboratory

- Snapshot capture occurs normally.
- RESET ALL and EXIT LAB still restore the entry state.

### Dev Interaction Sandbox

- General interaction objects, surfaces, and development tools appear.

## Error-state test

Perform this only on a disposable local edit, then revert it.

1. Temporarily change one visible feature's `scene` path in the JSON to a missing `.tscn` file.
2. Run:

```powershell
python scripts/ci/validate_feature_registry.py
```

3. Confirm validation fails and names the feature plus missing path.
4. Open the Control Center.
5. Confirm registry health reports errors and the broken entry is disabled.
6. Restore the original JSON before committing or continuing.

## Dependency validation test

Perform this only on a disposable local edit, then revert it.

1. Add an unknown dependency to one feature.
2. Confirm the Python validator fails with `unknown dependency`.
3. Create a temporary two-feature cycle.
4. Confirm validation fails with a dependency-cycle report.
5. Restore the original JSON.

## Registry-driven CI test

Run:

```powershell
python scripts/ci/validate_feature_registry.py
python scripts/ci/run_feature_registry.py --godot godot
```

Confirm the runner reports all registered startup scenes and tests, including:

- Church Trial startup;
- Elemental Reaction Laboratory startup;
- elemental reaction recipe test;
- Weapon Combat Arena startup;
- weapon moveset graph test;
- Runtime Stat Laboratory startup;
- runtime stat-session test;
- Dev Interaction Sandbox startup;
- Development Control Center startup;
- architecture contract test.

Adding another valid registered feature should not require editing `.github/workflows/godot-validation.yml`.

## Architecture contract test

The architecture test must verify:

- registry runtime loading;
- registered scene and test resources;
- Health, Stamina, Mana, and Stance current/max pairs;
- semantic UI, interaction, combat, spell, and dodge input actions;
- Sword, Hammer, and Spear moveset graph validity;
- weapon payload source and tag contracts;
- starting loadout ability scene references;
- payload requirements for non-instant abilities;
- valid scaling-stat IDs.

## Full regression

After Control Center validation, run the detailed test contracts registered for:

```text
docs/church_trial_vertical_slice_test.md
docs/elemental_reaction_lab_v0_5_test.md
docs/weapon_combat_arena_v0_6_test.md
docs/runtime_stat_lab_v0_7_test.md
docs/dev_interaction_sandbox_test.md
```

## Explicitly unchanged

- Production main scene
- Existing save files and save schema
- Story progression and key items
- Combat and spell balance
- Stat formulas
- Controller bindings
- Art direction
- Enemy AI

## Known limitations

- The Control Center is developer infrastructure, not a player-facing level select.
- It validates repository-local registry contracts, not open pull-request conflicts.
- A green registry proves paths and contracts are coherent, not that a feature is fun or creatively approved.
- Returning from launched scenes to the Control Center is not globally injected into production scenes; use the editor or each scene's existing exit/reset flow.
