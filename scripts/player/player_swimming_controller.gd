extends Node
class_name PlayerSwimmingController

signal water_entered(label: String)
signal water_exited
signal swim_state_changed(state: String)
signal breath_depleted

@export_group("Movement")
@export var surface_swim_speed: float = 4.2
@export var underwater_swim_speed: float = 3.6
@export var sprint_multiplier: float = 1.55
@export var vertical_swim_speed: float = 3.2
@export var surface_body_offset: float = 0.72
@export var buoyancy_response: float = 4.5
@export var current_influence: float = 1.0
@export var water_drag_response: float = 5.5

@export_group("Resources")
@export var maximum_breath_seconds: float = 12.0
@export var breath_recovery_per_second: float = 5.0
@export var sprint_stamina_per_second: float = 3.0
@export var exhaustion_rise_speed: float = 3.8

@export_group("Presentation")
@export var wetness_seconds: float = 5.0
@export var bubble_interval: float = 0.42

var active_volumes: Array[SwimmingWaterVolume] = []
var swimming: bool = false
var underwater: bool = false
var surface_swimming: bool = false
var sprinting: bool = false
var exhausted: bool = false
var water_exit_handoff: bool = false
var breath_seconds: float = 12.0
var wetness_remaining: float = 0.0
var stamina_progress: float = 0.0
var stamina_recovery_progress: float = 0.0
var bubble_timer: float = 0.0
var last_state: String = "DRY"
var last_current: Vector3 = Vector3.ZERO
var live_bubbles: Array[Node3D] = []

var wet_sheen: MeshInstance3D
var wet_material: StandardMaterial3D
var underwater_layer: CanvasLayer
var underwater_tint: ColorRect

@onready var actor: CharacterBody3D = get_parent() as CharacterBody3D
@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState") as PlayerActionState
@onready var climbing_controller: PlayerClimbingController = get_parent().get_node_or_null("ClimbingController") as PlayerClimbingController


func _ready() -> void:
	breath_seconds = maximum_breath_seconds
	_build_wet_sheen()
	_build_underwater_overlay()
	add_to_group("debuggable")


func _process(delta: float) -> void:
	wetness_remaining = maxf(wetness_remaining - delta, 0.0)
	_update_presentation(delta)
	_cleanup_bubbles()


func enter_water(volume: SwimmingWaterVolume) -> void:
	if volume == null or active_volumes.has(volume):
		return
	active_volumes.append(volume)
	if climbing_controller != null and climbing_controller.should_handle_locomotion():
		climbing_controller.reset_climbing()
	if not swimming:
		swimming = true
		wetness_remaining = wetness_seconds
		water_exit_handoff = false
		breath_seconds = maximum_breath_seconds
		if action_state != null:
			action_state.clear_action_locks()
			action_state.begin_manipulation()
		water_entered.emit(volume.water_label)
		_set_state("SURFACE")


func exit_water(volume: SwimmingWaterVolume) -> void:
	active_volumes.erase(volume)
	_prune_volumes()
	if active_volumes.size() > 0:
		return
	swimming = false
	underwater = false
	surface_swimming = false
	sprinting = false
	exhausted = false
	water_exit_handoff = false
	wetness_remaining = wetness_seconds
	last_current = Vector3.ZERO
	if action_state != null:
		action_state.end_manipulation()
	water_exited.emit()
	_set_state("WET EXIT")


func should_handle_locomotion() -> bool:
	_prune_volumes()
	return swimming and not water_exit_handoff and active_volumes.size() > 0


func process_locomotion(delta: float) -> bool:
	if actor == null or not should_handle_locomotion():
		return false
	var surface_y: float = get_surface_y()
	var depth: float = surface_y - actor.global_position.y
	underwater = depth > 1.18
	surface_swimming = not underwater
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera: Camera3D = get_viewport().get_camera_3d()
	var forward: Vector3 = -actor.global_transform.basis.z
	var right: Vector3 = actor.global_transform.basis.x
	if camera != null:
		forward = -camera.global_transform.basis.z
		right = camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	if right.length_squared() <= 0.001:
		right = Vector3.RIGHT
	forward = forward.normalized()
	right = right.normalized()
	var horizontal_direction: Vector3 = right * input_vector.x + forward * -input_vector.y
	if horizontal_direction.length() > 1.0:
		horizontal_direction = horizontal_direction.normalized()
	if horizontal_direction.length_squared() > 0.01:
		var target_yaw: float = atan2(-horizontal_direction.x, -horizontal_direction.z)
		actor.rotation.y = lerp_angle(actor.rotation.y, target_yaw, clampf(delta * 7.0, 0.0, 1.0))
	if surface_swimming and Input.is_action_just_pressed("jump") and _try_water_exit_handoff():
		return false

	sprinting = Input.is_action_pressed("guard") and input_vector.length() > 0.3 and not exhausted
	var movement_speed: float = surface_swim_speed if surface_swimming else underwater_swim_speed
	if sprinting and GameState.get_stat("stamina") > 0:
		movement_speed *= sprint_multiplier
		_drain_sprint_stamina(delta)
	else:
		sprinting = false
		stamina_progress = maxf(stamina_progress - delta, 0.0)
		_recover_swim_stamina(delta)

	var desired_velocity: Vector3 = horizontal_direction * movement_speed
	last_current = sample_total_current()
	desired_velocity += last_current * current_influence
	var ascend: float = Input.get_action_strength("jump")
	var descend: float = Input.get_action_strength("dodge")
	if exhausted:
		desired_velocity.y = exhaustion_rise_speed
	elif underwater or descend > 0.1:
		desired_velocity.y = (ascend - descend) * vertical_swim_speed
		if ascend <= 0.1 and descend <= 0.1:
			desired_velocity.y += clampf(depth * 0.22, 0.0, 0.8)
	else:
		var target_y: float = surface_y - surface_body_offset
		desired_velocity.y = clampf(
			(target_y - actor.global_position.y) * buoyancy_response,
			-vertical_swim_speed,
			vertical_swim_speed
		)

	actor.velocity = actor.velocity.lerp(
		desired_velocity,
		clampf(delta * water_drag_response, 0.0, 1.0)
	)
	actor.move_and_slide()
	_update_breath(delta)
	_update_swim_state()
	return true


func _try_water_exit_handoff() -> bool:
	if actor == null or climbing_controller == null:
		return false
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return false
	var origin: Vector3 = actor.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + forward.normalized() * 1.25
	)
	query.exclude = [actor.get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Node = hit.get("collider") as Node
	if collider == null or not collider.is_in_group("climbable"):
		return false
	if action_state != null:
		action_state.end_manipulation()
	water_exit_handoff = true
	climbing_controller.update_climb_detection()
	if not climbing_controller.should_handle_locomotion():
		water_exit_handoff = false
		if action_state != null:
			action_state.begin_manipulation()
		return false
	_set_state("LEDGE EXIT")
	return true


func _update_breath(delta: float) -> void:
	if underwater:
		breath_seconds = maxf(breath_seconds - delta, 0.0)
		bubble_timer -= delta
		if bubble_timer <= 0.0:
			bubble_timer = bubble_interval
			_spawn_bubble()
		if breath_seconds <= 0.0 and not exhausted:
			exhausted = true
			breath_depleted.emit()
			_show_message("Out of breath — Grace is surfacing!")
	else:
		breath_seconds = minf(
			breath_seconds + breath_recovery_per_second * delta,
			maximum_breath_seconds
		)
		bubble_timer = 0.0
		if breath_seconds >= maximum_breath_seconds * 0.22:
			exhausted = false


func _recover_swim_stamina(delta: float) -> void:
	var maximum: int = GameState.get_stat("max_stamina")
	var current: int = GameState.get_stat("stamina")
	if current >= maximum:
		stamina_recovery_progress = 0.0
		return
	stamina_recovery_progress += 3.2 * delta
	var recovered: int = floori(stamina_recovery_progress)
	if recovered <= 0:
		return
	recovered = mini(recovered, maximum - current)
	GameState.restore_stamina(recovered)
	stamina_recovery_progress -= float(recovered)


func _drain_sprint_stamina(delta: float) -> void:
	stamina_recovery_progress = 0.0
	stamina_progress += sprint_stamina_per_second * delta
	while stamina_progress >= 1.0:
		stamina_progress -= 1.0
		if not GameState.spend_stamina(1):
			sprinting = false
			return


func get_surface_y() -> float:
	var surface_y: float = -INF
	for volume: SwimmingWaterVolume in active_volumes:
		if volume != null and is_instance_valid(volume):
			surface_y = maxf(surface_y, volume.get_surface_y())
	return actor.global_position.y if surface_y == -INF and actor != null else surface_y


func sample_total_current() -> Vector3:
	var result: Vector3 = Vector3.ZERO
	if actor == null:
		return result
	for volume: SwimmingWaterVolume in active_volumes:
		if volume != null and is_instance_valid(volume):
			result += volume.sample_current(actor.global_position)
	return result


func _update_swim_state() -> void:
	if exhausted:
		_set_state("FORCED SURFACE")
	elif underwater and sprinting:
		_set_state("DIVE SPRINT")
	elif underwater:
		_set_state("UNDERWATER")
	elif sprinting:
		_set_state("SURFACE SPRINT")
	else:
		_set_state("SURFACE")


func _set_state(next_state: String) -> void:
	if next_state == last_state:
		return
	last_state = next_state
	swim_state_changed.emit(next_state)


func _prune_volumes() -> void:
	var valid: Array[SwimmingWaterVolume] = []
	for volume: SwimmingWaterVolume in active_volumes:
		if volume != null and is_instance_valid(volume):
			valid.append(volume)
	active_volumes = valid


func _build_wet_sheen() -> void:
	if actor == null:
		return
	wet_sheen = MeshInstance3D.new()
	wet_sheen.name = "WetSheen"
	wet_sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.54
	mesh.height = 2.05
	mesh.radial_segments = 16
	mesh.rings = 4
	wet_sheen.mesh = mesh
	wet_material = StandardMaterial3D.new()
	wet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wet_material.albedo_color = Color(0.28, 0.68, 1.0, 0.0)
	wet_material.emission_enabled = true
	wet_material.emission = Color(0.1, 0.42, 0.8)
	wet_material.emission_energy_multiplier = 0.45
	wet_sheen.material_override = wet_material
	wet_sheen.visible = false
	actor.add_child(wet_sheen)


func _build_underwater_overlay() -> void:
	underwater_layer = CanvasLayer.new()
	underwater_layer.layer = 5
	add_child(underwater_layer)
	underwater_tint = ColorRect.new()
	underwater_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	underwater_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underwater_tint.color = Color(0.02, 0.22, 0.34, 0.0)
	underwater_layer.add_child(underwater_tint)


func _update_presentation(_delta: float) -> void:
	if wet_sheen != null and wet_material != null:
		var wet_weight: float = 1.0 if swimming else clampf(wetness_remaining / maxf(wetness_seconds, 0.01), 0.0, 1.0)
		wet_sheen.visible = wet_weight > 0.01
		var sheen_color: Color = wet_material.albedo_color
		sheen_color.a = wet_weight * (0.2 if underwater else 0.12)
		wet_material.albedo_color = sheen_color
	if underwater_tint != null:
		var target_alpha: float = 0.2 if underwater else 0.0
		underwater_tint.color.a = lerpf(underwater_tint.color.a, target_alpha, 0.12)


func _spawn_bubble() -> void:
	if actor == null or get_tree().current_scene == null:
		return
	var bubble := MeshInstance3D.new()
	bubble.name = "SwimBubble"
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	bubble.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.62, 0.9, 1.0, 0.65)
	material.emission_enabled = true
	material.emission = Color(0.32, 0.72, 1.0)
	material.emission_energy_multiplier = 0.7
	bubble.material_override = material
	get_tree().current_scene.add_child(bubble)
	var head_anchor := actor.get_node_or_null("GraceVisualV1/HeadAnchor") as Node3D
	bubble.global_position = head_anchor.global_position if head_anchor != null else actor.global_position + Vector3.UP * 0.7
	live_bubbles.append(bubble)
	while live_bubbles.size() > 8:
		var oldest: Node3D = live_bubbles.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()
	var tween := bubble.create_tween()
	tween.parallel().tween_property(bubble, "global_position:y", get_surface_y(), 1.2)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 1.2)
	tween.finished.connect(bubble.queue_free)


func _cleanup_bubbles() -> void:
	var valid: Array[Node3D] = []
	for bubble: Node3D in live_bubbles:
		if bubble != null and is_instance_valid(bubble) and not bubble.is_queued_for_deletion():
			valid.append(bubble)
	live_bubbles = valid


func reset_swimming() -> void:
	active_volumes.clear()
	swimming = false
	underwater = false
	surface_swimming = false
	sprinting = false
	exhausted = false
	water_exit_handoff = false
	breath_seconds = maximum_breath_seconds
	wetness_remaining = 0.0
	stamina_progress = 0.0
	stamina_recovery_progress = 0.0
	last_current = Vector3.ZERO
	_set_state("DRY")
	if action_state != null:
		action_state.end_manipulation()


func get_debug_data() -> Dictionary:
	return {
		"swimming": swimming,
		"underwater": underwater,
		"surface": surface_swimming,
		"sprinting": sprinting,
		"exhausted": exhausted,
		"ledge_handoff": water_exit_handoff,
		"state": last_state,
		"breath": snappedf(breath_seconds, 0.1),
		"max_breath": maximum_breath_seconds,
		"surface_y": snappedf(get_surface_y(), 0.01) if swimming else 0.0,
		"current": last_current,
		"wetness": snappedf(wetness_remaining, 0.1),
		"volumes": active_volumes.size(),
	}


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
