extends Node
class_name PlayerAbilityContextRouter

signal context_provider_resolved(provider: Node, ability: AbilityDefinition)
signal context_open_failed(ability: AbilityDefinition, reason: String)

const AbilityContextMenuScript = preload(
	"res://scripts/ui/ability_context_menu.gd"
)

var actor: Node3D
var context_menu: Node
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
	add_to_group("ability_context_routers")
	add_to_group("debuggable")
	call_deferred("_install_context_menu")


func _input(event: InputEvent) -> void:
	if is_context_active():
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
	_install_context_menu()
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
	_install_context_menu()
	return context_menu


func is_context_active() -> bool:
	return (
		context_menu != null
		and is_instance_valid(context_menu)
		and context_menu.has_method("is_modal_active")
		and bool(context_menu.call("is_modal_active"))
	)


func cancel_context() -> bool:
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


func _install_context_menu() -> void:
	if actor == null or not is_instance_valid(actor):
		actor = get_parent() as Node3D
	if actor == null:
		return
	if context_menu != null and is_instance_valid(context_menu):
		return
	var existing: Node = actor.get_node_or_null("AbilityContextMenu")
	if existing != null:
		context_menu = existing
	else:
		context_menu = AbilityContextMenuScript.new()
		context_menu.name = "AbilityContextMenu"
		actor.add_child(context_menu)
	if context_menu.has_method("bind_actor"):
		context_menu.call("bind_actor", actor)


func get_debug_data() -> Dictionary:
	return {
		"open_requests": open_requests,
		"successful_opens": successful_opens,
		"intercepted_casts": intercepted_casts,
		"last_provider": last_provider_name,
		"last_ability": last_ability_id,
		"context_active": is_context_active(),
		"menu_installed": context_menu != null and is_instance_valid(context_menu),
		"selected_ability": _get_selected_ability().get_spell_id() if _get_selected_ability() != null else "none",
	}
