# Repository Consolidation Backlog

Last reviewed: 2026-07-27

This backlog records repository-health work discovered during the capability audit. It is not a feature roadmap. Complete these items when they directly improve discoverability, ownership, or safe reuse.

## Priority A: canonical inventory alignment

### Promote missing permanent scenes into the feature registry

Confirm and register the permanent scenes that were added after the July 24 registry update, including at minimum:

- Systems Integration Hub
- Wilds Expedition
- Regional Expedition Map
- Authored Wilds Segments
- Airborne Presentation Laboratory
- Broken Waystation / Relay Response

For each promoted scene, record:

- stable feature ID;
- canonical scene;
- focused tests;
- dependencies;
- manual test document;
- temporary-state policy;
- story-integration status;
- current limitations.

The feature registry remains the launcher and CI source of truth. The capability inventory is not a substitute for registry promotion.

### Reconcile project map with the audit

Regenerate or rewrite `docs/project_map.md` so it:

- links to `docs/REPOSITORY_AUDIT.md` and `data/features/capability_inventory.json` near the top;
- lists the current player component stack;
- updates weapon combat to include guard, aerial techniques, airborne reactions, and mastery;
- documents authored quest framework ownership;
- removes the obsolete six-feature permanent-scene list;
- points readers to the registry for the live list rather than duplicating it.

## Priority B: canonical owner cleanup

### Broken Waystation inheritance chain

Current behavior is intentionally layered to preserve a working authored quest. Audit these scripts before the next major change to the quest:

```text
prototype_broken_waystation_mission.gd
prototype_broken_waystation_relay_response.gd
prototype_broken_waystation_consequence.gd
prototype_broken_waystation_framework_integration.gd
```

Goal:

- preserve one canonical playable scene;
- keep reusable quest framework components separate;
- collapse scene-specific wrappers only when the quest is already being modified for player-facing reasons;
- avoid a cleanup-only rewrite that risks the polished encounter.

### Ability caster wrapper history

Audit obsolete wrappers left behind by the transition to registries, especially old Time Snare and Dream Trap caster layers.

Goal:

- keep `ground_targeting_controller.gd` and `ground_spell_registry.gd` canonical;
- retain compatibility only where a live scene still depends on it;
- mark superseded wrappers clearly before deletion.

### Safe weapon controller

Confirm `SafeWeaponController` remains a narrow compatibility layer and determine whether its validity guards should eventually move into the canonical `WeaponController`.

Do not merge the layer solely for aesthetic cleanliness. Move it only alongside focused stale-target regression coverage.

## Priority C: laboratory ownership

### Integration Hub scope

The Systems Integration Hub is a broad integration campus, not the authoritative owner of every mechanic.

Maintain this rule:

- dedicated laboratories own isolated tuning and regression;
- the hub proves selected systems coexist on one shared player;
- authored quests prove systems create good game experiences;
- absence from the hub does not mean a capability is absent from the repository.

### Identify duplicate labs

For each mechanic family, choose one canonical development scene in `capability_inventory.json`. Classify other scenes as:

- supporting demonstration;
- integrated encounter;
- superseded laboratory;
- scratch.

Do not delete scenes until registry references, manual docs, and live dependencies are checked.

## Priority D: historical pull requests

Several stacked or superseded PRs remain open even when equivalent commits landed on `main`.

Audit open PRs by comparing their head with current `main`, then label or close them as:

- landed on main;
- superseded by later implementation;
- contains unique unmerged work;
- historical dependency chain.

High-noise families include:

- Physical Interaction → Circuits → Thermal → Machinery → Fluids
- Element VFX → Lightning → Fire → Ice
- Enemy Personality restoration branches

Do not merge old stacked PRs merely to make the list shorter. Current `main` is the source of truth.

## Priority E: authored integration opportunities

These systems are implemented but underused in story content:

- thermal and pressure machinery;
- circuits and conductive water;
- buoyancy and currents;
- structural stress and flexible tethers;
- portals and resonance;
- weather and environmental sources;
- enemy personality and threat-aware defense;
- climbing, riding, swimming, summons, and stealth.

Future milestones should usually integrate one or two of these into an authored quest or puzzle rather than expand their laboratory foundations.

## Completed in Consolidation v1

- Added `docs/REPOSITORY_AUDIT.md`.
- Added `data/features/capability_inventory.json`.
- Added `scripts/ci/validate_capability_inventory.py`.
- Updated `AGENTS.md` with a mandatory capability-discovery protocol.
- Established `do_not_resuggest` as the planning contract for implemented capabilities.
- Recorded canonical scenes and owner areas for the major mechanic families.

## Definition of consolidation done

Repository consolidation is healthy when:

- every reusable mechanic has one capability entry;
- every permanent scene has one feature-registry entry;
- every capability names canonical owners and aliases;
- planning begins from the audit rather than conversational memory;
- implemented capabilities are not repeatedly proposed as new;
- authored content becomes the dominant form of new work.
