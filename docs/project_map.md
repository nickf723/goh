# Grace of Humanity Prototype Project Map

This file is a navigation aid for assistant-driven development.

## Godot project

- Engine config: `project.godot`
- Main scene is configured in `project.godot` under `run/main_scene`.
- Autoloads currently include:
  - `GameState`
  - `HitStop`

## Input actions

Core actions currently include:

```txt
move_forward
move_back
move_left
move_right
interact
jump
dodge
cast_spell
weapon_light_attack
ability_slot_1 ... ability_slot_0
next_ability
spell_menu
restart_scene
toggle_dev_vision
```

## Scripts by system

### Player

Expected player component stack:

```txt
Player
├── PlayerActionState
├── AbilityCaster
├── WeaponController
└── PlayerDodgeController
```

Key folders:

```txt
scripts/player/
scripts/abilities/
scripts/weapons/
```

### Combat and payloads

Core grammar:

```txt
Actor → Tool → Action → Payload → Target → Receiver → Reaction → Consequence
```

Key folders:

```txt
scripts/combat/
scripts/actions/
scripts/systems/reaction_resolver.gd
```

Common receiver stack:

```txt
PayloadReceiver
HitReceiver
StatusReceiver
ForceReceiver
TagComponent
RevealableReceiver optional
```

### Enemies

Expected enemy stack:

```txt
EnemyRoot
├── EnemyBrain
├── EnemyTelegraph
├── PayloadReceiver
├── HitReceiver
├── StatusReceiver
├── ForceReceiver
└── TagComponent
```

Key folders:

```txt
scripts/enemies/
data/enemies/
data/enemy_attacks/
scenes/actors/enemies/
```

Current enemy pattern:

- Goblin and Gremlin use the same brain stack.
- Differences should be mostly in `EnemyDefinition`, `EnemyAttackDefinition`, `DamagePayload`, hit stats, and visuals.

### Detection

Key folders:

```txt
scripts/detection/
data/detection_payloads/
```

Sound Pulse uses detection payloads and revealable receivers.

### Surfaces and reactions

Key folders:

```txt
scripts/surfaces/
scripts/systems/reaction_resolver.gd
```

Known interactions:

```txt
oil + fire -> burning
wet + lightning -> stunned
wet + ice -> frozen
frozen + force -> shatter
wet cleans oily/burning through status conflict logic
```

### Development automation

Key files:

```txt
scripts/systems/dev_audit_manager.gd
scripts/systems/dev_sandbox_director.gd
```

Current dev loop:

```txt
F6 spawn wave
F7 clear wave
F8 run audit
```

## Recommended future automation

### Enemy factory

Goal: let new prototype enemies be generated/configured from data rather than hand-built scene editing.

### Ability factory

Goal: let new spells be created from ability definition + action scene + payload patterns.

### Receiver installer

Goal: quickly add and verify standard component stacks to enemies, objects, props, and puzzle targets.

### Test scenario director

Goal: spawn named test scenarios without building full rooms first.

Example future commands:

```txt
spawn_test("zombie_duel")
spawn_test("oil_fire_reaction")
spawn_test("sound_reveal_puzzle")
```
