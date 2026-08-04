# Ability Context Layout v1

## Purpose

Some equipped abilities are instant actions. Fireball fires, Blink moves Grace, and a pulse resolves immediately.

Other abilities create persistent gameplay objects that remain relevant after the original cast. Familiar summons, recorded objects, artificer builds, deployable contraptions, vehicles, and similar tools need a second interaction layer after activation.

Ability Context Layout v1 gives those systems one shared controller and UI grammar.

## Player grammar

Outside a context:

- D-pad and the quick spell belt continue selecting abilities normally.
- Cast activates an ordinary ability.
- Cast activates a persistent ability when it has not been created yet.
- Cast opens the selected persistent ability's context when that provider has commands or prepared content.

Inside the context:

- D-pad or right stick selects an action.
- Cast confirms the selected action.
- B / Cancel closes the context without changing state.
- World-targeted actions enter the shared targeting reticle.
- Cast confirms the target.
- B / Cancel abandons targeting.

No subsystem receives a private controller button.

## Runtime pieces

### PlayerAbilityContextRouter

The player-level router observes the authoritative `cast_spell` action before the normal unhandled cast path.

It asks the selected ability's provider whether a context is available. When no provider claims the ability, the input continues to the ordinary caster unchanged.

### PersistentAbilityContextMenu

One CanvasLayer renders:

- persistent context status
- radial action selection
- shared action-state locking
- shared time slowdown
- world targeting and placement marker
- controller, keyboard, and mouse confirmation/cancellation

It extends the original AbilityContextMenu with refreshable actions. A provider can return:

```gdscript
{
    "ok": true,
    "keep_open": true,
    "selected_id": "place_part",
}
```

The menu then asks the provider for a fresh context specification without releasing the modal. Blueprint cycling, part cycling, undo, and clear operations therefore update in place instead of requiring another Cast press.

### Provider contract

A persistent subsystem can participate by implementing:

```gdscript
func can_handle_ability_context(ability: AbilityDefinition) -> bool
func is_ability_context_available(ability: AbilityDefinition) -> bool
func has_active_ability_context() -> bool
func get_ability_context_spec(ability: AbilityDefinition) -> Dictionary
func execute_ability_context_action(action_id: String, payload: Variant) -> Dictionary
func get_ability_context_status() -> Dictionary
```

The context specification returns action dictionaries with these common fields:

```gdscript
{
    "id": "move_to",
    "label": "Go There",
    "description": "Move to an aimed world position.",
    "target_mode": "world",
    "enabled": true,
}
```

`target_mode = "world"` routes through the shared world-targeting phase. Other action types can be added without changing the player controller.

## Familiar provider

Summon Familiar follows this lifecycle:

1. Select Summon Familiar.
2. Press Cast with no familiar active to summon the prepared familiar.
3. Switch to another spell and cast normally while the familiar remains active.
4. Return to Summon Familiar and press Cast to open its context.
5. Choose Follow, Stay Here, Come Here, Go There, supported combat commands, or Dismiss Familiar.

Dismiss is an explicit menu action and does not start the familiar defeat cooldown.

The previous L3-specific familiar interface remains available only as an opt-in legacy development surface. It is not installed for normal players.

## Recorded Object provider

Selecting Reproduce Object and pressing Cast opens the global context whenever Grace has at least one recorded blueprint.

Actions include:

- place the prepared recorded object through shared world targeting
- previous and next recorded blueprint with in-place menu refresh
- Advanced Placement for the existing depth and rotation workflow
- Recall Last for the most recently reproduced object
- Dismiss All for every active reproduced object

The manager's original placement mode remains intact for precision work and development testing. The global context is the ordinary gameplay front door.

## Artificer Assembly provider

Selecting Artificer Assembly and pressing Cast opens a draft-management context.

Actions include:

- attach the prepared part through shared world targeting
- previous and next unlocked engineering part
- undo the latest part
- clear the current draft
- save a draft with at least two connected parts into the prepared custom slot
- Advanced Assembly for the original continuous depth and rotation workflow

Saving through the context creates the blueprint without automatically manifesting it. Deploy Contraption remains the explicit deployment spell.

## Deploy Contraption provider

Selecting Deploy Contraption and pressing Cast opens a blueprint and active-contraption context whenever at least one build is saved.

Actions include:

- deploy the prepared blueprint through shared world targeting
- previous and next saved blueprint, including custom slots
- Advanced Deployment for the original continuous placement workflow
- Recall Last for the most recently deployed contraption
- Dismiss All for every active contraption

## Regression

`res://scenes/tests/persistent_ability_context_providers_smoke_test.tscn` verifies:

- one shared context menu serves all three providers
- provider selection actions refresh without closing
- recorded objects place and recall through the shared layout
- Artificer parts assemble into a saved custom blueprint
- the saved blueprint deploys and recalls through the same layout
- advanced placement actions remain available

## Intended next providers

The next systems that should adopt this contract are:

- persistent terrain or bridge summons
- vehicle and mount deployment
- controllable gadgets and turrets
- weather or field spells with persistent controls
- any future ability that creates an owned world object with follow-up actions
