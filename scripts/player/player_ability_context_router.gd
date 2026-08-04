extends Node
class_name PlayerAbilityContextRouter

signal context_provider_resolved(provider: Node, ability: AbilityDefinition)
signal context_open_failed(ability: AbilityDefinition, reason: String)

const AbilityContextMenuScript = preload(
	"res://scripts/ui/persistent_ability_context_menu_unified.gd"
)
const SharedPlacementControllerScript = preload(
	"res://scripts/player/player_shared_placement_controller_unified.gd"
)
const ActiveAbilityRibbonScript = preload(
	"res://scripts/ui/player_active_ability_ribbon_unified.gd"
)
const RecordedObjectSpellControllerScript = preload(
	"res://scripts/player/player_recorded_object_spell_controller.gd"
)
const ArtificerSpellControllerScript = preload(
	"res://scripts/player/player_artificer_spell_controller.gd"
)
const CONTEXT_DPAD_ACTIONS: Dictionary = {
	&"ui_up": JOY_BUTTON_DPAD_UP,
	&"ui_down": JOY_BUTTON_DPAD_DOWN,
	&"ui_left": JOY_BUTTON_DPAD_LEFT,
	&"ui_right": JOY_BUTTON_DPAD_RIGHT,
}

var actor: Node3D
var context_menu: Node
var shared_placement_controller: Node
var active_ability_ribbon: Node
var ability_caster: Node
var action_state: PlayerActionState
var open_requests: int = 0
var successful_opens: int = 0
var intercepted_casts: int = 0
var last_provider_name: String = "none"
var last_ability_id: String = "none"


func _ready() -> void:
	actor = get_parent() as Node3D
	if actor != null:
		ability_caster = actor.get_node_or_null("AbilityCaster")
		action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	_ensure_context_providers()
	_ensure_dpad_navigation_actions()
	add_to_group("ability_context_routers")
	add_to_group("debuggable")
	call_deferred("_install_context_surfaces")


func _input(event: InputEvent) -> void:
	if is_context_active() or is_placement_active():
		return
	if not event.is_action_pressed("cast_spell"):
		return
	if action_state != null and action_state.is_focus_menu_open:
		return
	var ability: AbilityDefinition = _get_selected_ability()
	var result: Dictionary = try_open_context(actor, ability)
	if not bool(result.get("handled", false)):
		return
	intercepted_casts += 1
	get_viewport().set_input_as_handled()


func try_open_context(
	player: Node3D,
	ability: AbilityDefinition
) -> Dictionary:
	open_requests += 1
	if player == null or ability == null or player != actor:
		return {"handled": false, "success": false}
	if is_placement_active():
		return {"handled": true, "success": false}
	var resolved_provider: Node = get_provider_for_ability(ability)
	if resolved_provider == null:
		return {"handled": false, "success": false}
	if resolved_provider.has_method("is_ability_context_available"):
		if not bool(resolved_provider.call("is_ability_context_available", ability)):
			return {"handled": false, "success": false}
	var opened: bool = open_provider_context(resolved_provider, ability)
	return {
		"handled": true,
		"success": opened,
		"provider": resolved_provider,
	}


func open_provider_context(
	provider: Node,
	ability: AbilityDefinition
) -> bool:
	if provider == null or ability == null:
		return false
	_install_context_surfaces()
	if context_menu == null or not is_instance_valid(context_menu):
		context_open_failed.emit(ability, "context menu unavailable")
		return false
	if not context_menu.has_method("open_context"):
		context_open_failed.emit(ability, "context menu contract missing")
		return false
	var opened: bool = bool(
		context_menu.call("open_context", provider, ability)
	)
	if opened:
		successful_opens += 1
		last_provider_name = str(provider.name)
		last_ability_id = ability.get_spell_id()
		context_provider_resolved.emit(provider, ability)
	else:
		context_open_failed.emit(ability, "provider supplied no usable actions")
	return opened


func get_provider_for_ability(ability: AbilityDefinition) -> Node:
	if actor == null or ability == null:
		return null
	for child: Node in actor.get_children():
		if child == self:
			continue
		if not child.has_method("can_handle_ability_context"):
			continue
		if bool(child.call("can_handle_ability_context", ability)):
			return child
	return null


func get_context_menu() -> Node:
	_install_context_surfaces()
	return context_menu


func get_shared_placement_controller() -> Node:
	_install_context_surfaces()
	return shared_placement_controller


func get_active_ability_ribbon() -> Node:
	_install_context_surfaces()
	return active_ability_ribbon


func is_context_active() -> bool:
	return (
		context_menu != null
		and is_instance_valid(context_menu)
		and context_menu.has_method("is_modal_active")
		and bool(context_menu.call("is_modal_active"))
	)


func is_placement_active() -> bool:
	return (
		shared_placement_controller != null
		and is_instance_valid(shared_placement_controller)
		and shared_placement_controller.has_method("is_placement_active")
		and bool(shared_placement_controller.call("is_placement_active"))
	)


func cancel_context() -> bool:
	if is_placement_active():
		return bool(shared_placement_controller.call("cancel_placement"))
	if context_menu == null or not is_instance_valid(context_menu):
		return false
	if not context_menu.has_method("cancel_context"):
		return false
	return bool(context_menu.call("cancel_context"))


func _get_selected_ability() -> AbilityDefinition:
	if ability_caster == null or not is_instance_valid(ability_caster):
		ability_caster = actor.get_node_or_null("AbilityCaster") if actor != null else null
	if ability_caster == null or not ability_caster.has_method("get_current_ability"):
		return null
	var value: Variant = ability_caster.call("get_current_ability")
	return value as AbilityDefinition if value is AbilityDefinition else null


func _ensure_context_providers() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var recorded_provider: Node = actor.get_node_or_null(
		"RecordedObjectSpellController"
	)
	if recorded_provider == null:
		recorded_provider = RecordedObjectSpellControllerScript.new()
		recorded_provider.name = "RecordedObjectSpellController"
		actor.add_child(recorded_provider)
	var artificer_provider: Node = actor.get_node_or_null(
		"ArtificerSpellController"
	)
	if artificer_provider == null:
		artificer_provider = ArtificerSpellControllerScript.new()
		artificer_provider.name = "ArtificerSpellController"
		actor.add_child(artificer_provider)


func _install_context_surfaces() -> void:
	if actor == null or not is_instance_valid(actor):
		actor = get_parent() as Node3D
	if actor == null:
		return
	if (
		shared_placement_controller == null
		or not is_instance_valid(shared_placement_controller)
	):
		var existing_placement: Node = actor.get_node_or_null(
			"SharedPlacementController"
		)
		if existing_placement != null:
			shared_placement_controller = existing_placement
		else:
			shared_placement_controller = SharedPlacementControllerScript.new()
			shared_placement_controller.name = "SharedPlacementController"
			actor.add_child(shared_placement_controller)
	if shared_placement_controller.has_method("bind_actor"):
		shared_placement_controller.call("bind_actor", actor)

	if context_menu == null or not is_instance_valid(context_menu):
		var existing: Node = actor.get_node_or_null("AbilityContextMenu")
		if existing != null:
			context_menu = existing
		else:
			context_menu = AbilityContextMenuScript.new()
			context_menu.name = "AbilityContextMenu"
			actor.add_child(context_menu)
	if context_menu.has_method("bind_actor"):
		context_menu.call("bind_actor", actor)
	if context_menu.has_signal("context_closed"):
		var callback := Callable(self, "_on_context_closed")
		if not context_menu.is_connected("context_closed", callback):
			context_menu.connect("context_closed", callback)

	if active_ability_ribbon == null or not is_instance_valid(active_ability_ribbon):
		var existing_ribbon: Node = actor.get_node_or_null("ActiveAbilityRibbon")
		if existing_ribbon != null:
			active_ability_ribbon = existing_ribbon
		else:
			active_ability_ribbon = ActiveAbilityRibbonScript.new()
			active_ability_ribbon.name = "ActiveAbilityRibbon"
			actor.add_child(active_ability_ribbon)
	if active_ability_ribbon.has_method("bind_actor"):
		active_ability_ribbon.call("bind_actor", actor)


func _on_context_closed(_committed: bool) -> void:
	if context_menu != null and is_instance_valid(context_menu):
		if context_menu.has_method("_refresh_compact_status"):
			context_menu.call("_refresh_compact_status")
	if active_ability_ribbon != null and is_instance_valid(active_ability_ribbon):
		if active_ability_ribbon.has_method("force_refresh"):
			active_ability_ribbon.call("force_refresh")


func _ensure_dpad_navigation_actions() -> void:
	for raw_action: Variant in CONTEXT_DPAD_ACTIONS.keys():
		var action := StringName(str(raw_action))
		var button: int = int(CONTEXT_DPAD_ACTIONS[action])
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				if (event as InputEventJoypadButton).button_index == button:
					found = true
					break
		if found:
			continue
		var input := InputEventJoypadButton.new()
		input.button_index = button
		InputMap.action_add_event(action, input)


func _has_dpad_navigation() -> bool:
	for raw_action: Variant in CONTEXT_DPAD_ACTIONS.keys():
		var action := StringName(str(raw_action))
		var button: int = int(CONTEXT_DPAD_ACTIONS[action])
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				if (event as InputEventJoypadButton).button_index == button:
					found = true
					break
		if not found:
			return false
	return true


func get_debug_data() -> Dictionary:
	return {
		"open_requests": open_requests,
		"successful_opens": successful_opens,
		"intercepted_casts": intercepted_casts,
		"last_provider": last_provider_name,
		"last_ability": last_ability_id,
		"context_active": is_context_active(),
		"placement_active": is_placement_active(),
		"menu_installed": context_menu != null and is_instance_valid(context_menu),
		"placement_installed": shared_placement_controller != null and is_instance_valid(shared_placement_controller),
		"ribbon_installed": active_ability_ribbon != null and is_instance_valid(active_ability_ribbon),
		"unified_surfaces": true,
		"dpad_navigation": _has_dpad_navigation(),
		"recorded_provider": actor.get_node_or_null("RecordedObjectSpellController") != null if actor != null else false,
		"artificer_provider": actor.get_node_or_null("ArtificerSpellController") != null if actor != null else false,
		"selected_ability": _get_selected_ability().get_spell_id() if _get_selected_ability() != null else "none",
	}
