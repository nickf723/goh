extends CanvasLayer
class_name AbilityContextMenu

signal context_opened(provider: Node, ability: AbilityDefinition, actions: Array[String])
signal context_closed(committed: bool)
signal targeting_changed(active: bool)
signal context_action_committed(action_id: String, result: Dictionary)

@export_group("Presentation")
@export_range(0.05, 1.0, 0.05) var modal_time_scale: float = 0.35
@export_range(0.1, 1.0, 0.05) var stick_deadzone: float = 0.42
@export_range(10.0, 160.0, 5.0) var targeting_distance: float = 80.0

var actor: Node3D
var action_state: PlayerActionState
var provider: Node
var context_ability: AbilityDefinition
var context_spec: Dictionary = {}
var actions: Array[Dictionary] = []
var selected_index: int = 0

var compact_panel: PanelContainer
var compact_label: Label
var radial_root: Control
var radial_panel: PanelContainer
var radial_title: Label
var radial_description: Label
var radial_button_layer: Control
var target_root: Control
var target_label: Label
var target_marker: Node3D
var action_buttons: Array[Button] = []

var modal_active: bool = false
var menu_open: bool = false
var targeting_active: bool = false
var target_valid: bool = false
var target_position: Vector3 = Vector3.ZERO
var stick_armed: bool = true
var previous_time_scale: float = 1.0
var previous_allow_movement: bool = true
var focus_was_open: bool = false
var open_count: int = 0
var commit_count: int = 0
var targeting_confirm_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 72
	_build_interface()
	add_to_group("ability_context_menu")
	add_to_group("debuggable")
	_refresh_compact_status()


func bind_actor(actor_value: Node3D) -> void:
	actor = actor_value
	action_state = (
		actor.get_node_or_null("PlayerActionState") as PlayerActionState
		if actor != null
		else null
	)
	_refresh_compact_status()


func _exit_tree() -> void:
	_finish_modal(false)
	_remove_target_marker()


func _process(_delta: float) -> void:
	if modal_active and not _provider_is_usable(provider):
		_finish_modal(false)
	if menu_open:
		_update_selection_from_stick()
	if targeting_active:
		_update_targeting_position()
	_refresh_compact_status()


func _input(event: InputEvent) -> void:
	if not modal_active:
		return

	var handled: bool = false
	if event.is_action_pressed("ui_cancel"):
		handled = cancel_context()
	elif targeting_active:
		if (
			event.is_action_pressed("cast_spell")
			or event.is_action_pressed("ui_accept")
			or event.is_action_pressed("interact")
		):
			handled = confirm_current_target()
	elif menu_open:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			handled = select_action_index(selected_index - 1)
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			handled = select_action_index(selected_index + 1)
		elif (
			event.is_action_pressed("cast_spell")
			or event.is_action_pressed("ui_accept")
			or event.is_action_pressed("interact")
		):
			handled = commit_selected_action()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				handled = select_action_index(selected_index - 1)
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				handled = select_action_index(selected_index + 1)
			elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
				handled = commit_selected_action()

	if handled or event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func open_context(provider_value: Node, ability_value: AbilityDefinition) -> bool:
	if not _provider_is_usable(provider_value):
		return false
	if modal_active:
		_finish_modal(false)

	var spec_value: Variant = provider_value.call(
		"get_ability_context_spec",
		ability_value
	)
	if not (spec_value is Dictionary):
		return false
	var resolved_spec: Dictionary = (spec_value as Dictionary).duplicate(true)
	var resolved_actions: Array[Dictionary] = _resolve_actions(
		resolved_spec.get("actions", [])
	)
	if resolved_actions.is_empty():
		_show_message("This ability has no available context actions.")
		return false

	provider = provider_value
	context_ability = ability_value
	context_spec = resolved_spec
	actions = resolved_actions
	selected_index = _resolve_selected_index(
		str(context_spec.get("selected_id", ""))
	)
	_rebuild_action_buttons()
	_begin_modal()
	menu_open = true
	targeting_active = false
	radial_root.visible = true
	target_root.visible = false
	stick_armed = true
	open_count += 1
	_refresh_action_highlight()
	context_opened.emit(provider, context_ability, get_available_action_ids())
	return true


func close_context(committed: bool = false) -> bool:
	if not modal_active:
		return false
	_finish_modal(committed)
	return true


func cancel_context() -> bool:
	if not modal_active:
		return false
	_finish_modal(false)
	return true


func commit_selected_action() -> bool:
	if not menu_open or actions.is_empty() or not _provider_is_usable(provider):
		return false
	selected_index = clampi(selected_index, 0, actions.size() - 1)
	var action: Dictionary = actions[selected_index]
	var action_id: String = str(action.get("id", ""))
	if action_id == "":
		return false
	if str(action.get("target_mode", "")) == "world":
		menu_open = false
		radial_root.visible = false
		targeting_active = true
		target_valid = false
		target_root.visible = true
		_ensure_target_marker()
		targeting_changed.emit(true)
		return true
	return _execute_action(action_id, Vector3.INF)


func confirm_current_target() -> bool:
	if not targeting_active or not target_valid:
		return false
	return confirm_world_target(target_position)


func confirm_world_target(world_position: Vector3) -> bool:
	if not targeting_active:
		return false
	var action_id: String = get_selected_action_id()
	if action_id == "":
		return false
	var succeeded: bool = _execute_action(action_id, world_position)
	if succeeded:
		targeting_confirm_count += 1
	return succeeded


func select_action_by_id(action_id: String) -> bool:
	var normalized: String = _normalize_id(action_id)
	for index: int in range(actions.size()):
		if _normalize_id(str(actions[index].get("id", ""))) == normalized:
			selected_index = index
			_refresh_action_highlight()
			return true
	return false


func select_action_index(index: int) -> bool:
	if actions.is_empty():
		return false
	selected_index = wrapi(index, 0, actions.size())
	_refresh_action_highlight()
	return true


func is_context_open() -> bool:
	return menu_open


func is_targeting() -> bool:
	return targeting_active


func is_modal_active() -> bool:
	return modal_active


func is_interface_visible() -> bool:
	return compact_panel != null and compact_panel.visible


func get_selected_action_id() -> String:
	if actions.is_empty():
		return ""
	return str(actions[clampi(selected_index, 0, actions.size() - 1)].get("id", ""))


func get_available_action_ids() -> Array[String]:
	var ids: Array[String] = []
	for action: Dictionary in actions:
		var action_id: String = str(action.get("id", ""))
		if action_id != "":
			ids.append(action_id)
	return ids


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
	commit_count += 1
	context_action_committed.emit(action_id, result)
	if result.has("message") and str(result.get("message", "")) != "":
		_show_message(str(result.get("message", "")))
	_finish_modal(true)
	return true


func _begin_modal() -> void:
	if modal_active:
		return
	modal_active = true
	previous_time_scale = Engine.time_scale
	Engine.time_scale = minf(previous_time_scale, modal_time_scale)
	if action_state != null:
		focus_was_open = action_state.is_focus_menu_open
		previous_allow_movement = action_state.allow_movement_during_focus_menu
		action_state.allow_movement_during_focus_menu = false
		action_state.set_focus_menu_open(true)


func _finish_modal(committed: bool) -> void:
	if not modal_active:
		return
	modal_active = false
	menu_open = false
	targeting_active = false
	target_valid = false
	radial_root.visible = false
	target_root.visible = false
	if target_marker != null and is_instance_valid(target_marker):
		target_marker.visible = false
	Engine.time_scale = previous_time_scale
	if action_state != null:
		action_state.allow_movement_during_focus_menu = previous_allow_movement
		action_state.set_focus_menu_open(focus_was_open)
	targeting_changed.emit(false)
	context_closed.emit(committed)
	provider = null
	context_ability = null
	context_spec.clear()
	actions.clear()
	selected_index = 0
	_clear_action_buttons()


func _provider_is_usable(candidate: Node) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and candidate.has_method("get_ability_context_spec")
		and candidate.has_method("execute_ability_context_action")
	)


func _resolve_actions(raw_actions: Variant) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	if not (raw_actions is Array):
		return resolved
	for raw: Variant in raw_actions as Array:
		if not (raw is Dictionary):
			continue
		var action: Dictionary = (raw as Dictionary).duplicate(true)
		var action_id: String = _normalize_id(str(action.get("id", "")))
		if action_id == "" or not bool(action.get("enabled", true)):
			continue
		action["id"] = action_id
		if not action.has("label"):
			action["label"] = action_id.replace("_", " ").capitalize()
		if not action.has("description"):
			action["description"] = "Use this ability context action."
		resolved.append(action)
	return resolved


func _resolve_selected_index(selected_id: String) -> int:
	var normalized: String = _normalize_id(selected_id)
	if normalized == "":
		return 0
	for index: int in range(actions.size()):
		if str(actions[index].get("id", "")) == normalized:
			return index
	return 0


func _update_selection_from_stick() -> void:
	var vector: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)
	if vector.length() < stick_deadzone * 0.65:
		stick_armed = true
		return
	if not stick_armed or actions.is_empty():
		return
	stick_armed = false
	var normalized: Vector2 = vector.normalized()
	var best_index: int = selected_index
	var best_dot: float = -INF
	for index: int in range(actions.size()):
		var direction: Vector2 = _action_direction(index, actions.size())
		var score: float = normalized.dot(direction)
		if score > best_dot:
			best_dot = score
			best_index = index
	selected_index = best_index
	_refresh_action_highlight()


func _action_direction(index: int, count: int) -> Vector2:
	var angle: float = -PI * 0.5 + TAU * float(index) / float(maxi(count, 1))
	return Vector2(cos(angle), sin(angle))


func _rebuild_action_buttons() -> void:
	_clear_action_buttons()
	var count: int = actions.size()
	for index: int in range(count):
		var action: Dictionary = actions[index]
		var button := Button.new()
		button.name = "Action_" + str(action.get("id", "context"))
		button.text = str(action.get("label", "Action"))
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(142.0, 50.0)
		button.size = Vector2(142.0, 50.0)
		var direction: Vector2 = _action_direction(index, count)
		button.position = Vector2(266.0, 205.0) + direction * 157.0 - button.size * 0.5
		button.mouse_entered.connect(func() -> void:
			select_action_index(index)
		)
		button.pressed.connect(func() -> void:
			select_action_index(index)
			commit_selected_action()
		)
		radial_button_layer.add_child(button)
		action_buttons.append(button)


func _clear_action_buttons() -> void:
	for button: Button in action_buttons:
		if is_instance_valid(button):
			button.queue_free()
	action_buttons.clear()


func _refresh_action_highlight() -> void:
	if actions.is_empty():
		return
	selected_index = clampi(selected_index, 0, actions.size() - 1)
	for index: int in range(action_buttons.size()):
		action_buttons[index].modulate = (
			Color(1.0, 0.84, 0.38)
			if index == selected_index
			else Color(0.76, 0.86, 0.96)
		)
	var action: Dictionary = actions[selected_index]
	radial_title.text = str(action.get("label", "Action"))
	radial_description.text = str(action.get("description", ""))


func _refresh_compact_status() -> void:
	if compact_panel == null or compact_label == null:
		return
	var status_provider: Node = _find_active_status_provider()
	if status_provider == null:
		compact_panel.visible = false
		return
	var status_value: Variant = status_provider.call("get_ability_context_status")
	if not (status_value is Dictionary):
		compact_panel.visible = false
		return
	var status: Dictionary = status_value as Dictionary
	if not bool(status.get("active", false)):
		compact_panel.visible = false
		return
	compact_panel.visible = true
	var title: String = str(status.get("title", "Active Ability"))
	var state: String = str(status.get("state", "Ready"))
	var hint: String = str(status.get("hint", "Select its spell and press Cast to manage"))
	compact_label.text = title + "\n" + state + "\n" + hint


func _find_active_status_provider() -> Node:
	if actor == null or not is_instance_valid(actor):
		return null
	for child: Node in actor.get_children():
		if not child.has_method("has_active_ability_context"):
			continue
		if not child.has_method("get_ability_context_status"):
			continue
		if bool(child.call("has_active_ability_context")):
			return child
	return null


func _update_targeting_position() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		target_valid = false
		return
	var screen_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var origin: Vector3 = camera.project_ray_origin(screen_center)
	var direction: Vector3 = camera.project_ray_normal(screen_center).normalized()
	var end: Vector3 = origin + direction * targeting_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = _get_actor_collision_exclusions()
	var result: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.has("position"):
		target_position = result.get("position", Vector3.ZERO) as Vector3
		target_valid = true
	else:
		var plane := Plane(Vector3.UP, 0.0)
		var intersection: Variant = plane.intersects_ray(origin, direction)
		if intersection is Vector3:
			target_position = intersection as Vector3
			target_valid = origin.distance_to(target_position) <= targeting_distance
		else:
			target_valid = false
	_ensure_target_marker()
	if target_marker != null:
		target_marker.visible = target_valid
		if target_valid:
			target_marker.global_position = target_position + Vector3.UP * 0.06
	target_label.text = (
		"CAST: confirm destination   B: cancel"
		if target_valid
		else "Aim at reachable ground"
	)


func _get_actor_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	_collect_collision_rids(actor, exclusions)
	return exclusions


func _collect_collision_rids(node: Node, exclusions: Array[RID]) -> void:
	if node == null:
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not exclusions.has(rid):
			exclusions.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, exclusions)


func _ensure_target_marker() -> void:
	if target_marker != null and is_instance_valid(target_marker):
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	target_marker = Node3D.new()
	target_marker.name = "AbilityContextTargetMarker"
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.72
	mesh.height = 0.06
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.18, 0.92, 1.0, 0.54)
	material.emission_enabled = true
	material.emission = Color(0.12, 0.74, 1.0)
	material.emission_energy_multiplier = 2.2
	ring.material_override = material
	target_marker.add_child(ring)
	var label := Label3D.new()
	label.text = "PLACE"
	label.position.y = 0.75
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.pixel_size = 0.006
	label.outline_size = 7
	label.modulate = Color(0.4, 0.96, 1.0)
	target_marker.add_child(label)
	target_marker.visible = false
	scene_root.add_child(target_marker)


func _remove_target_marker() -> void:
	if target_marker != null and is_instance_valid(target_marker):
		target_marker.queue_free()
	target_marker = null


func _build_interface() -> void:
	compact_panel = PanelContainer.new()
	compact_panel.name = "AbilityContextStatus"
	compact_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	compact_panel.position = Vector2(-360.0, -132.0)
	compact_panel.size = Vector2(340.0, 112.0)
	compact_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var compact_style := StyleBoxFlat.new()
	compact_style.bg_color = Color(0.02, 0.045, 0.075, 0.9)
	compact_style.border_color = Color(0.2, 0.82, 0.92, 0.82)
	compact_style.set_border_width_all(2)
	compact_style.set_corner_radius_all(9)
	compact_style.set_content_margin_all(12.0)
	compact_panel.add_theme_stylebox_override("panel", compact_style)
	compact_label = Label.new()
	compact_label.add_theme_font_size_override("font_size", 14)
	compact_label.add_theme_color_override("font_color", Color(0.78, 0.96, 1.0))
	compact_panel.add_child(compact_label)
	add_child(compact_panel)

	radial_root = Control.new()
	radial_root.name = "AbilityContextRadial"
	radial_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radial_root.mouse_filter = Control.MOUSE_FILTER_STOP
	radial_root.visible = false
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.012, 0.025, 0.62)
	radial_root.add_child(dim)
	radial_panel = PanelContainer.new()
	radial_panel.set_anchors_preset(Control.PRESET_CENTER)
	radial_panel.position = Vector2(-280.0, -240.0)
	radial_panel.size = Vector2(560.0, 480.0)
	var radial_style := StyleBoxFlat.new()
	radial_style.bg_color = Color(0.02, 0.04, 0.068, 0.96)
	radial_style.border_color = Color(0.28, 0.86, 0.96, 0.9)
	radial_style.set_border_width_all(2)
	radial_style.set_corner_radius_all(18)
	radial_panel.add_theme_stylebox_override("panel", radial_style)
	radial_root.add_child(radial_panel)
	var surface := Control.new()
	surface.custom_minimum_size = Vector2(560.0, 480.0)
	radial_panel.add_child(surface)
	radial_button_layer = Control.new()
	radial_button_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(radial_button_layer)
	radial_title = Label.new()
	radial_title.position = Vector2(170.0, 190.0)
	radial_title.size = Vector2(220.0, 34.0)
	radial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radial_title.add_theme_font_size_override("font_size", 24)
	radial_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	surface.add_child(radial_title)
	radial_description = Label.new()
	radial_description.position = Vector2(135.0, 228.0)
	radial_description.size = Vector2(290.0, 58.0)
	radial_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radial_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radial_description.add_theme_font_size_override("font_size", 14)
	radial_description.add_theme_color_override("font_color", Color(0.72, 0.86, 0.94))
	surface.add_child(radial_description)
	var instruction := Label.new()
	instruction.position = Vector2(70.0, 436.0)
	instruction.size = Vector2(420.0, 30.0)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.text = "D-pad / Right stick: select   Cast: confirm   B: cancel"
	instruction.add_theme_font_size_override("font_size", 12)
	instruction.add_theme_color_override("font_color", Color(0.58, 0.72, 0.82))
	surface.add_child(instruction)
	add_child(radial_root)

	target_root = Control.new()
	target_root.name = "AbilityContextTargeting"
	target_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_root.visible = false
	target_label = Label.new()
	target_label.set_anchors_preset(Control.PRESET_CENTER)
	target_label.position = Vector2(-230.0, 76.0)
	target_label.size = Vector2(460.0, 64.0)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.add_theme_font_size_override("font_size", 18)
	target_label.add_theme_color_override("font_color", Color(0.48, 0.96, 1.0))
	target_root.add_child(target_label)
	var reticle := Label.new()
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-18.0, -25.0)
	reticle.size = Vector2(36.0, 50.0)
	reticle.text = "+"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.add_theme_font_size_override("font_size", 34)
	reticle.add_theme_color_override("font_color", Color(0.54, 0.98, 1.0))
	target_root.add_child(reticle)
	add_child(target_root)


func _normalize_id(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_")


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	return {
		"modal": modal_active,
		"menu_open": menu_open,
		"targeting": targeting_active,
		"target_valid": target_valid,
		"target_position": target_position,
		"provider": str(provider.name) if provider != null and is_instance_valid(provider) else "none",
		"ability": context_ability.get_spell_id() if context_ability != null else "none",
		"available_actions": get_available_action_ids(),
		"selected_action": get_selected_action_id(),
		"open_count": open_count,
		"commit_count": commit_count,
		"targeting_confirm_count": targeting_confirm_count,
		"controls": "D-pad/right stick select; cast confirm; B cancel",
	}
