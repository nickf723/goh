# Grace of Humanity Repository Audit

Last consolidated: 2026-07-27

This document is the planning-level inventory for the playable prototype. Read it before proposing a new mechanic, laboratory, quest framework, or integration milestone.

The machine-readable companion is:

```text
data/features/capability_inventory.json
```

The launch and CI source of truth remains:

```text
data/features/feature_registry.json
```

## Classification

Every substantial feature belongs to one lifecycle class:

- **canonical**: shared production architecture or the authoritative test location for a mechanic;
- **story_integrated**: used in persistent player-facing content;
- **experimental**: working and reusable, but not yet proven in authored content;
- **superseded**: retained for compatibility or history, but not the preferred implementation path;
- **scratch**: temporary investigation only and not part of the permanent inventory.

A feature may be both canonical and story-integrated.

## Planning rule

Before proposing work:

1. Search `capability_inventory.json` by mechanic and alias.
2. Reuse the listed owner files and canonical scene.
3. Do not propose an implemented capability as a new feature.
4. Prefer integration, authored content, polish, or consolidation when the capability already exists.
5. Add a new capability entry in the same change that introduces a genuinely new reusable mechanic.

## Current strategic state

The repository has more systemic substrate than authored game content. New mechanics are rarely the best next milestone.

Current priority order:

1. authored quests, puzzles, encounters, and story routes using existing systems;
2. visual and interaction quality inside those authored routes;
3. consolidation of duplicate wrappers and stale development scenes;
4. expansion of existing mechanic families only when a specific authored experience requires it;
5. entirely new foundations only after the inventory confirms no reusable path exists.

## Canonical playable content

### Ruined Village Approach

- Lifecycle: story_integrated
- Canonical scene: `scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn`
- Covers exploration, environmental storytelling, combat, elemental route solving, optional Sound discovery, checkpointing, and Church Trial entry.

### Church Trial

- Lifecycle: story_integrated
- Canonical scene: `scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn`
- Covers elemental tests, exploration, combat rooms, Sound reveal, Animated Armor, reward, persistence, and exit.

### Mara Roadside Encounter

- Lifecycle: story_integrated reference encounter
- Canonical scene: `scenes/levels/prototypes/prototype_roadside_conversation_lab_v1.tscn`
- Canonical quality reference for NPC staging, dialogue choices, requirements, relationship changes, quest continuation, and visible world feedback.

### Broken Waystation / Relay Response

- Lifecycle: story_integrated quest template
- Canonical scene: `scenes/levels/prototypes/prototype_broken_waystation_mission_v1.tscn`
- Covers Tamsin dialogue, multi-method repair, authored trail, staged combat, optional interactions, evidence recovery, journal stages, rewards, completion summary, and persistent aftermath.
- This is the current reference implementation for future authored quests.

## Canonical shared systems

### Player

Owner areas:

```text
scenes/actors/player/player.tscn
scripts/player/
scripts/abilities/
scripts/weapons/
```

Implemented capabilities include movement, camera, lock-on, jump, double jump, hover, flight, dodge, guard, perfect guard, action locks, health, stamina, mana, stance, quick items, inventory, Soul Grip, Metal Tether, climbing, swimming, riding, summons, stealth, and equipment appearance.

### Weapon combat

Owner areas:

```text
scripts/weapons/
data/weapons/
data/weapon_movesets/
scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn
```

Implemented capabilities include buffered Light/Heavy graphs, startup/active/recovery phases, cancels, attack movement, mastery, infusion, dash techniques, aerial techniques, launchers, airborne reactions, stance breaks, critical windows, guard interactions, hit stop, and stale-target-safe combat.

Authored weapon classes: Sword, Hammer, Spear.

Do not propose weapon mastery, combo trees, dash attacks, aerial attacks, stance breaks, criticals, guard, or a general combat laboratory as new mechanics.

### Ability and spell casting

Owner areas:

```text
scripts/abilities/
scripts/actions/
data/abilities/
```

Implemented families include projectiles, charged modifiers, piercing modifiers, chain effects, ground targeting, lingering fields, trigger traps, concentration, weather, detection, environmental element sources, and elemental reaction delivery.

Do not propose a generic ground-targeting system, spell modifier framework, spell menu, or generic elemental payload grammar as new work.

### Quest and conversation

Owner areas:

```text
scripts/dialogue/conversation_npc.gd
scripts/quests/
scripts/interaction/story_interactable.gd
scripts/levels/prototype_broken_waystation_framework_integration.gd
```

Canonical reusable pieces:

- `AuthoredQuestRuntime`
- `QuestRewardBundle`
- `WorldStateVariant`
- `AuthoredEncounterSequence`
- Quest journal
- Key items
- Requirement-aware dialogue
- Relationship changes
- Completion summaries
- Persistent aftermath

Do not propose a generic quest director, encounter sequencer, reward bundle, world-state variant system, or quest journal as new work.

### Enemy AI

Owner areas:

```text
scripts/enemies/
data/enemies/
data/enemy_attacks/
```

Implemented capabilities include personality profiles, hazard awareness, committed action phases, multi-action selection, independent cooldowns, defensive actions, Backstep, threat perception, reaction delay, interruption, and airborne response.

Do not propose enemy personality, action selection, generic committed phases, or incoming-attack awareness as new foundations.

### Elemental reactions

Owner areas:

```text
scripts/surfaces/
scripts/systems/reaction_resolver.gd
data/combo_rules/
```

Implemented reactions include ignite, conduct, freeze, shatter, steam, cleansing, reveal, toxic ignition, radial consequences, environmental emitters, and status surfaces.

### Physical simulation and machinery

Owner areas:

```text
scripts/physics/
scripts/circuits/
scripts/thermal/
scripts/machinery/
scripts/fluids/
scripts/airflow/
scripts/structures/
scripts/tethers/
```

Implemented capabilities include material profiles, force, torque, fields, magnetism, circuits, conductive water, thermal state, phase changes, pressure, turbines, generators, motors, conveyors, buoyancy, currents, propellers, airflow, gas, smoke, flexible tethers, pulleys, structural supports, fracture, and collapse.

Do not propose electricity, circuits, thermal simulation, steam pressure, generators, motors, buoyancy, airflow, rope physics, or structural stress as new foundations.

### Progression and persistence

Implemented capabilities include stats, elemental affinities, weapon mastery, unlocks, equipment, infusion, inventory, quick-item assignments, key items, loot, relationships, quests, checkpoints, route familiarity, and regional expedition state.

## Canonical development scenes

Use these scenes as mechanic owners rather than creating another lab by default:

| Domain | Canonical scene |
| --- | --- |
| Integrated systems | `prototype_systems_integration_hub_v1.tscn` |
| Weapon combat | `prototype_weapon_combat_arena_v1.tscn` |
| Stats and resources | `prototype_runtime_stat_lab_v1.tscn` |
| Elemental reactions | `prototype_environmental_chemistry_lab_v1.tscn` |
| General interaction | `dev_interaction_sandbox.tscn` |
| Enemy personality | `prototype_enemy_personality_lab_v1.tscn` |
| Airborne reactions | `prototype_airborne_presentation_lab_v1.tscn` |
| Physical fields | `prototype_physical_interaction_lab_v1.tscn` |
| Flexible tethers | `prototype_flexible_tether_lab_v1.tscn` |
| Structural failure | `prototype_structural_stress_lab_v1.tscn` |
| Spatial portals | `prototype_spatial_portal_lab_v1.tscn` |
| Resonance | `prototype_resonance_lab_v1.tscn` |
| Buoyancy and fluid forces | `prototype_buoyancy_lab_v1.tscn` |
| Element presentation | `prototype_element_vfx_gallery_v1.tscn` |
| Wilds route | `prototype_wilds_expedition_v1.tscn` |
| Authored quest template | `prototype_broken_waystation_mission_v1.tscn` |

A dedicated lab may still be appropriate when a mechanic needs isolated measurement, but the capability inventory must identify why an existing owner scene is insufficient.

## Known consolidation risks

### Stale documentation

`docs/project_map.md` and the feature registry predate several July 26–27 systems. This audit supersedes the project map for capability discovery until that document is fully regenerated.

### Deep wrapper inheritance

Ability casters, Broken Waystation, and some prototype levels use layered subclasses. Preserve working behavior, but prefer consolidating to one canonical owner when a future task already touches those files.

### Historical open pull requests

Several stacked PRs remain open even though equivalent work landed on `main`. Treat open PRs as historical context unless their head contains a capability absent from `main`.

### Labs without authored use

Many systems are technically verified but have no story-integrated appearance. Their next milestone should normally be authored use, not another isolated extension.

### Uneven presentation quality

Automated validation proves contracts, not player-facing quality. Mara and Tamsin are the minimum authored-content quality references.

## Definition of a genuinely new capability

A capability is new only when all are true:

- no inventory entry or alias describes it;
- no canonical owner can express it through data or composition;
- an authored experience requires it now;
- the implementation adds a reusable contract rather than a scene-local shortcut;
- the capability, owner, maturity, test, and aliases are recorded in `capability_inventory.json`.

## Near-term roadmap

Recommended next work after consolidation:

1. validate and correct the capability inventory against live repository paths;
2. promote missing permanent scenes into the feature registry;
3. identify superseded wrapper scripts and duplicate labs;
4. close or label historical stacked PRs;
5. build a second authored quest using the extracted framework;
6. integrate dormant physical and elemental systems into story content instead of adding more foundations.
