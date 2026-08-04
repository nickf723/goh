extends "res://scripts/ui/ability_context_menu.gd"
class_name PersistentAbilityContextMenu

# Persistent ability providers often need small state-changing actions such as
# cycling a blueprint or undoing one draft part. Those actions refresh the same
# modal. Placement actions hand off to one player-level placement session.


func _execute_action(action_id: String, payload: Variant) -> bool:
	if not _provider_is_usable(provider):
		return false
	var result_value: Variant = provider.call(
		"execute_ability_context_action",
		action_id,
		payload
	)
	var result: Dictionary = (
		(result_value as Dictionary).duplicate(true)
		if result_value is Dictionary
		else {"ok": bool(result_value)}
	)
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("error", "That context action is unavailable.")))
		return false

	if result.has("begin_shared_placement"):
		var placement_id: String = str(result.get("begin_shared_placement", ""))
		var placement_provider: Node = provider
		var placement_ability: AbilityDefinition = context_ability
		_finish_modal(true)
		var placement_controller: Node = (
			actor.get_node_or_null("SharedPlacementController")
			if actor != null
			else null
		)
		if (
			placement_controller == null
			or not placement_controller.has_method("begin_session")
		):
			_show_message("The shared placement controller is unavailable.")
			return false
		var started: bool = bool(placement_controller.call(
			"begin_session",
			placement_provider,
			placement_id,
			placement_ability
		))
		if not started:
			return false
		commit_count += 1
		context_action_committed.emit(action_id, result)
		return true

	commit_count += 1
	context_action_committed.emit(action_id, result)
	if result.has("message") and str(result.get("message", "")) != "":
		_show_message(str(result.get("message", "")))

	if bool(result.get("keep_open", false)):
		return refresh_context(str(result.get("selected_id", "")))

	_finish_modal(true)
	return true


func refresh_context(preferred_action_id: String = "") -> bool:
	if not modal_active or not _provider_is_usable(provider):
		return false
	if context_ability == null:
		return false

	var spec_value: Variant = provider.call(
		"get_ability_context_spec",
		context_ability
	)
	if not (spec_value is Dictionary):
		return false
	var refreshed_spec: Dictionary = (spec_value as Dictionary).duplicate(true)
	var refreshed_actions: Array[Dictionary] = _resolve_actions(
		refreshed_spec.get("actions", [])
	)
	if refreshed_actions.is_empty():
		_finish_modal(true)
		return true

	context_spec = refreshed_spec
	actions = refreshed_actions
	var requested_id: String = preferred_action_id
	if requested_id == "":
		requested_id = str(context_spec.get("selected_id", ""))
	selected_index = _resolve_selected_index(requested_id)
	menu_open = true
	targeting_active = false
	target_valid = false
	radial_root.visible = true
	target_root.visible = false
	if target_marker != null and is_instance_valid(target_marker):
		target_marker.visible = false
	stick_armed = true
	_rebuild_action_buttons()
	_refresh_action_highlight()
	_refresh_compact_status()
	return true
