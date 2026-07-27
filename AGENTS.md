# Grace of Humanity Agent Guide

This repository is the playable Godot prototype for **Grace of Humanity**. Agents should help Nick turn creative direction into small, testable vertical slices without silently expanding scope.

## North star

Build the first playable target before expanding the full mythology. Prefer one complete, readable player experience over several disconnected systems.

Core gameplay grammar:

```text
Actor → Tool → Action → Payload → Target → Receiver → Reaction → Consequence
```

Reuse this grammar and existing components before adding parallel systems.

## Working agreement

- Work from one bounded issue at a time.
- Implement the smallest complete vertical slice that satisfies the issue.
- Do not add adjacent features merely because they seem useful.
- Do not rewrite functioning systems unless the issue requires it.
- Prefer data-driven definitions and reusable components over one-off scene logic.
- Preserve player-facing behavior outside the issue scope.
- Add or update a manual test document for player-facing changes.
- Register every permanent development scene in `data/features/feature_registry.json`.
- Add every genuinely new reusable mechanic to `data/features/capability_inventory.json`.
- Search the capability inventory before proposing a mechanic, framework, laboratory, or progression system.
- When a capability already exists, propose authored use, integration, polish, extension, or consolidation instead of presenting it as new.
- Surface uncertainty in the pull request instead of guessing at creative intent.

## Creative approval boundary

Stop and return the decision to Nick when work would materially change:

- story, canon, character motivation, tone, or worldbuilding;
- final visual identity, animation style, audio direction, or level mood;
- player progression, spell identity, balance philosophy, or difficulty;
- the core gameplay grammar or a major architectural boundary;
- the intended scope of a milestone or vertical slice.

Agents may choose ordinary implementation details when they preserve the approved player experience.

## Repository map

Read these in order before planning or building:

```text
docs/REPOSITORY_AUDIT.md                 current capability and lifecycle map
data/features/capability_inventory.json   machine-readable planning memory and aliases
docs/project_map.md                       architecture and folder guide
data/features/feature_registry.json       canonical permanent-scene and CI inventory
```

The repository audit supersedes stale capability descriptions in the older project map. The feature registry remains authoritative for launchable permanent scenes and validation.

Important paths include:

```text
project.godot                              Godot project configuration and inputs
data/features/feature_registry.json        canonical permanent-feature inventory
data/features/capability_inventory.json    canonical mechanic and ownership inventory
scripts/systems/feature_registry.gd        Godot registry reader and runtime health
scripts/ci/validate_feature_registry.py    static registry validation
scripts/ci/validate_capability_inventory.py planning-memory validation
scripts/ci/run_feature_registry.py         registry-driven Godot scene/test runner
scripts/player/                            player behavior and controllers
scripts/abilities/                         ability definitions and casting
scripts/actions/                           delivery/action implementations
scripts/combat/                            payloads, hit processing, and combat data
scripts/enemies/                           enemy behavior
scripts/surfaces/                          elemental surfaces
scripts/systems/reaction_resolver.gd       shared reaction logic
scenes/actors/                             reusable actors and interactables
scenes/levels/prototypes/                  vertical-slice and test scenes
data/                                      data-driven definitions and payloads
docs/                                      architecture notes and manual test plans
```

Expected reusable component patterns are documented in `docs/project_map.md`. Extend those patterns rather than bypassing them.

Read `docs/feature_registry.md` before adding a permanent laboratory, arena, sandbox, vertical slice, or infrastructure scene. The registry is the shared source for the Development Control Center and CI. Do not add the same scene to a second hard-coded validation list.

## Capability discovery protocol

Before suggesting or implementing a system:

1. Search `data/features/capability_inventory.json` using the user’s terminology and likely aliases.
2. Inspect the listed owner files and canonical scene.
3. Decide whether the request is integration, authored content, polish, extension, consolidation, or a genuinely new capability.
4. State which existing systems will be reused.
5. Update the inventory in the same change only when ownership, maturity, aliases, or implemented scope materially changes.

An implemented capability with `do_not_resuggest: true` must never be proposed as though the repository does not contain it.

## Agent modes

### Plan

Planning work may inspect the repository and produce an issue-ready implementation plan. It should identify:

- the player-facing goal;
- existing systems to reuse;
- affected files or folders;
- acceptance criteria;
- risks and creative decisions;
- explicit out-of-scope items.

Planning work does not modify production code.

### Build

Building work may modify `main` directly when Nick's standing direct-main authorization applies, or it may create a feature branch and open a draft pull request when review isolation is useful. It must remain inside the approved issue and document how Nick can playtest the result.

When a build creates or promotes a permanent development scene, it must add the scene, its tests, its manual test path, its dependencies, and its state policy to the feature registry in the same pull request.

When a build adds a genuinely new reusable capability, it must add its canonical owner, aliases, lifecycle, maturity, canonical scene, and resuggestion policy to the capability inventory in the same change.

### Review

Review work compares a pull request with its issue and checks correctness, scope, architecture reuse, regressions, and testability. The reviewer should not approve its own implementation merely because checks pass.

Reviewers should reject permanent development scenes that are missing a registry entry or register nonexistent tests, documentation, dependencies, or scene paths.

Reviewers should reject new frameworks or mechanics that duplicate an implemented capability or omit a capability-inventory update.

## Specialist team

Custom agent profiles live in `.github/agents/`:

- **GoH Dispatcher** routes broad requests to the correct stage and specialist.
- **GoH Planner** creates issue-ready plans without changing production code.
- **GoH Builder** implements one approved issue on an agent branch.
- **GoH QA** reproduces bugs and strengthens tests, validation, and debug scenarios.
- **GoH Reviewer** independently checks pull requests without editing them.

Read `docs/agents/team.md` for routing and `docs/agents/handoff_contract.md` before passing work between specialists.

Do not add another specialist merely because the project has grown. Add a role only when a stable, non-overlapping responsibility cannot be expressed through the current Dispatcher, Planner, Builder, QA, or Reviewer workflow.

## Branch and pull request rules

- Nick has granted standing permission for agents to commit and push directly to `main` during solo development work. Direct-to-main is the default when he asks to build or fix something without requesting a branch or review.
- Use an `agent/<short-description>` branch and a draft pull request instead when Nick requests review, multiple contributors may overlap, or the work is destructive, unusually risky, experimental, or difficult to reverse.
- Before direct-main work, confirm the latest `main`, keep the change bounded, use concise commits, and run the relevant validation. Never force-push or rewrite `main` history.
- Keep unrelated cleanup out of every commit and feature pull request.
- Do not merge your own pull request.
- Pull requests must include player-facing results, changed systems, validation, manual test steps, known limitations, creative review points, and explicitly unchanged behavior.

## Definition of done

A task is done only when:

- acceptance criteria are satisfied;
- the project imports and starts headlessly when CI supports it;
- relevant automated checks pass;
- manual playtest instructions exist for player-facing changes;
- permanent scenes and tests are represented accurately in the feature registry;
- genuinely new or materially changed capabilities are represented accurately in the capability inventory;
- the pull request explains limitations and unresolved decisions;
- no unrelated behavior was intentionally changed.

A passing automated check proves technical health, not fun. Nick's playtest is the final authority on feel, clarity, and creative quality.

## Validation

CI uses a headless Godot smoke test driven by the feature registry. Locally, run:

```powershell
python scripts/ci/validate_feature_registry.py
python scripts/ci/validate_capability_inventory.py
./scripts/ci/validate_project.ps1
```

The feature registry validator checks schema, duplicate IDs, paths, documentation, statuses, dependencies, and cycles. The capability validator checks planning IDs, lifecycle values, aliases, owners, and resuggestion policy. The full project validator imports the project, starts the production main scene, then boots every registered validation scene and runs every registered automated test.

Record any validation that could not be run, including the reason.

## Safety rails

Do not:

- commit generated imports, editor caches, secrets, or local save data;
- add external dependencies without approval;
- delete or rename major systems to make a narrow task easier;
- duplicate an existing payload, receiver, status, reaction, quest framework, mechanic, or laboratory under a new name;
- create a parallel list of permanent prototype scenes outside the feature registry;
- claim a scene was manually tested when it was not;
- turn prototype art into an implied final art direction.
