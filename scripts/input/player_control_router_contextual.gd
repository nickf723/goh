extends "res://scripts/input/player_control_router.gd"


const PerformanceDockScript = preload(
	"res://scripts/ui/quick_spell_belt_unified.gd"
)

const PERFORMANCE_DOCK_PATH: String = "res://scripts/ui/quick_spell_belt_unified.gd"
const MANIPULATION_ROTATION_STEP_DEGREES: float = 22.5

var dock_replacement_pending: bool = false
var performance_dock_installed: bool = false


func _process(delta: float) -> void:
	super._process(delta)
	if not performance_dock_installed and not dock_replacement_pending:
		dock_replacement_pending = true
		call_deferred("_ensure_performance_command_dock")


func _ensure_performance_command_dock() -> void:
	dock_replacement_pending = false
	_resolve_bindings()
	if actor == null:
		return
	var existing: Node = actor.get_node_or_null("QuickSpellBeltPresentation")
	if existing != null:
		var existing_script: Script = existing.get_script() as Script
		if existing_script != null and existing_script.resource_path == PERFORMANCE_DOCK_PATH:
			performance_dock_installed = true
			return
		actor.remove_child(existing)
		existing.queue_free()
	var presentation: Node = PerformanceDockScript.new()
	presentation.name = "QuickSpellBeltPresentation"
	actor.add_child(presentation)
	performance_dock_installed = true


func is_ground_targeting_active() -> bool:
	return (
		ability_caster != null
		and ability_caster.has_method("is_ground_targeting")
		and bool(ability_caster.call("is_ground_targeting"))
	)


func is_focus_open() -> bool:
	if is_ground_targeting_active():
		return false
	if ability_caster != null and ability_caster.has_method("is_focus_library_open"):
		return bool(ability_caster.call("is_focus_library_open"))
	return super.is_focus_open()


func handle_focus_action(pressed: bool) -> bool:
	if is_ground_targeting_active() or _get_active_shared_placement_controller() != null:
		focus_axis_x_latched = false
		focus_axis_y_latched = false
		return true
	return super.handle_focus_action(pressed)


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	_resolve_bindings()
	if event is InputEventJoypadButton and _handle_active_manipulation_button(event as InputEventJoypadButton):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and is_ground_targeting_active():
		var target_button: InputEventJoypadButton = event as InputEventJoypadButton
		if target_button.button_index in [
			JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_DOWN,
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_RIGHT,
		]:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and is_focus_open() and _handle_focus_dpad(event as InputEventJoypadButton):
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _handle_active_manipulation_button(event: InputEventJoypadButton) -> bool:
	var shared_placement: Node = _get_active_shared_placement_controller()
	if shared_placement != null:
		return bool(shared_placement.call("handle_controller_button", event))
	var artificer: Node = _get_active_artificer_manager()
	if artificer != null:
		return _handle_artificer_button(artificer, event)
	var manager: Node = _get_active_recorded_object_manager()
	if manager != null:
		return _handle_recorded_object_button(manager, event)
	var soul_controller: Node = _get_active_soul_grip_controller()
	if soul_controller != null:
		return _handle_soul_grip_button(soul_controller, event)
	return false


func _get_active_shared_placement_controller() -> Node:
	var controller: Node = null
	if actor != null and is_instance_valid(actor):
		controller = actor.get_node_or_null("SharedPlacementController")
	if controller == null:
		controller = get_tree().get_first_node_in_group("shared_placement_controller")
	if controller == null or not is_instance_valid(controller):
		return null
	if not controller.has_method("is_placement_active"):
		return null
	if not bool(controller.call("is_placement_active")):
		return null
	return controller


func _get_active_artificer_manager() -> Node:
	var manager: Node = null
	if actor != null and is_instance_valid(actor):
		manager = actor.get_node_or_null("ArtificerConstructionManager")
	if manager == null:
		manager = get_tree().get_first_node_in_group("artificer_construction_manager")
	if manager == null or not is_instance_valid(manager):
		return null
	if str(manager.get("mode")) == "":
		return null
	return manager


func _handle_artificer_button(manager: Node, event: InputEventJoypadButton) -> bool:
	var mode_id: String = str(manager.get("mode"))
	var reserved: Array[int] = [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_LEFT_SHOULDER,
		JOY_BUTTON_RIGHT_SHOULDER,
		JOY_BUTTON_A,
		JOY_BUTTON_B,
	]
	if mode_id == "assembly":
		reserved.append_array([
			JOY_BUTTON_DPAD_LEFT,
			JOY_BUTTON_DPAD_RIGHT,
			JOY_BUTTON_X,
			JOY_BUTTON_Y,
		])
	if event.button_index not in reserved:
		return false
	if not event.pressed:
		return true
	match event.button_index:
		JOY_BUTTON_DPAD_UP:
			manager.call("adjust_depth", 1)
		JOY_BUTTON_DPAD_DOWN:
			manager.call("adjust_depth", -1)
		JOY_BUTTON_DPAD_LEFT:
			if mode_id == "assembly":
				manager.call("cycle_part", -1)
		JOY_BUTTON_DPAD_RIGHT:
			if mode_id == "assembly":
				manager.call("cycle_part", 1)
		JOY_BUTTON_LEFT_SHOULDER:
			manager.call("rotate_preview", -1)
		JOY_BUTTON_RIGHT_SHOULDER:
			manager.call("rotate_preview", 1)
		JOY_BUTTON_A:
			manager.call("confirm_placement")
		JOY_BUTTON_B:
			manager.call("cancel_mode")
		JOY_BUTTON_X:
			if mode_id == "assembly":
				manager.call("undo_last_part")
		JOY_BUTTON_Y:
			if mode_id == "assembly":
				manager.call("finalize_draft")
	return true


func _get_active_recorded_object_manager() -> Node:
	var manager: Node = null
	if actor != null and is_instance_valid(actor):
		manager = actor.get_node_or_null("RecordedObjectManager")
	if manager == null:
		manager = get_tree().get_first_node_in_group("recorded_object_manager")
	if manager == null or not is_instance_valid(manager) or not bool(manager.get("placement_active")):
		return null
	return manager


func _get_active_soul_grip_controller() -> Node:
	var controller: Node = null
	if actor != null and is_instance_valid(actor):
		controller = actor.get_node_or_null("SoulGripController")
	if controller == null:
		controller = get_tree().get_first_node_in_group("soul_grip_controllers")
	if controller == null or not is_instance_valid(controller):
		return null
	var held_target: Variant = controller.get("held_target")
	if not bool(controller.get("channel_requested")) or held_target == null:
		return null
	return controller


func _handle_recorded_object_button(manager: Node, event: InputEventJoypadButton) -> bool:
	var reserved: bool = event.button_index in [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
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
			if manager.has_method("adjust_depth"):
				manager.call("adjust_depth", 1)
		JOY_BUTTON_DPAD_DOWN:
			if manager.has_method("adjust_depth"):
				manager.call("adjust_depth", -1)
		JOY_BUTTON_LEFT_SHOULDER:
			if manager.has_method("rotate_preview"):
				manager.call("rotate_preview", -1)
		JOY_BUTTON_RIGHT_SHOULDER:
			if manager.has_method("rotate_preview"):
				manager.call("rotate_preview", 1)
		JOY_BUTTON_A:
			if manager.has_method("confirm_placement"):
				manager.call("confirm_placement")
		JOY_BUTTON_B:
			if manager.has_method("cancel_placement"):
				manager.call("cancel_placement")
	return true


func _handle_soul_grip_button(controller: Node, event: InputEventJoypadButton) -> bool:
	var reserved: bool = event.button_index in [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_LEFT_SHOULDER,
		JOY_BUTTON_RIGHT_SHOULDER,
	]
	if not reserved:
		return false
	if not event.pressed:
		return true
	match event.button_index:
		JOY_BUTTON_DPAD_UP:
			_adjust_soul_grip_distance(controller, 1)
		JOY_BUTTON_DPAD_DOWN:
			_adjust_soul_grip_distance(controller, -1)
		JOY_BUTTON_LEFT_SHOULDER:
			_rotate_soul_grip_target(controller, -1)
		JOY_BUTTON_RIGHT_SHOULDER:
			_rotate_soul_grip_target(controller, 1)
	return true


func _adjust_soul_grip_distance(controller: Node, direction: int) -> void:
	var step: float = 0.75
	var configured_step: Variant = controller.get("mouse_distance_step")
	if configured_step is float or configured_step is int:
		step = maxf(float(configured_step), 0.1)
	var minimum: float = float(controller.get("minimum_hold_distance"))
	var maximum: float = float(controller.get("maximum_hold_distance"))
	var current: float = float(controller.get("hold_distance"))
	controller.set("hold_distance", clampf(current + step * signi(direction), minimum, maximum))
	_refresh_soul_grip_pose(controller)


func _rotate_soul_grip_target(controller: Node, direction: int) -> void:
	var current_basis: Basis = controller.get("desired_basis") as Basis
	var angle: float = deg_to_rad(MANIPULATION_ROTATION_STEP_DEGREES * signi(direction))
	controller.set("desired_basis", Basis(Vector3.UP, angle) * current_basis)
	_refresh_soul_grip_pose(controller)


func _refresh_soul_grip_pose(controller: Node) -> void:
	if controller.has_method("update_target_pose"):
		controller.call("update_target_pose")
	if controller.has_method("update_feedback_visuals"):
		controller.call("update_feedback_visuals")


func _handle_focus_dpad(event: InputEventJoypadButton) -> bool:
	if event.button_index not in [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT,
	]:
		return false
	if not event.pressed:
		return true
	if ability_caster == null:
		return true
	match event.button_index:
		JOY_BUTTON_DPAD_LEFT:
			if ability_caster.has_method("cycle_focus_element"):
				ability_caster.call("cycle_focus_element", -1)
		JOY_BUTTON_DPAD_RIGHT:
			if ability_caster.has_method("cycle_focus_element"):
				ability_caster.call("cycle_focus_element", 1)
		JOY_BUTTON_DPAD_UP:
			if ability_caster.has_method("cycle_focus_spell"):
				ability_caster.call("cycle_focus_spell", -1)
		JOY_BUTTON_DPAD_DOWN:
			if ability_caster.has_method("cycle_focus_spell"):
				ability_caster.call("cycle_focus_spell", 1)
	return true


func get_input_mode_debug_data() -> Dictionary:
	var shared_placement: bool = _get_active_shared_placement_controller() != null
	return {
		"ground_targeting": is_ground_targeting_active(),
		"focus_library": is_focus_open(),
		"shared_placement": shared_placement,
		"artificer_construction": _get_active_artificer_manager() != null,
		"recorded_object_manipulation": _get_active_recorded_object_manager() != null,
		"soul_grip_manipulation": _get_active_soul_grip_controller() != null,
		"right_stick_owner": (
			"shared_placement_camera"
			if shared_placement
			else (
				"ground_target"
				if is_ground_targeting_active()
				else ("focus_library" if is_focus_open() else "camera")
			)
		),
		"optimized_dock_installed": performance_dock_installed,
		"unified_dock": performance_dock_installed,
	}
