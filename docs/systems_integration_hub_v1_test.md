# Systems Integration Hub v1 Manual Test

Run:

```text
res://scenes/levels/prototypes/prototype_systems_integration_hub_v1.tscn
```

## Purpose

The hub is the shared integration campus for mechanics that need to coexist on one persistent Player instance. Dedicated laboratories remain authoritative for focused tuning.

## Core route

1. Confirm Grace spawns at the central console with normal movement, camera, HUD, equipment, resources, and casting available.
2. Use the station shortcuts to visit Combat and Mastery, Aerial Reactions, Movement, Interaction, and Status and Ability Range.
3. Confirm each station has visible fixtures rather than invisible state-only triggers.
4. Fight the live enemies and confirm weapons, lock-on, defense, abilities, health, stamina, mana, stance, and mastery operate together.
5. Test launch, juggle, and aerial follow-through against the aerial targets.
6. Traverse the movement course and confirm Dodge, jump, aerial locomotion, and collision remain stable.
7. Use the interaction fixtures and confirm ordinary INTERACT prompts and responses appear.
8. Toggle the temporary all-unlocked state and confirm equipment, mastery, techniques, and unlocks become available.
9. Reset the hub and confirm Grace, resources, targets, and enemies return to the entry baseline.
10. Leave the scene and confirm the exact entry progression snapshot is restored.

## Quality checks

- Station labels and travel destinations are readable.
- No station silently mutates production progression.
- Freed enemies do not leave stale lock-on or weapon targets.
- New mechanics should receive a visible station fixture and reset path before this hub is considered their integration owner.

## Known limitations

- The hub does not contain every repository capability.
- Dedicated laboratories remain the primary location for detailed physics and presentation judgment.
- Geometry and fixtures are development presentation, not final world art.
