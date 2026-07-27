from __future__ import annotations

import json
from pathlib import Path


def main() -> None:
    registry_path = Path("data/features/feature_registry.json")
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    features = registry["features"]

    additions = [
        {
            "id": "broken_waystation",
            "order": 15,
            "display_name": "Broken Waystation / Relay Response",
            "category": "Authored Quest Vertical Slice",
            "version": "v1",
            "status": "vertical_slice",
            "description": "Character-led authored quest using Tamsin dialogue, affinity-based relay repair, an illuminated signal trail, staged combat, physical evidence, quest journal stages, key-item rewards, persistent aftermath, and the reusable Authored Quest Framework.",
            "scene": "res://scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn",
            "validation_scenes": ["res://scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn"],
            "automated_tests": [
                "res://scenes/tests/authored_quest_framework_smoke_test.tscn",
                "res://scenes/tests/broken_waystation_consequence_smoke_test.tscn",
            ],
            "dependencies": ["weapon_combat_arena", "enemy_personality_lab"],
            "controls": ["MOVE", "INTERACT", "LIGHT", "HEAVY", "FOCUS", "CAST", "DODGE", "LOCK-ON", "MENU", "RESET"],
            "manual_test": "docs/broken_waystation_v1_test.md",
            "temporary_state": "persistent",
            "story_integrated": True,
            "limitations": [
                "Environment and character presentation remain procedural prototypes.",
                "Goblin and Gremlin actors stand in for future location-specific enemies.",
                "The eastern route opens but does not yet connect to a production region.",
            ],
            "launchable": True,
            "visible_in_launcher": True,
            "ci_validate": True,
            "timeout_seconds": 10,
        },
        {
            "id": "airborne_presentation_lab",
            "order": 46,
            "display_name": "Airborne Presentation Laboratory",
            "category": "Combat Laboratory",
            "version": "v1",
            "status": "development_tool",
            "description": "Dedicated launch, juggle, fall, slam, landing, and recovery presentation space for light, medium, and heavy airborne targets using the shared weapon and reaction pipeline.",
            "scene": "res://scenes/levels/prototypes/prototype_airborne_presentation_lab_v1.tscn",
            "validation_scenes": ["res://scenes/levels/prototypes/prototype_airborne_presentation_lab_v1.tscn"],
            "automated_tests": ["res://scenes/tests/airborne_presentation_smoke_test.tscn"],
            "dependencies": ["weapon_combat_arena"],
            "controls": ["MOVE", "LIGHT", "HEAVY", "DODGE", "LOCK-ON", "RESET"],
            "manual_test": "docs/AIRBORNE_PRESENTATION_V1.md",
            "temporary_state": "runtime_only",
            "story_integrated": False,
            "limitations": [
                "Presentation uses procedural transforms rather than final skeletal animation.",
                "The laboratory isolates target reactions and is not an authored encounter.",
                "Boss-specific airborne resistance and final balance remain deferred.",
            ],
            "launchable": True,
            "visible_in_launcher": True,
            "ci_validate": True,
            "timeout_seconds": 7,
        },
        {
            "id": "systems_integration_hub",
            "order": 48,
            "display_name": "Systems Integration Hub",
            "category": "Integration Laboratory",
            "version": "v1",
            "status": "development_tool",
            "description": "Persistent shared-player campus connecting combat and mastery, aerial reactions, movement, interaction, status, and ability-range stations with fast travel, reset, temporary unlocks, and exact progression restoration.",
            "scene": "res://scenes/levels/prototypes/prototype_systems_integration_hub_v1.tscn",
            "validation_scenes": ["res://scenes/levels/prototypes/prototype_systems_integration_hub_v1.tscn"],
            "automated_tests": ["res://scenes/tests/systems_integration_hub_smoke_test.tscn"],
            "dependencies": ["weapon_combat_arena", "airborne_presentation_lab", "runtime_stat_lab", "dev_interaction_sandbox"],
            "controls": ["MOVE", "INTERACT", "LIGHT", "HEAVY", "FOCUS", "CAST", "DODGE", "LOCK-ON", "FAST TRAVEL", "RESET"],
            "manual_test": "docs/systems_integration_hub_v1_test.md",
            "temporary_state": "runtime_only",
            "story_integrated": False,
            "limitations": [
                "The hub intentionally does not contain every repository capability.",
                "Dedicated laboratories remain authoritative for detailed tuning.",
                "Campus geometry and fixtures are developer presentation rather than final world art.",
            ],
            "launchable": True,
            "visible_in_launcher": True,
            "ci_validate": True,
            "timeout_seconds": 8,
        },
        {
            "id": "wilds_expedition",
            "order": 52,
            "display_name": "Wilds Expedition",
            "category": "Exploration Prototype",
            "version": "v1",
            "status": "experimental",
            "description": "Five-segment outdoor expedition from cypress basin through wet woodland and longleaf ridge toward foothills and Blue Ridge forest, with authored early segments, route familiarity, optional discovery, checkpoints, and shared regional state.",
            "scene": "res://scenes/levels/prototypes/prototype_wilds_expedition_v1.tscn",
            "validation_scenes": ["res://scenes/levels/prototypes/prototype_wilds_expedition_v1.tscn"],
            "automated_tests": [
                "res://scenes/tests/wilds_expedition_smoke_test.tscn",
                "res://scenes/tests/route_familiarity_smoke_test.tscn",
                "res://scenes/tests/authored_wilds_segments_smoke_test.tscn",
            ],
            "dependencies": ["systems_integration_hub"],
            "controls": ["MOVE", "INTERACT", "LIGHT", "HEAVY", "FOCUS", "CAST", "DODGE", "RESET"],
            "manual_test": "docs/wilds_expedition_v1.md",
            "temporary_state": "persistent",
            "story_integrated": False,
            "limitations": [
                "Only Cypress Basin, Wet Woodland, and Pine Ridge have authored layout passes.",
                "Rocky Foothill Camp and Blue Ridge forest remain prototype route segments.",
                "Regional presentation and traversal assets remain replacement-ready.",
            ],
            "launchable": True,
            "visible_in_launcher": True,
            "ci_validate": True,
            "timeout_seconds": 10,
        },
        {
            "id": "regional_expedition_map",
            "order": 53,
            "display_name": "Regional Expedition Map",
            "category": "Exploration Infrastructure",
            "version": "v1",
            "status": "experimental",
            "description": "Regional route-selection and persistence prototype connecting mapped destinations, expedition entry, route familiarity, segment state, and return flow.",
            "scene": "res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn",
            "validation_scenes": ["res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn"],
            "automated_tests": ["res://scenes/tests/regional_expedition_map_smoke_test.tscn"],
            "dependencies": ["wilds_expedition"],
            "controls": ["NAVIGATE", "SELECT", "BACK"],
            "manual_test": "docs/REGIONAL_EXPEDITION_MAP_V1.md",
            "temporary_state": "persistent",
            "story_integrated": False,
            "limitations": [
                "The map represents a prototype regional network rather than final geography.",
                "Combined map and route-familiarity persistence previously required focused validation.",
                "Only the current Wilds route is developed beyond placeholder destination data.",
            ],
            "launchable": True,
            "visible_in_launcher": True,
            "ci_validate": True,
            "timeout_seconds": 8,
        },
    ]

    addition_ids = {entry["id"] for entry in additions}
    features = [entry for entry in features if entry.get("id") not in addition_ids]
    features.extend(additions)

    for entry in features:
        if entry.get("id") == "weapon_combat_arena":
            entry["version"] = "v0.8+"
            entry["description"] = "All-unlocks combat and mastery laboratory for buffered Light and Heavy branches, context techniques, dash and aerial attacks, launch and juggle routes, stance breaks, critical strikes, defense, infusion, and exact temporary progression restoration."
            entry["limitations"] = [
                "Sword, Hammer, and Spear remain the primary authored production movesets; Chain and Whip have separate experimental laboratories.",
                "Presentation is procedural and transform-driven rather than final skeletal animation.",
                "Boss-specific break rules, executions, final animation, and balance remain deferred.",
            ]
        if entry.get("id") == "development_control_center":
            dependencies = list(entry.get("dependencies", []))
            for feature_id in ["broken_waystation", "airborne_presentation_lab", "systems_integration_hub", "wilds_expedition", "regional_expedition_map"]:
                if feature_id not in dependencies:
                    dependencies.append(feature_id)
            entry["dependencies"] = dependencies

    registry["features"] = sorted(features, key=lambda row: (int(row.get("order", 9999)), str(row.get("id", ""))))
    registry_path.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")

    Path("docs/project_map.md").write_text(
        """# Grace of Humanity Prototype Project Map

This is the repository navigation guide. For current planning, read these sources in order:

1. `docs/REPOSITORY_AUDIT.md` for the human-readable capability audit.
2. `data/features/capability_inventory.json` for searchable ownership, aliases, maturity, and `do_not_resuggest`.
3. `data/features/feature_registry.json` for the live launcher and CI inventory.
4. `AGENTS.md` for development rules and quality boundaries.

The capability inventory answers **what already exists**. The feature registry answers **what launches and validates**. Do not maintain another permanent-scene list here.

## Core grammar

```text
Actor → Tool → Action → Payload → Target → Receiver → Reaction → Consequence
```

## Canonical player

The shared Player scene contains movement, camera, lock-on, action state, health/stamina/mana/stance recovery, defense and Perfect Guard, ability casting, data-driven weapons, Dodge, quick items, Soul Grip, Metal Tether, aerial locomotion, climbing, swimming, riding, summons, stealth, equipment appearance, and gameplay HUD layers.

Primary paths: `scenes/actors/player/player.tscn`, `scripts/player/`, `scripts/abilities/`, `scripts/weapons/`, `scripts/items/`, and `scripts/ui/`.

## Combat

Weapon combat is data-first through WeaponDefinition, WeaponMovesetDefinition, WeaponAttackDefinition, WeaponController, DamagePayload, and the shared receiver stack. Implemented behavior includes branching combos, buffering, cancel windows, attack motion, mastery, infusion, dash and aerial techniques, launch and juggle reactions, stance breaks, critical windows, Guard, Perfect Guard, and stale-target cleanup.

Canonical owners: Weapon Combat Arena, Airborne Presentation Laboratory, and Systems Integration Hub. Primary authored movesets are Sword, Hammer, and Spear; Chain and Whip remain experimental flexible classes.

Enemy behavior includes personality profiles, hazard awareness, committed action phases, multi-action selection, defensive actions, threat sensing, reaction delay, and encounter sequencing.

## Abilities and world systems

Casting uses definitions, loadouts, Focus selection, resource payment, modifiers, ground targeting, concentration, projectiles, fields, and ordinary payload delivery. Implemented families include Fire, Ice, Lightning, Earth, Poison, Time, Dreams, Sound, Space, Air, Water, Soul, and Metal tools.

The repository also contains elemental reactions, environmental sources, thermal state, conductive water, circuit graphs, pressure machinery, generators, motors, buoyancy, airflow, gas, flexible tethers, structural collapse, weather, and procedural element presentation. Search `capability_inventory.json` for the canonical owner before proposing extensions.

## Progression and quests

GameState owns stats, affinities, resources, equipment, mastery, unlocks, infusion, inventory, quick-item assignment, key items, relationships, quests, route state, and save data.

The Authored Quest Framework is owned by `scripts/quests/authored_quest_runtime.gd`, `quest_reward_bundle.gd`, `world_state_variant.gd`, and `authored_encounter_sequence.gd`. Broken Waystation / Relay Response is the canonical quest example. Mara and Tamsin are the minimum authored-content quality references.

## Exploration

Ruined Village Approach and Church Trial are story-integrated vertical slices. Wilds Expedition owns the five-segment outdoor route and authored Cypress, Wet Woodland, and Pine Ridge layouts. Regional Expedition Map owns route selection and regional persistence.

## Development infrastructure

- Development Control Center: registry-driven launcher
- Systems Integration Hub: cross-system shared-player campus
- Dev Interaction Sandbox: disposable interaction workbench
- Feature registry validator and runner: launcher/CI integrity
- Capability inventory validator: planning memory and resuggestion integrity

## Planning rule

Search the capability inventory using the user’s language and aliases, inspect canonical owners, and classify work as integration, authored content, polish, extension, consolidation, or genuinely new. Do not resuggest implemented capabilities as new.

Automated checks prove technical contracts. Nick’s manual playtest remains authoritative for feel, clarity, staging, pacing, and visual quality.
""",
        encoding="utf-8",
    )

    print(f"REGISTRY_ALIGNMENT_GENERATED: {len(registry['features'])} features")


if __name__ == "__main__":
    main()
