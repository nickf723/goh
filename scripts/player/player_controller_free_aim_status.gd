extends "res://scripts/player/player_controller_free_aim.gd"
class_name PlayerControllerFreeAimStatus

const SpellAimPointerScript = preload(
	"res://scripts/player/player_spell_aim_pointer_safe.gd"
)
const FlashAimControllerScript = preload(
	"res://scripts/player/player_flash_aim_controller.gd"
)

@export_range(8.0, 160.0, 1.0) var free_aim_ray_distance: float = 80.0

@export_group("Spell Camera Brush")
@export_range(-89.0, -30.0, 1.0) var spell_brush_min_pitch_degrees: float = -84.0
@export_range(30.0, 89.0, 1.0) var spell_brush_max_pitch_degrees: float = 78.0
@export_range(0.1, 1.0, 0.05) var spell_brush_mouse_sensitivity_scale: float = 0.5
@export_range(0.1, 1.0, 0.05) var spell_brush_controller_sensitivity_scale: float = 0.58

var player_status_receiver: PlayerStatusReceiver
var spell_aim_pointer: PlayerSpellAimPointer
var flash_aim_controller: PlayerFlashAimController
var preserved_step_velocity: Vector3 = Vector3.ZERO
var restore_step_velocity_after_move: bool = false

var spell_camera_brush_active: bool = false
var spell_camera_brush_owner: Node
var spell_camera_brush_saved_pitch: float = 0.0
var spell_camera_brush_saved_min_pitch: float = 0.0
var spell_camera_brush_saved_max_pitch: float = 0.0
var spell_camera_brush_mouse_scale: float = 0.5
var spell_camera_brush_controller_scale: float = 0.58
var spell_camera_brush_input_count: int = 0
var spell_camera_brush_recenter_count: int = 0
var spell_camera_brush_last_end_reason: String = "never_started"


func _ready() -> void:
	super._ready()
	player_status_receiver = get_node_or_null(
		"StatusReceiver"
	) as PlayerStatusReceiver
	_ensure_spell_aim_pointer()
	_ensure_flash_aim_controller()


func _process(delta: float) -> void:
	if (
		spell_camera_brush_active
		and (
			spell_camera_brush_owner == null
			or not is_instance_valid(spell_camera_brush_owner)
		)
	):
		end_spell_camera_brush(null, "owner_freed", true)
	super._process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if (
		spell_camera_brush_active
		and not is_focus_spell_menu_open()
	):
		if event is InputEventMouseMotion:
			var motion: InputEventMouseMotion = event as InputEventMouseMotion
			_apply_spell_camera_brush_look(
				motion.relative,
				mouse_sensitivity * spell_camera_brush_mouse_scale
			)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("lock_on"):
			recenter_spell_camera_brush()
			get_viewport().set_input_as_handled()
			return

	if (
		spell_aim_pointer != null
		and spell_aim_pointer.captures_look_input()
		and not is_focus_spell_menu_open()
	):
		if event is InputEventMouseMotion:
			spell_aim_pointer.handle_mouse_motion(
				(event as InputEventMouseMotion).relative
			)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("lock_on"):
			spell_aim_pointer.recenter()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func update_controller_camera(delta: float) -> void:
	if spell_camera_brush_active and not is_focus_spell_menu_open():
		var look_vector: Vector2 = Input.get_vector(
			"camera_left",
			"camera_right",
			"camera_up",
			"camera_down"
		)
		var strength: float = look_vector.length()
		if strength < controller_camera_deadzone:
			return
		var resolved_strength: float = inverse_lerp(
			controller_camera_deadzone,
			1.0,
			clampf(strength, controller_camera_deadzone, 1.0)
		)
		var resolved_look: Vector2 = (
			look_vector.normalized() * resolved_strength
		)
		_apply_spell_camera_brush_look(
			resolved_look,
			controller_camera_sensitivity
			* spell_camera_brush_controller_scale
			* maxf(delta, 0.0)
		)
		return

	if (
		spell_aim_pointer != null
		and spell_aim_pointer.captures_look_input()
		and not is_focus_spell_menu_open()
	):
		spell_aim_pointer.advance_controller_input(delta)
		return
	super.update_controller_camera(delta)


func begin_spell_camera_brush(
	owner: Node,
	options: Dictionary = {}
) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if spell_camera_brush_active:
		if spell_camera_brush_owner == owner:
			return true
		end_spell_camera_brush(
			spell_camera_brush_owner,
			"replaced",
			true
		)

	spell_camera_brush_saved_pitch = camera_pitch
	spell_camera_brush_saved_min_pitch = min_pitch
	spell_camera_brush_saved_max_pitch = max_pitch
	spell_camera_brush_owner = owner
	spell_camera_brush_active = true
	spell_camera_brush_last_end_reason = "active"
	spell_camera_brush_mouse_scale = clampf(
		float(options.get(
			"mouse_sensitivity_scale",
			spell_brush_mouse_sensitivity_scale
		)),
		0.05,
		1.0
	)
	spell_camera_brush_controller_scale = clampf(
		float(options.get(
			"controller_sensitivity_scale",
			spell_brush_controller_sensitivity_scale
		)),
		0.05,
		1.0
	)

	var brush_min_pitch: float = deg_to_rad(float(options.get(
		"min_pitch_degrees",
		spell_brush_min_pitch_degrees
	)))
	var brush_max_pitch: float = deg_to_rad(float(options.get(
		"max_pitch_degrees",
		spell_brush_max_pitch_degrees
	)))
	if brush_min_pitch > brush_max_pitch:
		var swapped_pitch: float = brush_min_pitch
		brush_min_pitch = brush_max_pitch
		brush_max_pitch = swapped_pitch
	min_pitch = brush_min_pitch
	max_pitch = brush_max_pitch
	camera_pitch = clampf(camera_pitch, min_pitch, max_pitch)
	if camera_pivot != null:
		camera_pivot.rotation.x = camera_pitch
	if has_lock_on_target():
		clear_lock_on()
	set_meta("spell_camera_brush_active", true)
	set_meta("spell_camera_brush_owner", str(owner.name))
	set_meta("spell_camera_brush_pitch", camera_pitch)
	return true


func end_spell_camera_brush(
	owner: Node = null,
	reason: String = "released",
	force: bool = false
) -> bool:
	if not spell_camera_brush_active:
		return false
	if (
		not force
		and owner != null
		and owner != spell_camera_brush_owner
	):
		return false

	spell_camera_brush_active = false
	spell_camera_brush_owner = null
	spell_camera_brush_last_end_reason = reason
	min_pitch = spell_camera_brush_saved_min_pitch
	max_pitch = spell_camera_brush_saved_max_pitch
	camera_pitch = clampf(
		spell_camera_brush_saved_pitch,
		min_pitch,
		max_pitch
	)
	if camera_pivot != null:
		camera_pivot.rotation.x = camera_pitch
	remove_meta("spell_camera_brush_active")
	remove_meta("spell_camera_brush_owner")
	remove_meta("spell_camera_brush_pitch")
	return true


func is_spell_camera_brush_active() -> bool:
	return spell_camera_brush_active


func is_spell_camera_brush_owned_by(owner: Node) -> bool:
	return (
		spell_camera_brush_active
		and owner != null
		and spell_camera_brush_owner == owner
		and is_instance_valid(owner)
	)


func recenter_spell_camera_brush() -> void:
	if not spell_camera_brush_active:
		return
	camera_pitch = clampf(
		spell_camera_brush_saved_pitch,
		min_pitch,
		max_pitch
	)
	if camera_pivot != null:
		camera_pivot.rotation.x = camera_pitch
	set_meta("spell_camera_brush_pitch", camera_pitch)
	spell_camera_brush_recenter_count += 1


func apply_spell_camera_brush_look_for_test(
	look_delta: Vector2,
	radians_per_unit: float = 0.0025
) -> void:
	_apply_spell_camera_brush_look(
		look_delta,
		maxf(radians_per_unit, 0.00001)
	)


func _apply_spell_camera_brush_look(
	look_delta: Vector2,
	radians_per_unit: float
) -> void:
	if not spell_camera_brush_active:
		return
	rotate_y(-look_delta.x * radians_per_unit)
	camera_pitch -= look_delta.y * radians_per_unit
	camera_pitch = clampf(camera_pitch, min_pitch, max_pitch)
	if camera_pivot != null:
		camera_pivot.rotation.x = camera_pitch
	set_meta("spell_camera_brush_pitch", camera_pitch)
	spell_camera_brush_input_count += 1


func get_lock_on_cast_direction(cast_origin: Vector3 = Vector3.ZERO) -> Vector3:
	if has_lock_on_target():
		return super.get_lock_on_cast_direction(cast_origin)

	var soft_direction: Vector3 = get_soft_aim_cast_direction(cast_origin)
	if soft_direction.length_squared() > 0.0001:
		return soft_direction.normalized()

	var converged_direction: Vector3 = get_camera_center_cast_direction(cast_origin)
	if converged_direction.length_squared() > 0.0001:
		return converged_direction.normalized()

	var fallback: Vector3 = -global_transform.basis.z
	fallback.y = 0.0
	return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector3.FORWARD


func get_camera_center_cast_direction(cast_origin: Vector3 = Vector3.ZERO) -> Vector3:
	var resolved_origin: Vector3 = cast_origin
	if resolved_origin == Vector3.ZERO:
		resolved_origin = global_position + Vector3.UP * lock_on_cast_origin_height

	if spell_aim_pointer != null and spell_aim_pointer.is_aim_active():
		return spell_aim_pointer.get_converged_direction(
			resolved_origin,
			free_aim_ray_distance,
			collision_mask,
			true,
			true,
			get_free_aim_exclusion_rids()
		)

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO

	var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
	var screen_center: Vector2 = viewport_rect.position + viewport_rect.size * 0.5
	var ray_origin: Vector3 = camera.project_ray_origin(screen_center)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_center).normalized()
	if ray_direction.length_squared() <= 0.0001:
		return Vector3.ZERO

	var aim_point: Vector3 = ray_origin + ray_direction * free_aim_ray_distance
	var world: World3D = get_world_3d()
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(ray_origin, aim_point)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.exclude = get_free_aim_exclusion_rids()
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		var hit_position: Variant = hit.get("position", null)
		if hit_position is Vector3:
			aim_point = hit_position as Vector3

	return resolve_projectile_direction_to_point(resolved_origin, aim_point)


func resolve_projectile_direction_to_point(
	cast_origin: Vector3,
	aim_point: Vector3
) -> Vector3:
	var direction: Vector3 = aim_point - cast_origin
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	return direction.normalized()


func get_free_aim_exclusion_rids() -> Array[RID]:
	var exclusions: Array[RID] = []
	_collect_collision_rids(self, exclusions)
	return exclusions


func _collect_collision_rids(node: Node, exclusions: Array[RID]) -> void:
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		var rid: RID = collision_object.get_rid()
		if rid.is_valid() and not exclusions.has(rid):
			exclusions.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, exclusions)


func handle_lock_on_target_switch_input() -> void:
	if is_focus_spell_menu_open():
		return
	if spell_camera_brush_active:
		return
	if spell_aim_pointer != null and spell_aim_pointer.captures_look_input():
		return
	super.handle_lock_on_target_switch_input()


func get_spell_aim_pointer() -> PlayerSpellAimPointer:
	return spell_aim_pointer


func is_spell_aim_pointer_active() -> bool:
	return spell_aim_pointer != null and spell_aim_pointer.is_aim_active()


func _ensure_spell_aim_pointer() -> void:
	spell_aim_pointer = get_node_or_null(
		"SpellAimPointer"
	) as PlayerSpellAimPointer
	if spell_aim_pointer != null:
		return
	spell_aim_pointer = SpellAimPointerScript.new() as PlayerSpellAimPointer
	spell_aim_pointer.name = "SpellAimPointer"
	add_child(spell_aim_pointer)


func _ensure_flash_aim_controller() -> void:
	flash_aim_controller = get_node_or_null(
		"FlashAimController"
	) as PlayerFlashAimController
	if flash_aim_controller != null:
		return
	flash_aim_controller = FlashAimControllerScript.new() as PlayerFlashAimController
	flash_aim_controller.name = "FlashAimController"
	add_child(flash_aim_controller)


func _get_requested_ground_velocity() -> Vector3:
	var benchmark_free_roam: bool = bool(
		get_meta("benchmark_free_roam", false)
	)
	if (
		not benchmark_free_roam
		and bool(get_meta("shared_placement_active", false))
	):
		return Vector3.ZERO
	var requested: Vector3 = super._get_requested_ground_velocity()
	if benchmark_free_roam or player_status_receiver == null:
		return requested
	return requested * clampf(
		player_status_receiver.get_movement_multiplier(),
		0.0,
		1.0
	)


func _item_allows_jump() -> bool:
	if (
		not bool(get_meta("benchmark_free_roam", false))
		and bool(get_meta("shared_placement_active", false))
	):
		return false
	return super._item_allows_jump()


func get_status_locomotion_debug_data() -> Dictionary:
	return {
		"active_controller": get_script().resource_path,
		"benchmark_free_roam": bool(
			get_meta("benchmark_free_roam", false)
		),
		"shared_placement_active": bool(
			get_meta("shared_placement_active", false)
		),
		"status_multiplier": (
			player_status_receiver.get_movement_multiplier()
			if player_status_receiver != null
			else 1.0
		),
	}


func _try_step_up(horizontal_velocity: Vector3, delta: float) -> bool:
	restore_step_velocity_after_move = false
	preserved_step_velocity = Vector3.ZERO
	if step_up_controller == null:
		return false

	var actual_planar_velocity: Vector3 = Vector3(
		velocity.x,
		0.0,
		velocity.z
	)
	if actual_planar_velocity.length_squared() <= 0.0001:
		actual_planar_velocity = horizontal_velocity
		actual_planar_velocity.y = 0.0

	var stepped: bool = step_up_controller.try_step_up(
		actual_planar_velocity,
		delta
	)
	if not stepped:
		return false

	preserved_step_velocity = actual_planar_velocity
	velocity.x = 0.0
	velocity.z = 0.0
	restore_step_velocity_after_move = true
	return true


func _finish_step_up() -> void:
	super._finish_step_up()
	if not restore_step_velocity_after_move:
		return
	velocity.x = preserved_step_velocity.x
	velocity.z = preserved_step_velocity.z
	preserved_step_velocity = Vector3.ZERO
	restore_step_velocity_after_move = false


func get_spell_camera_brush_debug_data() -> Dictionary:
	return {
		"active": spell_camera_brush_active,
		"owner": (
			str(spell_camera_brush_owner.name)
			if spell_camera_brush_owner != null
			and is_instance_valid(spell_camera_brush_owner)
			else "none"
		),
		"camera_pitch_degrees": rad_to_deg(camera_pitch),
		"minimum_pitch_degrees": rad_to_deg(min_pitch),
		"maximum_pitch_degrees": rad_to_deg(max_pitch),
		"saved_pitch_degrees": rad_to_deg(spell_camera_brush_saved_pitch),
		"mouse_scale": spell_camera_brush_mouse_scale,
		"controller_scale": spell_camera_brush_controller_scale,
		"input_count": spell_camera_brush_input_count,
		"recenter_count": spell_camera_brush_recenter_count,
		"last_end_reason": spell_camera_brush_last_end_reason,
	}


func get_spell_aim_debug_data() -> Dictionary:
	return {
		"pointer": (
			spell_aim_pointer.get_debug_data()
			if spell_aim_pointer != null
			else {}
		),
		"flash_aim": (
			flash_aim_controller.get_debug_data()
			if flash_aim_controller != null
			else {}
		),
		"camera_brush": get_spell_camera_brush_debug_data(),
	}
