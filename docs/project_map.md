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
weapon_heavy_attack
ability_slot_1 ... ability_slot_0
next_ability
spell_menu
restart_scene
toggle_dev_vision
lock_on / lock_on_previous / lock_on_next
```

Development scenes and player-facing instructions should name semantic actions rather than fixed physical buttons:

```txt
INTERACT
LIGHT
HEAVY
FOCUS
CAST
DODGE
LOCK-ON
RESET
```

The current controller layout may be remapped by the user. `WeaponInputBootstrap` may install missing keyboard/controller categories, but it must not add another joypad binding when `weapon_heavy_attack` already has one.

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

### Stats and runtime resources

`StatCatalog` owns stable ids, defaults, grouping, descriptions, and elemental-affinity hooks. `GameState` owns the current runtime values and emits `stat_changed`.

Current action-resource pairs:

```txt
health / max_health
stamina / max_stamina
mana / max_mana
stance / max_stance
```

Current implementation classes used by the Runtime Stat Laboratory:

```txt
LIVE
Health, Stamina, Mana, Stance, Focus

PARTIAL
Power, Dexterity, Arcana, Intelligence
Elemental affinity ids

DORMANT
Defense, Resilience, Constitution, Evasion
Charisma, Skill, Luck
```

`PARTIAL` means definitions or scaling metadata reference the stat, but no production formula changes damage/timing yet. `DORMANT` means the stable catalog id exists without an active gameplay reader.

The reusable temporary test-session stack is:

```txt
RuntimeStatLabSession
├── entry GameState stat snapshot
├── baseline / 10 / 1000 mutation
├── current+maximum resource-pair mutation
├── infinite-resource refill
├── LIVE / PARTIAL / DORMANT classification
├── exact reset
└── tree-exit / scene-exit cleanup
```

Key files:

```txt
scripts/systems/stat_catalog.gd
scripts/systems/game_state.gd
scripts/systems/runtime_stat_lab_session.gd
scripts/interaction/stat_lab_station.gd
scripts/levels/prototype_runtime_stat_lab.gd
scenes/actors/interactables/stat_lab_station.tscn
scenes/levels/prototypes/prototype_runtime_stat_lab_v1.tscn
scripts/tests/runtime_stat_lab_smoke_test.gd
```

Stat-lab values are runtime-only. The session must restore the exact entry snapshot, Infinite modes, action locks, invulnerability, lock-on, combat motion, and `Engine.time_scale` before leaving. It must not call save APIs or create a parallel stat store.

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
scenes/levels/prototypes/prototype_runtime_stat_lab_v1.tscn
```

The Elemental Reaction Laboratory provides:

- Fire, Water, Ice, Lightning, and Sound readability tests;
- target and surface reaction stations;
- resettable status/reaction state;
- permanent recipe-development space.

The Weapon Combat Arena provides:

- Sword, Hammer, and Spear equip racks;
- resettable force-aware training targets;
- live Goblin and Gremlin pressure;
- combo phase, buffer, chain, and cancel-window HUD;
- transient hit-volume debugging;
- reset console and editor F8 reset.

The Runtime Stat Laboratory provides:

- Stamina and Mana baseline/1000/Infinite controls;
- weapon and spell spend telemetry;
- controlled Health and Stance demonstrations;
- Focus 0/5/10/1000 presets with a visible motion clock;
- a universal selector for every base stat and affinity;
- LIVE/PARTIAL/DORMANT gallery panels;
- exact entry-snapshot reset and safe exit restoration;
- semantic controller-first instructions.

### Development automation

Key files:

```txt
scripts/systems/dev_audit_manager.gd
scripts/systems/dev_sandbox_director.gd
scripts/tests/weapon_moveset_smoke_test.gd
scripts/tests/elemental_reaction_smoke_test.gd
scripts/tests/runtime_stat_lab_smoke_test.gd
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
Runtime Stat Laboratory startup and stat-session restoration
Windows export
```

## Recommended future automation

### Enemy factory

Goal: let new prototype enemies be generated/configured from data rather than hand-built scene editing.

### Ability factory

Goal: let new spells be created from ability definition + action scene + payload patterns.

### Weapon moveset factory

Goal: generate a validated attack graph skeleton, payload profile, prototype visual identity, and arena rack from a weapon-class specification.

### Stat formula harness

Goal: add production formulas one category at a time and compare baseline/boost/overcharge behavior in the existing Runtime Stat Laboratory before those formulas enter story scenes.

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
spawn_test("stamina_overcharge_combo")
```
