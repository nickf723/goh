extends Node3D
class_name SoulThreadLink

signal thread_bound(source_actor: Node3D, target_actor: Node3D)
signal thread_refreshed(duration: float)
signal thread_broken(reason: String)

@export_group("Lifetime")
@export_range(0.5, 30.0, 0.1) var duration_seconds: float = 8.0
@export_range(1.0, 30.0, 0.1) var break_distance: float = 15.0

@export_group("Soul Leash")
@export_range(0.0, 20.0, 0.1) var slack_distance: float = 5.0
@export_range(0.0, 40.0, 0.1) var character_pull_acceleration: float = 8.0
@export_range(0.0, 15.0, 0.1) var maximum_character_pull_speed: float = 3.5
@export_range(0.0, 500.0, 1.0) var rigid_pull_force: float = 72.0
@export_range(0.0, 1.0, 0.05) var boss_pull_multiplier: float = 0.28

@export_group("Presentation")
@export_range(0.01, 0.35, 0.01) var thread_width: float = 0.055
@export_range(0.0, 3.0, 0.05) var source_height: float = 1.0
@export_range(0.0, 3.0, 0.05) var target_height: float = 0.85

var source_actor: Node3D = null
var target_actor: Node3D = null
var duration_remaining: float = 0.0
var bound: bool = false
var last_distance: float = 0.0
var last_tension: float = 0.0
var total_pull_steps: int = 0
var break_reason: String = "none"

var thread_visual: MeshInstance3D = null
var thread_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("soul_thread_links")
	add_to_group("debuggable")
	_build_visual()
	set_process(false)
	set_physics_process(false)


func bind_to_actors(new_source: Node3D, new_target: Node3D) -> bool:
	if new_source == null or new_target == null or new_source == new_target:
		return false
	source_actor = new_source
	target_actor = new_target
	duration_remaining = maxf(duration_seconds, 0.5)
	break_reason = "none"
	bound = true
	_mark_target(true)
	_update_visual()
	set_process(true)
	set_physics_process(true)
	thread_bound.emit(source_actor, target_actor)
	return true


func refresh_thread(new_duration: float = -1.0) -> void:
	if not bound:
		return
	var resolved_duration: float = duration_seconds if new_duration <= 0.0 else new_duration
	duration_remaining = maxf(duration_remaining, resolved_duration)
	thread_refreshed.emit(duration_remaining)


func matches_link(candidate_source: Node, candidate_target: Node) -> bool:
	return (
		bound
		and source_actor == candidate_source
		and target_actor == candidate_target
	)


func _process(delta: float) -> void:
	if not bound:
		return
	if not _actors_valid():
		break_thread("actor_invalid")
		return
	duration_remaining = maxf(duration_remaining - maxf(delta, 0.0), 0.0)
	if duration_remaining <= 0.0:
		break_thread("expired")
		return
	last_distance = source_actor.global_position.distance_to(target_actor.global_position)
	if last_distance > maxf(break_distance, slack_distance + 0.1):
		break_thread("range")
		return
	_update_visual()


func _physics_process(delta: float) -> void:
	if not bound or not _actors_valid():
		return
	var source_position: Vector3 = source_actor.global_position + Vector3.UP * source_height
	var target_position: Vector3 = target_actor.global_position + Vector3.UP * target_height
	var offset: Vector3 = source_position - target_position
	var distance: float = offset.length()
	last_distance = distance
	var slack: float = maxf(slack_distance, 0.0)
	if distance <= slack or distance <= 0.001:
		last_tension = 0.0
		return
	var tension_window: float = maxf(break_distance - slack, 0.1)
	last_tension = clampf((distance - slack) / tension_window, 0.0, 1.0)
	_apply_soft_pull(offset.normalized(), maxf(delta, 0.0), last_tension)


func _apply_soft_pull(direction_to_source: Vector3, delta: float, tension: float) -> void:
	if target_actor == null or tension <= 0.0:
		return
	var multiplier: float = 1.0
	if target_actor.is_in_group("boss") or bool(target_actor.get_meta("boss", false)):
		multiplier = boss_pull_multiplier
	multiplier *= clampf(tension, 0.0, 1.0)
	if multiplier <= 0.001:
		return

	if target_actor.has_method("receive_soul_thread_pull"):
		target_actor.call(
			"receive_soul_thread_pull",
			direction_to_source,
			character_pull_acceleration * multiplier,
			delta,
			self
		)
		total_pull_steps += 1
		return

	if target_actor is RigidBody3D:
		(target_actor as RigidBody3D).apply_central_force(
			direction_to_source * rigid_pull_force * multiplier
		)
		total_pull_steps += 1
		return

	var velocity_value: Variant = target_actor.get("velocity")
	if velocity_value is Vector3:
		var velocity: Vector3 = velocity_value as Vector3
		var pull_delta: Vector3 = (
			direction_to_source
			* character_pull_acceleration
			* multiplier
			* delta
		)
		var horizontal_pull := Vector3(pull_delta.x, 0.0, pull_delta.z)
		if horizontal_pull.length() > maximum_character_pull_speed:
			horizontal_pull = horizontal_pull.normalized() * maximum_character_pull_speed
		velocity += horizontal_pull
		target_actor.set("velocity", velocity)
		total_pull_steps += 1


func break_thread(reason: String = "manual") -> void:
	if not bound:
		return
	bound = false
	break_reason = reason
	_mark_target(false)
	set_process(false)
	set_physics_process(false)
	thread_broken.emit(reason)
	queue_free()


func _actors_valid() -> bool:
	return (
		source_actor != null
		and target_actor != null
		and is_instance_valid(source_actor)
		and is_instance_valid(target_actor)
		and source_actor.is_inside_tree()
		and target_actor.is_inside_tree()
	)


func _mark_target(active: bool) -> void:
	if target_actor == null or not is_instance_valid(target_actor):
		return
	if active:
		target_actor.set_meta("soul_threaded", true)
		target_actor.set_meta("soul_thread_source_id", source_actor.get_instance_id() if source_actor != null else 0)
		target_actor.set_meta("soul_thread_link_id", get_instance_id())
		if not target_actor.is_in_group("soul_threaded_targets"):
			target_actor.add_to_group("soul_threaded_targets")
		return
	var link_id: int = int(target_actor.get_meta("soul_thread_link_id", 0))
	if link_id != get_instance_id():
		return
	target_actor.remove_meta("soul_threaded")
	target_actor.remove_meta("soul_thread_source_id")
	target_actor.remove_meta("soul_thread_link_id")
	if target_actor.is_in_group("soul_threaded_targets"):
		target_actor.remove_from_group("soul_threaded_targets")


func _build_visual() -> void:
	thread_visual = MeshInstance3D.new()
	thread_visual.name = "SoulThreadVisual"
	thread_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thread_width, thread_width, 1.0)
	thread_visual.mesh = mesh
	thread_material = StandardMaterial3D.new()
	thread_material.albedo_color = Color(0.22, 0.94, 1.0, 0.72)
	thread_material.emission_enabled = true
	thread_material.emission = Color(0.15, 0.78, 1.0, 1.0)
	thread_material.emission_energy_multiplier = 2.4
	thread_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	thread_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	thread_visual.material_override = thread_material
	add_child(thread_visual)


func _update_visual() -> void:
	if thread_visual == null or not _actors_valid():
		return
	var start_position: Vector3 = source_actor.global_position + Vector3.UP * source_height
	var end_position: Vector3 = target_actor.global_position + Vector3.UP * target_height
	var length: float = maxf(start_position.distance_to(end_position), 0.01)
	thread_visual.global_position = (start_position + end_position) * 0.5
	thread_visual.look_at(end_position, Vector3.UP)
	thread_visual.scale = Vector3(1.0, 1.0, length)
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.12
	thread_visual.scale.x = pulse
	thread_visual.scale.y = pulse


func get_debug_data() -> Dictionary:
	return {
		"soul_thread_link": true,
		"persistent_actor_link": true,
		"bound": bound,
		"source": source_actor.name if source_actor != null and is_instance_valid(source_actor) else "none",
		"target": target_actor.name if target_actor != null and is_instance_valid(target_actor) else "none",
		"remaining": snappedf(duration_remaining, 0.1),
		"distance": snappedf(last_distance, 0.1),
		"tension": snappedf(last_tension, 0.01),
		"pull_steps": total_pull_steps,
		"break_reason": break_reason,
	}
