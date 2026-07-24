# Grace of Humanity Prototype Project Map

This file is a navigation aid for assistant-driven development.

## Godot project

- Engine config: `project.godot`
- Main scene is configured in `project.godot` under `run/main_scene`.
- Autoloads currently include:
  - `GameState`
  - `HitStop`
  - `FullMenuDirector`

## Canonical feature registry

Permanent development scenes and their validation contracts are registered in:

```txt
data/features/feature_registry.json
```

The registry is the source of truth for:

- feature IDs and display order;
- launcher visibility;
- playable and validation scene paths;
- automated test scenes;
- feature-level dependencies;
- maturity/status and version;
- semantic controls;
- temporary-state policy;
- story-integration status;
- manual test documents;
- known limitations.

Do not maintain another hard-coded list of permanent laboratories, arenas, sandboxes, or validation scenes.

Key infrastructure:

```txt
scripts/systems/feature_registry.gd
scripts/ui/development_control_center.gd
scenes/ui/development_control_center_v1.tscn
scripts/ci/validate_feature_registry.py
scripts/ci/run_feature_registry.py
scripts/tests/architecture_contract_smoke_test.gd
scenes/tests/architecture_contract_smoke_test.tscn
docs/feature_registry.md
```

The Development Control Center reads the registry at runtime. The Python validator and GitHub Actions runner read the same JSON. A new permanent feature should require a registry edit, not a workflow-YAML edit.

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
full_menu
quick_item_up / quick_item_left / quick_item_right / quick_item_down
restart_scene
toggle_dev_vision
lock_on / lock_on_previous / lock_on_next
ui_up / ui_down / ui_accept / ui_cancel
```

Development scenes and player-facing instructions should name semantic actions rather than fixed physical buttons:

```txt
INTERACT
LIGHT
HEAVY
FOCUS
CAST
DODGE
MENU
INVENTORY
QUICK ITEM
LOCK-ON
RESET
NAVIGATE
SELECT
BACK
```

The current controller layout may be remapped by the user. `WeaponInputBootstrap` may install missing keyboard/controller categories, but it must not add another joypad binding when `weapon_heavy_attack` already has one.

## Scripts by system

### Player

Expected player component stack:

```txt
Player
├── PlayerActionState
├── PlayerResourceController
├── AbilityCaster
├── WeaponController
│   └── WeaponInputBootstrap
├── PlayerDodgeController
├── PlayerQuickItemController
└── QuickItemBeltUI
```

Key folders:

```txt
scripts/player/
scripts/abilities/
scripts/weapons/
```

`PlayerActionState` owns action locks. Weapon attacks may open data-driven late spell or dodge cancel windows without bypassing casting, dodge, interaction, defeat, or Focus-menu restrictions.

`player_controller_free_aim.gd` also owns temporary collision-respecting combat motion requested by advancing weapon attacks.


#### Quick items and field inventory

`GameState` owns consumable counts, the four assigned item IDs, and collected persistent-pickup IDs. `PlayerQuickItemController` resolves those IDs through `QuickItemCatalog`, executes committed use, and consumes shared stock only after a successful effect or delivery. Two slots assigned to the same item therefore share one count.

Outside Focus and the paused Field Kit, the D-pad directly uses Up, Left, Right, and Down. Focus reserves those directions for spell navigation; the Field Kit reserves them for a spatial tile cursor. The Field Kit presents horizontal icon tabs, visual Loadout/Magic/Items grids, an item detail pane, and a four-direction belt placement cross. Players may assign slot-first from Loadout or item-first from Items. Arrow keys mirror quick-item directions during ordinary keyboard play, and H additionally uses Up.

A committed item use slows movement, blocks attacks, casting, Dodge, Guard, jumping, and interaction, and is interrupted by enemy stagger without consuming stock. Rest refills only definitions marked `refill_on_rest`. Inventory, assignments, and persistent pickup IDs participate in the normal save contract.

Thrown items use one delivery scene and data-selected impact scenes:

```txt
QuickItemDefinition
├── resource restore
└── delivery scene
    └── ThrownQuickItem
        ├── Oil StatusSurface impact
        └── Noise Maker perception stimulus
```

Key files:

```txt
scripts/items/quick_item_definition.gd
scripts/items/quick_item_catalog.gd
scripts/items/thrown_quick_item.gd
scripts/items/world_item_pickup.gd
scripts/items/noise_maker_impact.gd
scripts/player/player_quick_item_controller.gd
scripts/ui/quick_item_belt_ui.gd
scripts/ui/full_menu_director.gd
scripts/ui/full_menu_shell_key_items.gd
scenes/items/
scenes/ui/quick_item_belt_ui.tscn
data/items/healing_flask.tres
data/items/oil_flask.tres
data/items/noise_maker.tres
```

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

`StatCatalog` owns stable IDs, defaults, grouping, descriptions, and elemental-affinity hooks. `GameState` owns current runtime values and emits `stat_changed` plus `resource_depleted`. `PlayerResourceController` turns those shared values into the in-game recovery loop: stamina returns after physical-action expenditure, stance recovers after pressure, and health/mana remain pickup-, rest-, or system-driven.

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
Elemental affinity IDs

DORMANT
Defense, Resilience, Constitution, Evasion
Charisma, Skill, Luck
```

`PARTIAL` means definitions or scaling metadata reference the stat, but no production formula changes damage or timing yet. `DORMANT` means the stable catalog ID exists without an active gameplay reader.

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
scripts/player/player_resource_controller.gd
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

## Registered permanent features

The current registry contains:

```txt
church_trial
    scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn

elemental_reaction_lab
    scenes/levels/prototypes/prototype_elemental_reaction_lab_v1.tscn

weapon_combat_arena
    scenes/levels/prototypes/prototype_weapon_combat_arena_v1.tscn

runtime_stat_lab
    scenes/levels/prototypes/prototype_runtime_stat_lab_v1.tscn

dev_interaction_sandbox
    scenes/levels/_dev/dev_interaction_sandbox.tscn

development_control_center
    scenes/ui/development_control_center_v1.tscn
```

Use the registry for current metadata rather than duplicating version, dependency, status, or test-path details here.

### Church Trial

The integrated player-facing route covers exploration, elemental tests, combat rooms, Sound reveal, Animated Armor, reward, save flow, and exit.

Manual regression:

```txt
docs/church_trial_vertical_slice_test.md
```

### Elemental Reaction Laboratory

Provides:

- Fire, Water, Ice, Lightning, and Sound readability tests;
- target and surface reaction stations;
- resettable status/reaction state;
- permanent recipe-development space.

### Weapon Combat Arena

Provides:

- Sword, Hammer, and Spear equip racks;
- resettable force-aware training targets;
- live Goblin and Gremlin pressure;
- combo phase, buffer, chain, and cancel-window HUD;
- transient hit-volume debugging;
- reset console and editor F8 reset.

### Runtime Stat Laboratory

Provides:

- Stamina and Mana baseline/1000/Infinite controls;
- weapon and spell spend telemetry;
- controlled Health and Stance demonstrations;
- Focus 0/5/10/1000 presets with a visible motion clock;
- a universal selector for every base stat and affinity;
- LIVE/PARTIAL/DORMANT gallery panels;
- exact entry-snapshot reset and safe exit restoration;
- semantic controller-first instructions.

### Dev Interaction Sandbox

Provides a broad disposable workbench for interactables, receivers, surfaces, enemy waves, developer vision, audits, and rapid scenario experiments.

Dedicated laboratories remain authoritative for focused feel and regression judgments.

### Development Control Center

Provides:

- controller-first feature navigation;
- registry-driven descriptions and status;
- dependency and state-policy visibility;
- launch validation and disabled invalid entries;
- one entry point for permanent development scenes.

It is developer infrastructure, not a production level-select menu.

## Development automation

Key files:

```txt
scripts/systems/dev_audit_manager.gd
scripts/systems/dev_sandbox_director.gd
scripts/tests/weapon_moveset_smoke_test.gd
scripts/tests/elemental_reaction_smoke_test.gd
scripts/tests/runtime_stat_lab_smoke_test.gd
scripts/tests/architecture_contract_smoke_test.gd
scripts/ci/validate_agent_profiles.py
scripts/ci/validate_feature_registry.py
scripts/ci/run_feature_registry.py
scripts/ci/validate_project.ps1
```

Current dev loop:

```txt
F6 spawn wave where supported
F7 clear wave where supported
F8 run audit or reset the active dedicated lab/arena
Development Control Center launches registered permanent scenes
```

CI validates:

```txt
custom agent profiles
feature-registry schema, paths, docs, dependencies, and cycles
project import
production main startup
every registered validation scene
every registered automated test
architecture contracts
Windows export
artifact upload
```

The GitHub Actions workflow must not enumerate each laboratory manually. `run_feature_registry.py` discovers CI-enabled scenes and tests from the JSON registry.

The architecture contract test currently checks:

- runtime registry loading and registered resources;
- action-resource current/max pairs;
- semantic UI, interaction, combat, Focus, cast, and dodge inputs;
- Sword, Hammer, and Spear moveset graphs and payload tags;
- starting loadout ability scene/payload references;
- scaling-stat IDs.

## Recommended future automation

### Enemy factory

Goal: let new prototype enemies be generated and configured from data rather than hand-built scene editing.

### Ability factory

Goal: let new spells be created from ability definition, action scene, and payload patterns.

### Weapon moveset factory

Goal: generate a validated attack graph skeleton, payload profile, prototype visual identity, arena rack, registry entry, and test template from a weapon-class specification.

### Stat formula harness

Goal: add production formulas one category at a time and compare baseline, boost, and overcharge behavior in the existing Runtime Stat Laboratory before those formulas enter story scenes.

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

Future factories should write or propose feature-registry entries when they create permanent scenes. They should not silently promote scratch content into the canonical inventory.
