# Dev Interaction Sandbox Test

## Scene

```text
scenes/levels/_dev/dev_interaction_sandbox.tscn
```

## Purpose

The Dev Interaction Sandbox is a disposable, broad-scope workbench for quickly checking shared components before they are placed into a designed room.

It is intentionally less polished and less deterministic than the dedicated Reaction, Weapon, and Stat laboratories.

## Startup checks

- The scene opens without parser or missing-resource errors.
- Grace, camera, UI, Focus, AbilityCaster, and WeaponController are active.
- The training dummy, Church Finder, Mana Shrine, cracked crystal, gate, exit, water, and oil are present.
- Goblin and Gremlin wave scenes can be instantiated.

## Interaction checks

1. Interact with the Church Finder.
2. Use the Mana Shrine.
3. Damage and break the cracked crystal.
4. Exercise the magic gate and level exit.
5. Confirm interaction prompts and result messages reach the UI.

## Combat and reaction checks

- Strike the training dummy with LIGHT and HEAVY attacks.
- Cast several spells and confirm payload delivery.
- Apply Water and Oil states.
- Trigger at least one elemental reaction.
- Confirm status, force, hit, and health receivers continue to cooperate.

## Development controls

Use the semantic actions provided by the active input map:

```text
DEV VISION
SPAWN WAVE
CLEAR WAVE
AUDIT
RESET where supported
```

The current project commonly maps wave and audit actions to F6, F7, and F8 in editor builds, but sandbox instructions should not treat those physical keys as permanent player controls.

## Wave checks

1. Spawn a Goblin and Gremlin wave.
2. Confirm enemies acquire and pursue Grace.
3. Clear the wave.
4. Spawn another wave and confirm no stale references prevent reuse.

## Audit checks

- Run the development audit.
- Review missing receiver, tag, payload, or debug-contract warnings.
- Confirm the audit does not alter progression or save data.

## Known limitations

- The sandbox mixes systems from different prototype generations.
- Placement and encounter composition are not a level-design claim.
- Temporary sandbox state is disposable.
- Dedicated laboratories remain the authoritative feel tests for reactions, weapon combat, and stats.
