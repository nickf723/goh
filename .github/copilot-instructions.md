# Grace of Humanity repository instructions

This is a Godot 4.6 GDScript prototype for **Grace of Humanity**. Read `AGENTS.md` and `docs/project_map.md` before planning or editing.

## Architecture

The core mechanic grammar is:

```text
Actor → Tool → Action → Payload → Target → Receiver → Reaction → Consequence
```

Reuse existing data definitions, actions, payloads, receivers, status logic, reaction rules, component stacks, menu patterns, and prototype materials before creating new systems. Prefer data-driven resources and reusable components over one-off scene logic.

## Scope

Work from one bounded issue at a time. Implement the smallest complete vertical slice that satisfies its observable acceptance criteria. Do not expand scope, perform unrelated cleanup, rewrite functioning adjacent systems, or introduce permanent story, art, progression, or balance decisions.

Nick is the creative director. Escalate choices involving player fantasy, story, canon, permanent visual/audio direction, progression philosophy, difficulty, or milestone scope.

## Repository navigation

- `project.godot`: engine configuration, autoloads, inputs, and main scene
- `scripts/player/`: player controllers
- `scripts/abilities/`: ability definitions and casting
- `scripts/actions/`: delivery methods
- `scripts/combat/`: payload and hit systems
- `scripts/enemies/`: enemy behavior
- `scripts/surfaces/`: elemental surfaces
- `scripts/systems/reaction_resolver.gd`: shared reaction rules
- `scenes/actors/`: reusable actors and interactables
- `scenes/levels/prototypes/`: playable test slices
- `data/`: data-driven definitions
- `docs/`: architecture and manual test documents

## Validation

Use Godot 4.6. Every production change must preserve successful headless import and startup:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 5
```

On Windows, the repository helper is:

```powershell
./scripts/ci/validate_project.ps1
```

Add or update a focused manual test document for player-facing changes. Never claim a visual, controller, audio, or feel test was performed when it was not.

## Git workflow

Branch from current `main` as `agent/<short-description>`. Never push directly to `main`. Open a draft pull request by default, use the repository PR template, inspect the final diff for unrelated changes, and never merge your own work.

Trust these instructions and search only when the needed repository detail is missing or contradicted by the code.
