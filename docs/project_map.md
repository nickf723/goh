# Grace of Humanity Prototype Project Map

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

The shared Player scene contains movement, camera, lock-on, action state, health/stamina/mana/stance recovery, defense and Perfect Guard, ability casting, data-driven weapons, Dodge, quick items, Soul Grip, Metal Tether, aerial locomotion, climbing, swimming, riding, summons, stealth, equipment appearance, gameplay HUD layers, and last-resort playable-space recovery.

Grace's physical envelope and prototype silhouette are explicit data through `data/player/grace_spatial_profile.tres`, applied by `scripts/player/player_spatial_profile_controller.gd`. The profile owns capsule dimensions, silhouette measurements, authored-space clearance, and route or interaction radii without changing Grace's character identity or animation hierarchy.

Primary paths: `scenes/actors/player/player.tscn`, `scripts/player/`, `scripts/abilities/`, `scripts/weapons/`, `scripts/items/`, and `scripts/ui/`.

## Combat

Weapon combat is data-first through WeaponDefinition, WeaponMovesetDefinition, WeaponAttackDefinition, WeaponController, DamagePayload, and the shared receiver stack. Implemented behavior includes branching combos, buffering, cancel windows, attack motion, mastery, infusion, dash and aerial techniques, launch and juggle reactions, stance breaks, critical windows, Guard, Perfect Guard, and stale-target cleanup.

Canonical owners: Weapon Combat Arena, Airborne Presentation Laboratory, and Systems Integration Hub. Primary authored movesets are Sword, Hammer, and Spear; Chain and Whip remain experimental flexible classes.

Enemy behavior includes personality profiles, hazard awareness, committed action phases, multi-action selection, defensive actions, threat sensing, reaction delay, and encounter sequencing. Encounter-specific actors such as the Drowned Bell's Listener may compose these shared combat contracts without becoming a new general AI framework.

## Abilities and world systems

Casting uses definitions, loadouts, Focus selection, resource payment, modifiers, ground targeting, concentration, projectiles, fields, and ordinary payload delivery. Implemented families include Fire, Ice, Lightning, Earth, Poison, Time, Dreams, Sound, Space, Air, Water, Soul, and Metal tools.

The repository also contains elemental reactions, environmental sources, thermal state, conductive water, circuit graphs, pressure machinery, generators, motors, buoyancy, airflow, gas, flexible tethers, structural collapse, weather, and procedural element presentation. Search `capability_inventory.json` for the canonical owner before proposing extensions.

## Progression and quests

GameState owns stats, affinities, resources, equipment, mastery, unlocks, infusion, inventory, quick-item assignment, key items, relationships, quests, route state, and save data.

The Authored Quest Framework is owned by `scripts/quests/authored_quest_runtime.gd`, `quest_reward_bundle.gd`, `world_state_variant.gd`, and `authored_encounter_sequence.gd`. Broken Waystation / Relay Response is the canonical reusable quest example. The Drowned Bell is the second complete authored quest and demonstrates direct composition, environmental investigation, alternative resolution, and persistent aftermath. Mara and Tamsin remain the minimum conversation and staging quality references.

## Exploration

Ruined Village Approach and Church Trial are story-integrated vertical slices. Wilds Expedition owns the five-segment outdoor route and authored Cypress, Wet Woodland, and Pine Ridge layouts. Regional Expedition Map owns route selection and regional persistence. The completed Drowned Bell quest combines water traversal, resonance investigation, a coherent chapel and crypt, three Listener-resolution routes, return dialogue, rewards, global playability, authored environment contracts, data-driven set composition, and spatial readability zones.

## Playability and authored-space quality

The reusable playability layer lives under `scripts/quality/` and `scripts/player/player_recovery_controller.gd`. It provides explicit playable bounds, safe recovery transforms, forbidden and recovery volumes, safe destination validation, swimming exit anchors, quest guidance targets, and a structural scene auditor. Space Blink uses the shared safe-destination query, and the shared player retains fallback recovery even in scenes that have not yet declared an explicit `PlayableSpace3D`.

The reusable environment-composition layer lives under `scripts/environment/`. It provides palette-driven prototype materials, collision-matched architectural primitives, stair runs, pillars, archways, non-blocking dressing, local lights, build statistics, and an authored-environment auditor. Level-specific passes retain responsibility for layout, landmarks, sightlines, mood, prop placement, and environmental storytelling.

The Authored Set Composer adds a data-first assembly layer through `scripts/environment/authored_set_composer.gd`, `scripts/environment/authored_set_clearance_auditor.gd`, and `data/set_layouts/`. It builds corridors, opening-aware walls, continuous-ramp stairs, modular catalog placements, and simple support geometry from compact plans. The Drowned Bell crypt passage is the first story-integrated proof. Use it when connected dimensions or repeated placements would otherwise be scattered across unrelated magic numbers.

`AuthoredSetReadabilityAuditor` separately protects route collision, camera breathing room, interaction approaches, landmark hierarchy, and density budgets. `AuthoredSetReadabilityDebug` can visualize those contracts while tuning a set. The Drowned Chapel uses `data/set_layouts/drowned_chapel_readability_v1.json` as the first story-integrated readability plan.

Architecture and manual quality gates are documented in:

```text
docs/GLOBAL_PLAYABILITY_FRAMEWORK_V1.md
docs/global_playability_framework_v1_test.md
docs/AUTHORED_ENVIRONMENT_COMPOSITION_V1.md
docs/AUTHORED_SET_COMPOSER_V1.md
docs/SPATIAL_READABILITY_AND_GRACE_SILHOUETTE_V1.md
docs/drowned_chapel_environment_v2_2_test.md
docs/drowned_chapel_benchmark_remaster_v1_test.md
docs/drowned_bell_v3_test.md
```

These frameworks are safety and construction scaffolds, not substitutes for continuous authored collision, natural boundaries, readable sightlines, deliberate composition, visual rhythm, or human playtesting.

## Modular environment assets

Repeated architecture and props have production-facing scene owners under `scenes/environment/modular/`, with shared weathered materials under `art/materials/environment/modular/` and canonical lookup through `scripts/environment/modular_environment_catalog.gd`. The dedicated Weathered Cloister showcase is `scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn`.

The Drowned Chapel is the first story-integrated modular benchmark. `scripts/levels/drowned_bell_benchmark_remaster_pass.gd` places reusable floors, walls, arches, pillars, timber frames, sconces, water-edge pieces, pedestals, crates, and barrels over the chapel's proven continuous support shell. Repeated architecture disables duplicate collision, while freestanding props remain physical. The memorial arcade, bell frame, rose window, pool geometry, and quest machinery remain bespoke.

`scripts/levels/drowned_bell_spatial_readability_pass.gd` then removes redundant repeated structure, restages physical props against the walls, reduces signal clutter, and audits the chapel against its readability plan.

The modular kit extends the authored environment-composition capability rather than replacing it. Use modular scenes for repeated construction vocabulary. Keep blocking support, bespoke landmarks, floor plans, sightlines, mood, and environmental storytelling authored per level.

Architecture and manual quality gates are documented in:

```text
docs/MODULAR_ENVIRONMENT_AND_PROP_KIT_V1.md
docs/modular_environment_showcase_v1_test.md
docs/drowned_chapel_benchmark_remaster_v1_test.md
```

The next meaningful proof is the Ruined Village Approach. Expand the kit only when that outdoor application exposes a repeated need such as corners, ruined-wall variants, ceilings, vaults, railings, doors, terrain transitions, vegetation-density zones, or open combat-space declarations.

## Development infrastructure

- Development Control Center: registry-driven launcher
- Systems Integration Hub: cross-system shared-player campus
- Dev Interaction Sandbox: disposable interaction workbench
- Feature registry validator and runner: launcher/CI integrity
- Capability inventory validator: planning memory and resuggestion integrity
- Playable Space Auditor: recovery, water-exit, interaction, and guidance contracts
- Authored Environment Auditor: collision-paired surfaces and assembly integrity
- Authored Set Clearance Auditor: corridor, doorway, and stair clearance contracts
- Authored Set Readability Auditor: protected routes, interaction approaches, camera envelopes, and density warnings

## Planning rule

Search the capability inventory using the user's language and aliases, inspect canonical owners, and classify work as integration, authored content, polish, extension, consolidation, or genuinely new. Do not resuggest implemented capabilities as new.

Automated checks prove technical contracts. Nick's manual playtest remains authoritative for feel, clarity, staging, pacing, density, silhouette, and visual quality.
