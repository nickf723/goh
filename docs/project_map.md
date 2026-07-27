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

Ruined Village Approach and Church Trial are story-integrated vertical slices. Wilds Expedition owns the five-segment outdoor route and authored Cypress, Wet Woodland, and Pine Ridge layouts. Regional Expedition Map owns route selection and regional persistence. The Drowned Bell is the current composition-first quest proving water, resonance investigation, guidance, global playability, and authored environment contracts.

## Playability and authored-space quality

The reusable playability layer lives under `scripts/quality/` and `scripts/player/player_recovery_controller.gd`. It provides explicit playable bounds, safe recovery transforms, forbidden and recovery volumes, safe destination validation, swimming exit anchors, quest guidance targets, and a structural scene auditor. Space Blink uses the shared safe-destination query, and the shared player retains fallback recovery even in scenes that have not yet declared an explicit `PlayableSpace3D`.

The reusable environment-composition layer lives under `scripts/environment/`. It provides palette-driven prototype materials, collision-matched architectural primitives, stair runs, pillars, archways, non-blocking dressing, local lights, build statistics, and an authored-environment auditor. Level-specific passes retain responsibility for layout, landmarks, sightlines, mood, prop placement, and environmental storytelling.

Architecture and manual quality gates are documented in:

```text
docs/GLOBAL_PLAYABILITY_FRAMEWORK_V1.md
docs/global_playability_framework_v1_test.md
docs/AUTHORED_ENVIRONMENT_COMPOSITION_V1.md
docs/drowned_chapel_environment_v2_2_test.md
```

These frameworks are safety and construction scaffolds, not substitutes for continuous authored collision, natural boundaries, readable sightlines, deliberate composition, or human playtesting.

## Development infrastructure

- Development Control Center: registry-driven launcher
- Systems Integration Hub: cross-system shared-player campus
- Dev Interaction Sandbox: disposable interaction workbench
- Feature registry validator and runner: launcher/CI integrity
- Capability inventory validator: planning memory and resuggestion integrity
- Playable Space Auditor: recovery, water-exit, interaction, and guidance contracts
- Authored Environment Auditor: collision-paired surfaces and assembly integrity

## Planning rule

Search the capability inventory using the user’s language and aliases, inspect canonical owners, and classify work as integration, authored content, polish, extension, consolidation, or genuinely new. Do not resuggest implemented capabilities as new.

Automated checks prove technical contracts. Nick’s manual playtest remains authoritative for feel, clarity, staging, pacing, and visual quality.
