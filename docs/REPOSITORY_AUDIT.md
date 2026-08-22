# Grace of Humanity Repository Audit

Last consolidated: 2026-08-22

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
- This remains the reference implementation for reusable authored-quest composition.

### The Drowned Bell

- Lifecycle: story_integrated complete authored quest
- Canonical scene: `scenes/levels/prototypes/prototype_drowned_bell_v1.tscn`
- Covers Orin dialogue, causeway listening, resonance investigation, authored chapel and crypt environments, two swimming routes, the passive-to-hostile Listener, three physical resolution routes, recovered evidence, route-aware return dialogue, rewards, journal completion, and persistent quiet aftermath.
- This is the current reference for composition-first reuse of the quest, playability, environment, swimming, combat-payload, guidance, and world-state systems without adding another generic framework.

## Canonical shared systems

### Player

Owner areas:

```text
scenes/actors/player/player.tscn
scripts/player/
scripts/abilities/
scripts/weapons/
```

Implemented capabilities include movement, camera, lock-on, jump, double jump, hover, flight, dodge, guard, perfect guard, action locks, health, stamina, mana, stance, quick items, inventory, Soul Grip, Metal Tether, climbing, swimming, riding, summons, stealth, equipment appearance, and last-resort playable-space recovery.

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

### Animals and Mob Engine

Owner areas:

```text
scripts/mobs/
scripts/animals/
scripts/summons/bonded_familiar_roster.gd
```

Implemented capabilities include shared move definitions, species policies, body-plan eligibility, validated ground/swimming/flight/climbing/burrowing capability profiles, runtime mode transitions and medium validation, planar/surface/volumetric steering, water-current sampling, surface buoyancy, gravity policy, opt-in gait modifiers, personality-shaped utility scoring, drives, committed intentions, startup/active/recovery timing, phase-aware interruption, exactly-once active-phase effect requests, authoritative actor-owned target acquisition, reusable contact/area/projectile/recovery execution, shared DamagePayload conversion, species-derived health and stamina, incapacitation, timed buffs and harmful conditions, policy-visible status and active-locomotion tags, perception and memory, same-species alerts, Grace relationships, persistent bonding, familiar loadouts, navigation-aware commands, rescue state, and stuck recovery.

Seed moves cover ambient, forage, retreat, contact, gap-closing, support, projectile, habitat, control, and area-action families, including reusable Peck, Climb, and Burrow actions. Seed species are Wolf, Sheep, Capybara, Gorgon, Gremlin, Goose, Trout, Gecko, and Mole. The reusable live animal actor presents procedural quadruped, waterfowl, fish, low-reptile, and digging-mammal bodies with real vitals, physical effects, relationships, bonding, and shared locomotion. The canonical Animal Behavior Lab includes a real `SwimmingWaterVolume`, a generic `MobTraversalMedium`, live water-only, amphibious, flying/swimming, wall-climbing, and routed-burrowing animals, incompatible-mode rejection, and controls that restore authored start modes and route progress.

Do not propose animal movesets, animal personality, bonding, locomotion capability data, runtime ground/swimming/flight/climbing/burrowing steering, active-phase effects, animal vitals, statuses, projectiles, familiar commands, authored Goose/Trout/Gecko/Mole proving species, generic water or traversal habitats, or a generic animal AI foundation as new mechanics. The next extension is an authored exploration-space application of the existing habitat contracts; ceiling/corner climbing, terrain-occluded burrows, entrances/exits, or deformation should be added only when that content proves the need.

### Enemy AI

Owner areas:

```text
scripts/enemies/
data/enemies/
data/enemy_attacks/
```

Implemented capabilities include personality profiles, hazard awareness, committed action phases, multi-action selection, independent cooldowns, defensive actions, Backstep, threat perception, reaction delay, interruption, and airborne response.

Authored encounter actors may compose ordinary target, payload, health, force, status, and cleanup contracts without becoming a new general AI family. The Drowned Bell's Listener is deliberately encounter-specific.

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

Implemented capabilities include stats, elemental affinities, weapon mastery, unlocks, equipment, infusion, inventory, quick-item assignments, key items, loot, relationships, quests, checkpoints, route familiarity, regional expedition state, route-aware quest aftermath, and save restoration.

### Global playability and authored environment composition

Owner areas:

```text
scripts/quality/
scripts/player/player_recovery_controller.gd
scripts/environment/
scripts/levels/drowned_bell_playability_pass.gd
scripts/levels/drowned_bell_environment_pass.gd
```

Implemented playability capabilities include explicit bounds, recovery and forbidden volumes, safe destination queries, safe Blink destinations, grounded recovery anchors, swimming exit anchors, quest guidance targets, and a structural scene auditor.

Implemented environment-composition capabilities include palette-driven prototype materials, collision-matched primitives, continuous stair runs, pillars, archways, non-blocking dressing, local lights, water-volume alignment, build statistics, and an authored-environment auditor.

These systems guarantee safety, consistency, and construction contracts. They do not replace authored floor plans, sightlines, environmental history, mood, camera checks, or human playtesting.

### Modular environment assets

Owner areas:

```text
scenes/environment/modular/
scripts/environment/modular_environment_piece.gd
scripts/environment/modular_environment_gate.gd
scripts/environment/modular_environment_catalog.gd
art/materials/environment/modular/
shaders/environment/
```

The Weathered Cloister kit provides reusable scene assets for floors, walls, arches, stairs, pillars, timber frames, gates, pedestals, crates, barrels, sconces, and water channels. Its canonical benchmark is `prototype_modular_environment_showcase_v1.tscn`.

Do not propose another generic modular architecture framework, prop kit, or environment showcase as new work. Extend this kit only when repeated authored-content needs justify additional modules or material families.

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
| Modular environment assets | `prototype_modular_environment_showcase_v1.tscn` |
| Completed composition-first quest | `prototype_drowned_bell_v1.tscn` |

A dedicated lab may still be appropriate when a mechanic needs isolated measurement, but the capability inventory must identify why an existing owner scene is insufficient.

## Known consolidation risks

### Documentation drift

The repository audit, capability inventory, project map, feature registry, and Development Control Center now describe the major permanent systems and quests. Every future permanent feature must update the appropriate source in the same change so these views do not diverge again.

### Deep wrapper inheritance

Ability casters, Broken Waystation, and some prototype levels use layered subclasses. Preserve working behavior, but prefer direct component composition when a future task already touches those files. The Drowned Bell deliberately uses separate composition passes rather than inheriting from the previous quest.

### Historical pull requests and validation branches

Several stacked or validation-only PRs remain as historical context even though production work landed directly on `main`. Treat them as archaeology unless their head contains a capability absent from `main`, and close temporary validation mirrors after their checks finish.

### Labs without authored use

Many systems are technically verified but have no story-integrated appearance. Their next milestone should normally be authored use, not another isolated extension.

### Uneven presentation quality

Automated validation proves contracts, not player-facing quality. Mara and Tamsin remain the minimum conversation and staging references; the rebuilt Drowned Chapel establishes a stronger baseline for continuous collision, environmental composition, readable water routes, and authored landmarks.

### Scene-specific pass growth

Composition avoids inheritance towers, but a quest can still accumulate too many adjacent pass scripts. Consolidate level-specific passes only when a future change already touches their shared boundary; do not destabilize a validated authored route solely to reduce file count.

## Definition of a genuinely new capability

A capability is new only when all are true:

- no inventory entry or alias describes it;
- no canonical owner can express it through data or composition;
- an authored experience requires it now;
- the implementation adds a reusable contract rather than a scene-local shortcut;
- the capability, owner, maturity, test, and aliases are recorded in `capability_inventory.json`.

## Near-term roadmap

Recommended next work after The Drowned Bell v3:

1. manually playtest the full chapel and crypt route, including all three Listener resolutions, and fix player-facing friction before expanding the story;
2. perform a focused Systems Friction Review using evidence from Broken Waystation and The Drowned Bell rather than launching a broad refactor;
3. integrate the global playability and environment-composition contracts into the next authored scene as it is built;
4. consolidate wrapper or pass boundaries only when active work already requires touching them;
5. integrate dormant physical and elemental systems into story content instead of adding more foundations.
