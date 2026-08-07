extends Node
class_name PlayerSpellAimPointer

signal aim_started(owner_name: String, mode_id: String)
signal aim_ended(owner_name: String, reason: String)
signal pointer_moved(logical_position: Vector2, display_position: Vector2)
signal target_state_changed(valid: bool, status_text: String)

@export_group("Pointer Motion")
@export_range(0.05, 4.0, 0.05) var controller_speed_screens_per_second: float = 1.15
@export_range(0.1, 4.0, 0.05) var mouse_motion_scale: float = 1.0
@export_range(0.0, 0.95, 0.05) var controller_deadzone: float = 0.16
@export_range(0.0, 2.0, 0.05) var default_horizontal_overflow_screens: float = 0.55
@export_range(0.0, 4.0, 0.05) var default_vertical_overflow_screens: float = 1.4
@export_range(0.0, 80.0, 1.0) var visible_margin_pixels: float = 24.0

@export_group("Presentation")
@export_range(24.0, 72.0, 1.0) var reticle_size: float = 42.0
@export_range(10, 32, 1) var reticle_font_size: int = 23
@export_range(8, 24, 1) var status_font_size: int = 13
@export_range(0.5, 4.0, 0.1) var guide_line_width: float = 1.4
@export var default_pointer_color: Color = Color(0.44, 0.76, 1.0, 1.0)
@export var invalid_pointer_color: Color = Color(1.0, 0.28, 0.14, 1.0)

var actor: Node3D
var active_owner: Node
var active: bool = false
var capture_look_input: bool = true
var mode_id: String = "aim"
var logical_position: Vector2 = Vector2(0.5, 0.5)
var display_position: Vector2 = Vector2.ZERO
var horizontal_overflow_screens: float = 0.55
var vertical_overflow_screens: float = 1.4
var pointer_color: Color = Color(0.44, 0.76, 1.0, 1.0)
var target_valid: bool = true
var status_text: String = ""
var last_viewport_size: Vector2 = Vector2.ZERO
var pointer_update_count: int = 0
var controller_input_count: int = 0
var mouse_input_count: int = 0
var offscreen_update_count: int = 0
var last_ray_direction: Vector3 = Vector3.FORWARD

var canvas_layer: CanvasLayer
var ui_root: Control
var guide_line: Line2D
var reticle_panel: PanelContainer
var reticle_label: Label
var status_label: Label
var valid_style: StyleBoxFlat
var invalid_style: StyleBoxFlat


func _ready() -> void:
	actor = get_parent() as Node3D
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player_spell_aim_pointers")
	add_to_group("debuggable")
	_build_ui()
	_set_ui_visible(false)
	set_process(false)


func _process(_delta: float) -> void:
	if not active:
		return
	if active_owner == null or not is_instance_valid(active_owner):
		end_aim(null, "owner_freed", true)
		return
	var viewport_size: Vector2 = _get_viewport_size()
	if viewport_size != last_viewport_size:
		_update_visuals()


func begin_aim(owner: Node, options: Dictionary = {}) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if active and active_owner != owner:
		end_aim(active_owner, "replaced")

	active_owner = owner
	active = true
	capture_look_input = bool(options.get("capture_look", true))
	mode_id = str(options.get("mode_id", "aim"))
	horizontal_overflow_screens = maxf(
		float(options.get(
			"horizontal_overflow_screens",
			default_horizontal_overflow_screens
		)),
		0.0
	)
	vertical_overflow_screens = maxf(
		float(options.get(
			"vertical_overflow_screens",
			default_vertical_overflow_screens
		)),
		0.0
	)
	var color_value: Variant = options.get("color", default_pointer_color)
	pointer_color = (
		color_value as Color
		if color_value is Color
		else default_pointer_color
	)
	target_valid = bool(options.get("target_valid", true))
	status_text = str(options.get("status_text", ""))
	var initial_value: Variant = options.get(
		"initial_normalized_position",
		Vector2(0.5, 0.5)
	)
	logical_position = (
		initial_value as Vector2
		if initial_value is Vector2
		else Vector2(0.5, 0.5)
	)
	_clamp_logical_position()

	if actor != null:
		actor.set_meta("spell_aim_pointer_active", true)
		actor.set_meta("spell_aim_pointer_mode", mode_id)
		actor.set_meta("spell_aim_pointer_owner", str(owner.name))
		if actor.has_method("clear_lock_on"):
			actor.call("clear_lock_on")

	_set_ui_visible(true)
	_update_visuals()
	set_process(true)
	aim_started.emit(str(owner.name), mode_id)
	return true


func end_aim(
	owner: Node = null,
	reason: String = "released",
	force: bool = false
) -> bool:
	if not active:
		return false
	if not force and owner != null and owner != active_owner:
		return false
	var owner_name: String = (
		str(active_owner.name)
		if active_owner != null and is_instance_valid(active_owner)
		else "unknown"
	)
	active = false
	active_owner = null
	capture_look_input = false
	mode_id = "aim"
	status_text = ""
	target_valid = true
	if actor != null and is_instance_valid(actor):
		actor.remove_meta("spell_aim_pointer_active")
		actor.remove_meta("spell_aim_pointer_mode")
		actor.remove_meta("spell_aim_pointer_owner")
		actor.remove_meta("spell_aim_pointer_logical_position")
	_set_ui_visible(false)
	set_process(false)
	aim_ended.emit(owner_name, reason)
	return true


func is_aim_active() -> bool:
	return active


func is_owned_by(owner: Node) -> bool:
	return (
		active
		and owner != null
		and active_owner == owner
		and is_instance_valid(owner)
	)


func captures_look_input() -> bool:
	return active and capture_look_input


func recenter() -> void:
	if not active:
		return
	logical_position = Vector2(0.5, 0.5)
	_update_visuals()


func handle_mouse_motion(relative_motion: Vector2) -> bool:
	if not captures_look_input():
		return false
	var viewport_size: Vector2 = _get_viewport_size()
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return false
	logical_position += Vector2(
		relative_motion.x / viewport_size.x,
		relative_motion.y / viewport_size.y
	) * maxf(mouse_motion_scale, 0.01)
	mouse_input_count += 1
	_clamp_logical_position()
	_update_visuals()
	return true


func advance_controller_input(delta: float) -> bool:
	if not captures_look_input():
		return false
	var look_vector: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)
	var strength: float = look_vector.length()
	if strength < controller_deadzone:
		return false
	var normalized_strength: float = inverse_lerp(
		controller_deadzone,
		1.0,
		clampf(strength, controller_deadzone, 1.0)
	)
	var resolved: Vector2 = look_vector.normalized() * normalized_strength
	logical_position += resolved * maxf(
		controller_speed_screens_per_second,
		0.01
	) * maxf(delta, 0.0)
	controller_input_count += 1
	_clamp_logical_position()
	_update_visuals()
	return true


func set_logical_position_for_test(value: Vector2) -> void:
	logical_position = value
	_clamp_logical_position()
	_update_visuals()


func get_logical_position() -> Vector2:
	return logical_position


func get_display_position() -> Vector2:
	return display_position


func get_virtual_screen_position() -> Vector2:
	var viewport_rect: Rect2 = _get_viewport_rect()
	return viewport_rect.position + Vector2(
		logical_position.x * viewport_rect.size.x,
		logical_position.y * viewport_rect.size.y
	)


func get_world_ray(maximum_distance: float = 100.0) -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		var fallback_direction: Vector3 = (
			-actor.global_transform.basis.z
			if actor != null
			else Vector3.FORWARD
		)
		fallback_direction = (
			fallback_direction.normalized()
			if fallback_direction.length_squared() > 0.0001
			else Vector3.FORWARD
		)
		last_ray_direction = fallback_direction
		var fallback_origin: Vector3 = (
			actor.global_position + Vector3.UP
			if actor != null
			else Vector3.ZERO
		)
		return {
			"valid": false,
			"origin": fallback_origin,
			"direction": fallback_direction,
			"end": fallback_origin + fallback_direction * maximum_distance,
			"screen_position": Vector2.ZERO,
		}

	var virtual_position: Vector2 = get_virtual_screen_position()
	var ray_origin: Vector3 = camera.project_ray_origin(virtual_position)
	var ray_direction: Vector3 = camera.project_ray_normal(virtual_position)
	if ray_direction.length_squared() <= 0.0001:
		ray_direction = -camera.global_transform.basis.z
	if ray_direction.length_squared() <= 0.0001:
		ray_direction = Vector3.FORWARD
	ray_direction = ray_direction.normalized()
	last_ray_direction = ray_direction
	return {
		"valid": true,
		"origin": ray_origin,
		"direction": ray_direction,
		"end": ray_origin + ray_direction * maxf(maximum_distance, 0.01),
		"screen_position": virtual_position,
	}


func get_ray_direction() -> Vector3:
	return get_world_ray(1.0).get(
		"direction",
		Vector3.FORWARD
	) as Vector3


func get_converged_direction(
	cast_origin: Vector3,
	maximum_distance: float = 100.0,
	collision_mask: int = 1,
	collide_with_areas: bool = true,
	collide_with_bodies: bool = true,
	exclusions: Array[RID] = []
) -> Vector3:
	var ray: Dictionary = get_world_ray(maximum_distance)
	var aim_point: Vector3 = ray.get("end", cast_origin + Vector3.FORWARD) as Vector3
	var world: World3D = actor.get_world_3d() if actor != null else null
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(
			ray.get("origin", cast_origin) as Vector3,
			aim_point,
			collision_mask
		)
		query.collide_with_areas = collide_with_areas
		query.collide_with_bodies = collide_with_bodies
		query.exclude = exclusions
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		var hit_position: Variant = hit.get("position")
		if hit_position is Vector3:
			aim_point = hit_position as Vector3
	var direction: Vector3 = aim_point - cast_origin
	if direction.length_squared() <= 0.0001:
		direction = ray.get("direction", Vector3.FORWARD) as Vector3
	return (
		direction.normalized()
		if direction.length_squared() > 0.0001
		else Vector3.FORWARD
	)


func set_target_state(
	valid: bool,
	new_status_text: String = ""
) -> void:
	var changed: bool = target_valid != valid or status_text != new_status_text
	target_valid = valid
	status_text = new_status_text
	if changed:
		_update_visuals()
		target_state_changed.emit(target_valid, status_text)


func set_status_text(new_status_text: String) -> void:
	if status_text == new_status_text:
		return
	status_text = new_status_text
	_update_visuals()


func _clamp_logical_position() -> void:
	logical_position.x = clampf(
		logical_position.x,
		-horizontal_overflow_screens,
		1.0 + horizontal_overflow_screens
	)
	logical_position.y = clampf(
		logical_position.y,
		-vertical_overflow_screens,
		1.0 + vertical_overflow_screens
	)


func _build_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "SpellAimPointerCanvas"
	canvas_layer.layer = 92
	add_child(canvas_layer)

	ui_root = Control.new()
	ui_root.name = "SpellAimPointerUI"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(ui_root)

	guide_line = Line2D.new()
	guide_line.name = "AimGuideLine"
	guide_line.width = guide_line_width
	guide_line.default_color = Color(0.44, 0.76, 1.0, 0.28)
	guide_line.antialiased = true
	ui_root.add_child(guide_line)

	valid_style = StyleBoxFlat.new()
	valid_style.bg_color = Color(0.02, 0.04, 0.075, 0.84)
	valid_style.border_color = default_pointer_color
	valid_style.set_border_width_all(2)
	valid_style.set_corner_radius_all(12)

	invalid_style = StyleBoxFlat.new()
	invalid_style.bg_color = Color(0.09, 0.018, 0.012, 0.88)
	invalid_style.border_color = invalid_pointer_color
	invalid_style.set_border_width_all(2)
	invalid_style.set_corner_radius_all(12)

	reticle_panel = PanelContainer.new()
	reticle_panel.name = "AimReticle"
	reticle_panel.size = Vector2(reticle_size, reticle_size)
	reticle_panel.custom_minimum_size = Vector2(reticle_size, reticle_size)
	reticle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(reticle_panel)

	reticle_label = Label.new()
	reticle_label.name = "AimGlyph"
	reticle_label.text = "⊕"
	reticle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle_label.add_theme_font_size_override("font_size", reticle_font_size)
	reticle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle_panel.add_child(reticle_label)

	status_label = Label.new()
	status_label.name = "AimStatus"
	status_label.size = Vector2(300.0, 24.0)
	status_label.custom_minimum_size = Vector2(300.0, 24.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", status_font_size)
	status_label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.9)
	)
	status_label.add_theme_constant_override("outline_size", 5)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(status_label)


func _set_ui_visible(value: bool) -> void:
	if canvas_layer != null:
		canvas_layer.visible = value


func _update_visuals() -> void:
	if not active or ui_root == null:
		return
	var viewport_rect: Rect2 = _get_viewport_rect()
	last_viewport_size = viewport_rect.size
	var margin: Vector2 = Vector2.ONE * minf(
		visible_margin_pixels,
		minf(viewport_rect.size.x, viewport_rect.size.y) * 0.2
	)
	var minimum_position: Vector2 = viewport_rect.position + margin
	var maximum_position: Vector2 = (
		viewport_rect.end - margin
	)
	var virtual_position: Vector2 = get_virtual_screen_position()
	display_position = Vector2(
		clampf(virtual_position.x, minimum_position.x, maximum_position.x),
		clampf(virtual_position.y, minimum_position.y, maximum_position.y)
	)
	var offscreen_x: int = -1 if logical_position.x < 0.0 else 1 if logical_position.x > 1.0 else 0
	var offscreen_y: int = -1 if logical_position.y < 0.0 else 1 if logical_position.y > 1.0 else 0
	var offscreen: bool = offscreen_x != 0 or offscreen_y != 0
	if offscreen:
		offscreen_update_count += 1
	reticle_label.text = _get_reticle_glyph(offscreen_x, offscreen_y)

	var active_color: Color = pointer_color if target_valid else invalid_pointer_color
	valid_style.border_color = pointer_color
	reticle_panel.add_theme_stylebox_override(
		"panel",
		valid_style if target_valid else invalid_style
	)
	reticle_label.add_theme_color_override("font_color", active_color)
	reticle_panel.position = display_position - Vector2.ONE * reticle_size * 0.5

	var center: Vector2 = viewport_rect.position + viewport_rect.size * 0.5
	guide_line.points = PackedVector2Array([center, display_position])
	guide_line.default_color = Color(
		active_color.r,
		active_color.g,
		active_color.b,
		0.3
	)

	status_label.text = status_text
	status_label.visible = status_text != ""
	status_label.add_theme_color_override("font_color", active_color)
	var status_position: Vector2 = display_position + Vector2(-150.0, reticle_size * 0.65)
	status_position.x = clampf(
		status_position.x,
		viewport_rect.position.x + 4.0,
		viewport_rect.end.x - status_label.size.x - 4.0
	)
	status_position.y = clampf(
		status_position.y,
		viewport_rect.position.y + 4.0,
		viewport_rect.end.y - status_label.size.y - 4.0
	)
	status_label.position = status_position

	pointer_update_count += 1
	if actor != null:
		actor.set_meta("spell_aim_pointer_logical_position", logical_position)
		actor.set_meta("spell_aim_pointer_display_position", display_position)
	pointer_moved.emit(logical_position, display_position)


func _get_reticle_glyph(offscreen_x: int, offscreen_y: int) -> String:
	if offscreen_x == 0 and offscreen_y == 0:
		return "⊕"
	if offscreen_x < 0 and offscreen_y < 0:
		return "↖"
	if offscreen_x > 0 and offscreen_y < 0:
		return "↗"
	if offscreen_x < 0 and offscreen_y > 0:
		return "↙"
	if offscreen_x > 0 and offscreen_y > 0:
		return "↘"
	if offscreen_x < 0:
		return "←"
	if offscreen_x > 0:
		return "→"
	return "↑" if offscreen_y < 0 else "↓"


func _get_viewport_rect() -> Rect2:
	var rect: Rect2 = get_viewport().get_visible_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	return rect


func _get_viewport_size() -> Vector2:
	return _get_viewport_rect().size


func get_debug_data() -> Dictionary:
	var offscreen: bool = (
		logical_position.x < 0.0
		or logical_position.x > 1.0
		or logical_position.y < 0.0
		or logical_position.y > 1.0
	)
	return {
		"spell_aim_pointer": true,
		"active": active,
		"owner": (
			str(active_owner.name)
			if active_owner != null and is_instance_valid(active_owner)
			else "none"
		),
		"mode": mode_id,
		"captures_look": captures_look_input(),
		"logical_position": logical_position,
		"display_position": display_position,
		"virtual_screen_position": get_virtual_screen_position(),
		"offscreen": offscreen,
		"horizontal_overflow": horizontal_overflow_screens,
		"vertical_overflow": vertical_overflow_screens,
		"target_valid": target_valid,
		"status": status_text,
		"last_ray_direction": last_ray_direction,
		"updates": pointer_update_count,
		"controller_inputs": controller_input_count,
		"mouse_inputs": mouse_input_count,
		"offscreen_updates": offscreen_update_count,
		"processing": is_processing(),
	}
