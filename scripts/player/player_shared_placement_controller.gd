extends CanvasLayer
class_name PlayerSharedPlacementController

signal placement_started(provider: Node, placement_id: String)
signal placement_updated(state: Dictionary)
signal placement_committed(placement_id: String, result: Dictionary)
signal placement_cancelled(placement_id: String)
signal variant_changed(placement_id: String, direction: int, result: Dictionary)

@export_group("Placement Presentation")
@export var lock_player_movement: bool = true
@export var show_controls: bool = true

var actor: CharacterBody3D
var action_state: PlayerActionState
var provider: Node
var placement_id: String = ""
var context_ability: AbilityDefinition
var placement_state: Dictionary = {}
var placement_active: bool = false

var panel: PanelContainer
var eyebrow_label: Label
var title_label: Label
var status_label: Label
var details_label: Label
var controls_label: Label

var begin_count: int = 0
var confirm_count: int = 0
var cancel_count: int = 0
var depth_adjust_count: int = 0
var rotation_count: int = 0
var variant_cycle_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 74
	_build_interface()
	add_to_group("shared_placement_controller")
	add_to_group("debuggable")


func bind_actor(actor_value: Node3D) -> void:
	actor = actor_value as CharacterBody3D
	action_state = (
		actor.get_node_or_null("PlayerActionState") as PlayerActionState
		if actor != null
		else null
	)


func _exit_tree() -> void:
	if placement_active:
		_finish_session(false, true)


func _process(_delta: float) -> void:
	if not placement_active:
		return
	if not _provider_is_usable(provider):
		_finish_session(false, false)
		return
	_refresh_state()
	if not bool(placement_state.get("session_active", true)):
		_finish_session(false, false)


func _input(event: InputEvent) -> void:
	if not placement_active:
		return

	var handled: bool = false
	if event.is_action_pressed("cast_spell"):
		handled = confirm_placement()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.physical_keycode:
				KEY_ESCAPE:
					handled = cancel_placement()
				KEY_Q:
					handled = adjust_depth(-1)
				KEY_E:
					handled = adjust_depth(1)
				KEY_R:
					handled = rotate_preview(-1 if key_event.shift_pressed else 1)
				KEY_Z:
					handled = cycle_variant(-1)
				KEY_X:
					handled = cycle_variant(1)
				KEY_ENTER:
					handled = confirm_placement()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			match mouse_event.button_index:
				MOUSE_BUTTON_LEFT:
					handled = confirm_placement()
				MOUSE_BUTTON_RIGHT:
					handled = cancel_placement()
				MOUSE_BUTTON_WHEEL_UP:
					handled = adjust_depth(1)
				MOUSE_BUTTON_WHEEL_DOWN:
					handled = adjust_depth(-1)

	if handled:
		get_viewport().set_input_as_handled()


func begin_session(
	provider_value: Node,
	placement_id_value: String,
	ability_value: AbilityDefinition = null
) -> bool:
	if not _provider_is_usable(provider_value):
		_show_message("That ability does not provide a shared placement contract.")
		return false
	var normalized_id: String = _normalize_id(placement_id_value)
	if normalized_id == "":
		return false
	if placement_active:
		_finish_session(false, true)

	provider = provider_value
	placement_id = normalized_id
	context_ability = ability_value
	var begin_value: Variant = provider.call(
		"begin_shared_placement",
		placement_id
	)
	var begin_result: Dictionary = _normalize_result(begin_value)
	if not bool(begin_result.get("ok", false)):
		_show_message(str(begin_result.get("error", "Placement could not begin.")))
		_clear_session_references()
		return false

	placement_active = true
	begin_count += 1
	if actor != null:
		actor.set_meta("shared_placement_active", true)
		if lock_player_movement:
			actor.velocity.x = 0.0
			actor.velocity.z = 0.0
	if action_state != null:
		if not action_state.is_manipulating:
			action_state.begin_manipulation()
	_refresh_state()
	panel.visible = true
	placement_started.emit(provider, placement_id)
	if str(begin_result.get("message", "")) != "":
		_show_message(str(begin_result.get("message", "")))
	return true


func handle_controller_button(event: InputEventJoypadButton) -> bool:
	if not placement_active:
		return false
	var reserved: bool = event.button_index in [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT,
		JOY_BUTTON_LEFT_SHOULDER,
		JOY_BUTTON_RIGHT_SHOULDER,
		JOY_BUTTON_A,
		JOY_BUTTON_B,
	]
	if not reserved:
		return false
	if not event.pressed:
		return true

	match event.button_index:
		JOY_BUTTON_DPAD_UP:
			adjust_depth(1)
		JOY_BUTTON_DPAD_DOWN:
			adjust_depth(-1)
		JOY_BUTTON_DPAD_LEFT:
			cycle_variant(-1)
		JOY_BUTTON_DPAD_RIGHT:
			cycle_variant(1)
		JOY_BUTTON_LEFT_SHOULDER:
			rotate_preview(-1)
		JOY_BUTTON_RIGHT_SHOULDER:
			rotate_preview(1)
		JOY_BUTTON_A:
			confirm_placement()
		JOY_BUTTON_B:
			cancel_placement()
	return true


func adjust_depth(direction: int) -> bool:
	if not placement_active or direction == 0:
		return false
	if not provider.has_method("adjust_shared_placement_depth"):
		return false
	var result: Dictionary = _normalize_result(provider.call(
		"adjust_shared_placement_depth",
		placement_id,
		direction
	))
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("error", "Placement depth cannot change.")))
		return false
	depth_adjust_count += 1
	_refresh_state()
	return true


func rotate_preview(direction: int) -> bool:
	if not placement_active or direction == 0:
		return false
	if not provider.has_method("rotate_shared_placement"):
		return false
	var result: Dictionary = _normalize_result(provider.call(
		"rotate_shared_placement",
		placement_id,
		direction
	))
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("error", "That placement cannot rotate.")))
		return false
	rotation_count += 1
	_refresh_state()
	return true


func cycle_variant(direction: int) -> bool:
	if not placement_active or direction == 0:
		return false
	if not provider.has_method("cycle_shared_placement_variant"):
		return false
	var result: Dictionary = _normalize_result(provider.call(
		"cycle_shared_placement_variant",
		placement_id,
		direction
	))
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("error", "No alternate placement is available.")))
		return false
	variant_cycle_count += 1
	if str(result.get("message", "")) != "":
		_show_message(str(result.get("message", "")))
	_refresh_state()
	variant_changed.emit(placement_id, direction, result)
	return true


func confirm_placement() -> bool:
	if not placement_active or not provider.has_method("confirm_shared_placement"):
		return false
	var result: Dictionary = _normalize_result(provider.call(
		"confirm_shared_placement",
		placement_id
	))
	if not bool(result.get("ok", false)):
		_refresh_state()
		_show_message(str(result.get(
			"error",
			placement_state.get("reason", "That placement is not valid.")
		)))
		return false
	confirm_count += 1
	placement_committed.emit(placement_id, result)
	if str(result.get("message", "")) != "":
		_show_message(str(result.get("message", "")))
	if bool(result.get("keep_active", false)):
		_refresh_state()
		return true
	_finish_session(true, false)
	return true


func confirm_at(
	world_position: Vector3,
	yaw_degrees: float = 0.0
) -> bool:
	# Deterministic test and scripted-sequence seam. Runtime play uses the live
	# provider preview and confirm_placement().
	if (
		not placement_active
		or not provider.has_method("confirm_shared_placement_at")
	):
		return false
	var result: Dictionary = _normalize_result(provider.call(
		"confirm_shared_placement_at",
		placement_id,
		world_position,
		yaw_degrees
	))
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("error", "That placement is not valid.")))
		return false
	confirm_count += 1
	placement_committed.emit(placement_id, result)
	if bool(result.get("keep_active", false)):
		_refresh_state()
		return true
	_finish_session(true, false)
	return true


func cancel_placement() -> bool:
	if not placement_active:
		return false
	var cancelled_id: String = placement_id
	cancel_count += 1
	_finish_session(false, true)
	placement_cancelled.emit(cancelled_id)
	return true


func is_placement_active() -> bool:
	return placement_active


func get_placement_state() -> Dictionary:
	return placement_state.duplicate(true)


func get_provider() -> Node:
	return provider


func get_placement_id() -> String:
	return placement_id


func _refresh_state() -> void:
	if not placement_active or not _provider_is_usable(provider):
		return
	var state_value: Variant = provider.call(
		"get_shared_placement_state",
		placement_id
	)
	if state_value is Dictionary:
		placement_state = (state_value as Dictionary).duplicate(true)
	else:
		placement_state = {
			"valid": false,
			"reason": "Placement state is unavailable.",
			"session_active": false,
		}
	_update_interface()
	placement_updated.emit(placement_state.duplicate(true))


func _finish_session(committed: bool, notify_provider: bool) -> void:
	if not placement_active:
		_clear_session_references()
		return
	if notify_provider and _provider_is_usable(provider):
		provider.call("cancel_shared_placement", placement_id)
	placement_active = false
	panel.visible = false
	if actor != null:
		actor.set_meta("shared_placement_active", false)
	if action_state != null:
		action_state.end_manipulation()
	if not committed and notify_provider:
		_show_message("Placement cancelled.")
	_clear_session_references()


func _clear_session_references() -> void:
	provider = null
	placement_id = ""
	context_ability = null
	placement_state.clear()


func _provider_is_usable(candidate: Node) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and candidate.has_method("begin_shared_placement")
		and candidate.has_method("get_shared_placement_state")
		and candidate.has_method("confirm_shared_placement")
		and candidate.has_method("cancel_shared_placement")
	)


func _normalize_result(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {"ok": bool(value)}


func _normalize_id(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_")


func _build_interface() -> void:
	panel = PanelContainer.new()
	panel.name = "SharedPlacementPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -390.0
	panel.offset_top = -220.0
	panel.offset_right = 390.0
	panel.offset_bottom = -72.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.add_to_group("menu_suppressed_hud")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.028, 0.05, 0.96)
	style.border_color = Color(0.28, 0.88, 1.0, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	panel.add_child(stack)

	eyebrow_label = Label.new()
	eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow_label.add_theme_font_size_override("font_size", 10)
	eyebrow_label.add_theme_color_override("font_color", Color(0.46, 0.86, 1.0))
	stack.add_child(eyebrow_label)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	stack.add_child(title_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 13)
	stack.add_child(status_label)

	details_label = Label.new()
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.add_theme_font_size_override("font_size", 11)
	details_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
	stack.add_child(details_label)

	controls_label = Label.new()
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.add_theme_font_size_override("font_size", 10)
	controls_label.add_theme_color_override("font_color", Color(0.56, 0.7, 0.8))
	controls_label.text = "Right stick aim  •  D-pad ↑/↓ depth  •  D-pad ←/→ variant  •  L/R rotate  •  Cast/A confirm  •  B cancel"
	controls_label.visible = show_controls
	stack.add_child(controls_label)


func _update_interface() -> void:
	if panel == null:
		return
	panel.visible = placement_active
	eyebrow_label.text = str(placement_state.get("eyebrow", "SHARED PLACEMENT"))
	title_label.text = str(placement_state.get("title", "Placement"))
	var valid: bool = bool(placement_state.get("valid", false))
	status_label.text = (
		"VALID POSITION"
		if valid
		else str(placement_state.get("reason", "That placement cannot fit there."))
	)
	status_label.add_theme_color_override(
		"font_color",
		Color(0.46, 1.0, 0.66) if valid else Color(1.0, 0.46, 0.34)
	)
	var details: Array[String] = []
	if placement_state.has("mana_cost"):
		details.append(str(placement_state.get("mana_cost", 0)) + " MANA")
	if placement_state.has("depth"):
		details.append("DEPTH " + str(snappedf(float(placement_state.get("depth", 0.0)), 0.25)))
	if placement_state.has("rotation"):
		details.append("ROTATION " + str(snappedf(float(placement_state.get("rotation", 0.0)), 0.5)) + "°")
	if placement_state.has("active_count"):
		var active_text: String = str(placement_state.get("active_count", 0))
		if placement_state.has("active_limit"):
			active_text += "/" + str(placement_state.get("active_limit", 0))
		details.append("ACTIVE " + active_text)
	if placement_state.has("draft_count"):
		details.append("DRAFT " + str(placement_state.get("draft_count", 0)) + "/12")
	details_label.text = "  •  ".join(details)


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	return {
		"active": placement_active,
		"placement_id": placement_id,
		"provider": str(provider.name) if provider != null and is_instance_valid(provider) else "none",
		"state": placement_state.duplicate(true),
		"begin_count": begin_count,
		"confirm_count": confirm_count,
		"cancel_count": cancel_count,
		"depth_adjust_count": depth_adjust_count,
		"rotation_count": rotation_count,
		"variant_cycle_count": variant_cycle_count,
		"movement_locked": lock_player_movement,
		"universal_controls": true,
	}
