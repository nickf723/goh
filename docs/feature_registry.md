# Feature Registry

`data/features/feature_registry.json` is the canonical inventory of permanent Grace of Humanity development scenes.

Both the Development Control Center and CI consume this file. Do not maintain a second list of laboratories, arenas, prototype routes, or registered tests.

## What belongs in the registry

Register a scene when it is intended to remain available as one of the following:

- a playable vertical slice;
- a permanent systems laboratory or combat arena;
- a reusable development sandbox;
- development infrastructure with its own scene and validation contract.

Do not register disposable scratch scenes, temporary visual experiments, imported examples, or one-off debugging fragments.

## Required feature fields

Each feature object contains:

```json
{
  "id": "weapon_combat_arena",
  "order": 30,
  "display_name": "Weapon Combat Arena",
  "category": "Systems Arena",
  "version": "v0.6",
  "status": "prototype_verified",
  "description": "Player-facing purpose.",
  "scene": "res://scenes/levels/prototypes/example.tscn",
  "validation_scenes": [
    "res://scenes/levels/prototypes/example.tscn"
  ],
  "automated_tests": [
    "res://scenes/tests/example_smoke_test.tscn"
  ],
  "dependencies": [],
  "controls": ["MOVE", "INTERACT"],
  "manual_test": "docs/example_test.md",
  "temporary_state": "runtime_only",
  "story_integrated": false,
  "limitations": ["Known limitation."],
  "launchable": true,
  "visible_in_launcher": true,
  "ci_validate": true,
  "timeout_seconds": 5
}
```

## Allowed statuses

```text
vertical_slice
prototype_verified
development_tool
infrastructure
experimental
disabled
```

Status describes maturity and purpose. It does not claim final art, final balance, or production readiness.

## Temporary-state policies

```text
none          Feature does not intentionally mutate gameplay state.
runtime_only  Mutations are disposable and should not survive the scene.
persistent    Feature legitimately exercises save/progression behavior.
mixed         Feature contains both temporary and persistent paths.
```

## Dependencies

Dependencies refer to other feature IDs in the same registry.

Use them only for genuine feature-level prerequisites. Do not list every script, payload, receiver, material, or shared subsystem.

The validator rejects:

- unknown dependency IDs;
- self-dependencies;
- dependency cycles.

## Adding a permanent feature

1. Build and validate the scene on its bounded feature branch.
2. Add or update its manual test document.
3. Add the feature entry to `feature_registry.json`.
4. Add its startup scene to `validation_scenes`.
5. Add deterministic test scenes to `automated_tests`.
6. Run:

```powershell
python scripts/ci/validate_feature_registry.py
./scripts/ci/validate_project.ps1
```

7. Open the Development Control Center and confirm the new entry is readable and launchable.

No GitHub Actions YAML edit should be required for a newly registered scene or test.

## Validation commands

Static registry validation:

```powershell
python scripts/ci/validate_feature_registry.py
```

Registry-driven Godot validation:

```powershell
python scripts/ci/run_feature_registry.py --godot godot
```

Full local project validation:

```powershell
./scripts/ci/validate_project.ps1
```

The Python validator checks schema, IDs, ordering, files, documentation, statuses, state policies, dependencies, and cycles.

The runner then boots every CI-enabled `validation_scenes` entry and executes every registered `automated_tests` scene.

## Control Center behavior

`scenes/ui/development_control_center_v1.tscn` reads the same JSON through `FeatureRegistry`.

A launcher entry is disabled when its registered scene, test, documentation, or dependency contract is invalid. The launcher never invents fallback paths or silently repairs registry data.

## Agent rule

A builder adding a permanent development scene must update the registry in the same pull request. A reviewer should treat an unregistered permanent scene as incomplete infrastructure, not harmless documentation debt.
