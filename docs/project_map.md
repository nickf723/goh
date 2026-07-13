# Grace of Humanity Prototype Project Map

This file is a navigation aid for assistant-driven development.

## Godot project

- Engine config: `project.godot`
- Main scene is configured in `project.godot` under `run/main_scene`.
- Autoloads currently include:
  - `GameState`
  - `HitStop`
  - `FullMenuDirector`

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
weapon_heavy_attack (installed at runtime by WeaponInputBootstrap when absent)
ability_slot_1 ... ability_slot_0
next_ability
spell_menu
restart_scene
toggle_dev_vision
lock_on / lock_on_previous / lock_on_next (installed at runtime when absent)
```

Current prototype weapon controls:

```txt
J / left mouse       Light attack
K / right shoulder   Heavy attack
```

## Scripts by system

### Player

Expected player component stack:

```txt
Player
├── PlayerActionState
├── AbilityCaster
├── WeaponController
│   └── WeaponInputBootstrap
└── PlayerDodgeController
```

Key folders:

```txt
scripts/player/
scripts/abilities/
scripts/weapons/
```

`PlayerActionState` owns action locks. Weapon attacks may open data-driven late spell or dodge cancel windows without bypassing casting, dodge, interaction, defeat, or Focus-menu restrictions.

`player_controller_free_aim.gd` also owns temporary collision-respecting combat motion requested by advancing weapon attacks.

### Weapon combat

The reusable weapon stack is:

```txt
WeaponDefinition
└── WeaponMovesetDefinition
    ├── entry Light attack id
    ├── entry Heavy attack id
    └── WeaponAttackDefinition[]
        ├── timing and cancel windows
        ├── attack geometry
        ├── movement
        ├── payload modifiers and tags
        ├── Light / Heavy branch ids
        └── feedback and prototype pose data
```

Runtime flow:

```txt
Input
→ WeaponController buffer
→ Moveset graph branch
→ startup / active / recovery
→ DamagePayload
→ standard receiver stack
→ reaction / consequence
```

Key files and folders:

```txt
scripts/weapons/weapon_attack_definition.gd
scripts/weapons/weapon_moveset_definition.gd
scripts/weapons/weapon_definition.gd
scripts/weapons/weapon_controller.gd
data/weapon_movesets/
data/weapons/
data/damage_payloads/
```

Current proof classes:

```txt
Practice Sword   balanced four-Light tree with Heavy at neutral and every Light step
Training Hammer  committed broad force and stance pressure
Training Spear   long narrow thrusts and advancing precision
```

Add future weapon classes through data first. Do not add class-specific conditionals to `WeaponController` unless the shared attack grammar truly cannot express the mechanic.

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
data/combo_rules/
```

Known interactions:

```txt
oil + fire -> burning
wet + lightning -> stunned
wet + ice -> frozen
frozen + force -> shatter
fire + frozen -> steam
wet cleans oily/burning through status conflict logic
sound detection -> reveal
```

Weapon attacks participate through ordinary payload tags such as `force`, `blunt`, `pierce`, `light`, and `heavy`. They should not call reaction rules directly.

### Prototype laboratories and arenas

Permanent development scenes currently include:

```txt
scenes/levels/prototypes/prototype_elemental_reaction_lab_v1.tscn
scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn
```

The weapon arena provides:

- Sword, Hammer, and Spear equip racks;
- resettable force-aware training targets;
- live Goblin and Gremlin pressure;
- combo phase, buffer, chain, and cancel-window HUD;
- transient hit-volume debugging;
- reset console and editor F8 reset.

### Development automation

Key files:

```txt
scripts/systems/dev_audit_manager.gd
scripts/systems/dev_sandbox_director.gd
scripts/tests/weapon_moveset_smoke_test.gd
scripts/tests/elemental_reaction_smoke_test.gd
```

Current dev loop:

```txt
F6 spawn wave
F7 clear wave
F8 run audit or reset the active dedicated lab/arena
```

CI validates:

```txt
project import
main startup
Church Trial startup
Elemental Reaction Lab startup and recipes
Weapon Combat Arena startup and moveset graphs
Windows export
```

## Recommended future automation

### Enemy factory

Goal: let new prototype enemies be generated/configured from data rather than hand-built scene editing.

### Ability factory

Goal: let new spells be created from ability definition + action scene + payload patterns.

### Weapon moveset factory

Goal: generate a validated attack graph skeleton, payload profile, prototype visual identity, and arena rack from a weapon-class specification.

### Receiver installer

Goal: quickly add and verify standard component stacks to enemies, objects, props, and puzzle targets.

### Test scenario director

Goal: spawn named test scenarios without building full rooms first.

Example future commands:

```txt
spawn_test("zombie_duel")
spawn_test("oil_fire_reaction")
spawn_test("sound_reveal_puzzle")
spawn_test("hammer_shatter_trial")
```
