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
- Cast opens the persistent ability's context when that selected ability already owns an active context.

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

It asks the selected ability's provider whether an active context is available. When no provider claims the ability, the input continues to the ordinary caster unchanged.

### AbilityContextMenu

One CanvasLayer renders:

- persistent context status
- radial action selection
- shared action-state locking
- shared time slowdown
- world targeting and placement marker
- controller, keyboard, and mouse confirmation/cancellation

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

## Familiar implementation

Summon Familiar now follows this lifecycle:

1. Select Summon Familiar.
2. Press Cast with no familiar active to summon the prepared familiar.
3. Switch to another spell and cast normally while the familiar remains active.
4. Return to Summon Familiar and press Cast to open its context.
5. Choose Follow, Stay Here, Come Here, Go There, supported combat commands, or Dismiss Familiar.

Dismiss is an explicit menu action and does not start the familiar defeat cooldown.

The previous L3-specific familiar interface remains available only as an opt-in legacy development surface. It is not installed for normal players.

## Intended next providers

The same layout should next be adopted by:

- Recorded Object Summon
- Artificer Assembly
- Deploy Contraption
- persistent terrain or bridge summons
- vehicle and mount deployment
- controllable gadgets and turrets

Each provider should supply its own actions while retaining the same player grammar.