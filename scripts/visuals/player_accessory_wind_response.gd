extends Node
class_name PlayerAccessoryWindResponse

@export_range(0.0, 2.0, 0.01) var sash_response_scale: float = 0.72
@export_range(0.0, 2.0, 0.01) var hair_response_scale: float = 0.42
@export_range(0.1, 20.0, 0.1) var smoothing: float = 7.5
@export_range(0.0, 18.0, 0.1) var maximum_visual_wind_speed: float = 6.0

var actor: CharacterBody3D = null
var visual: StylizedActorVisual = null
var sash_tail: Node3D = null
var left_hair_lock: Node3D = null
var right_hair_lock: Node3D = null
var motion_director: EnvironmentalMotionDirector3D = null
var smoothed_wind: Vector3 = Vector3.ZERO
var last_wind: Vector3 = Vector3.ZERO
var applied_frames: int = 0


func _ready() -> void:
	process_priority = 50
	add_to_group("debuggable")
	actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	visual = actor.get_node_or_null("GraceVisualV1") as StylizedActorVisual
	if visual != null:
		sash_tail = visual.get_node_or_null("VisualRoot/SashTailPivot") as Node3D
		left_hair_lock = visual.get_node_or_null("VisualRoot/LeftHairLockPivot") as Node3D
		right_hair_lock = visual.get_node_or_null("VisualRoot/RightHairLockPivot") as Node3D
	_resolve_motion_director()


func _process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if motion_director == null or not is_instance_valid(motion_director):
		_resolve_motion_director()
	var target_wind: Vector3 = _sample_environment_wind()
	var alpha: float = 1.0 - exp(-maxf(delta, 0.0) * smoothing)
	smoothed_wind = smoothed_wind.lerp(target_wind, clampf(alpha, 0.0, 1.0))
	last_wind = target_wind
	_apply_accessory_offset(smoothed_wind)


func _resolve_motion_director() -> void:
	motion_director = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("environmental_motion_director")
	if candidate is EnvironmentalMotionDirector3D:
		motion_director = candidate as EnvironmentalMotionDirector3D


func _sample_environment_wind() -> Vector3:
	if motion_director == null or not is_instance_valid(motion_director):
		return Vector3.ZERO
	if not motion_director.enabled or motion_director.profile == null:
		return Vector3.ZERO
	var wind: Vector3 = motion_director.sample_visual_wind_at(actor.global_position, 0.37)
	var manager: Node = motion_director.airflow_manager
	if manager != null and is_instance_valid(manager) and manager.has_method("sample_total_airflow_fast"):
		var value: Variant = manager.call("sample_total_airflow_fast", actor.global_position, motion_director.elapsed)
		if value is Vector3:
			wind += (
				value as Vector3
			) * motion_director.profile.systemic_airflow_scale
	var limit: float = minf(
		maxf(maximum_visual_wind_speed, 0.0),
		maxf(motion_director.profile.maximum_visual_wind_speed, 0.0)
	)
	if limit > 0.001 and wind.length_squared() > limit * limit:
		wind = wind.normalized() * limit
	return wind


func _apply_accessory_offset(world_wind: Vector3) -> void:
	if actor == null or world_wind.length_squared() <= 0.000001:
		return
	var local_wind: Vector3 = actor.global_transform.basis.inverse() * world_wind
	var reference_speed: float = 1.5
	if motion_director != null and motion_director.profile != null:
		reference_speed = maxf(motion_director.profile.reference_wind_speed, 0.1)
	var strength: float = clampf(world_wind.length() / reference_speed, 0.0, 2.2)
	var forward_bend: float = clampf(-local_wind.z / reference_speed, -1.5, 1.5)
	var side_bend: float = clampf(local_wind.x / reference_speed, -1.5, 1.5)

	if sash_tail != null:
		sash_tail.rotation.x += forward_bend * 0.055 * sash_response_scale * strength
		sash_tail.rotation.z += side_bend * 0.075 * sash_response_scale * strength
	if left_hair_lock != null:
		left_hair_lock.rotation.x += forward_bend * 0.030 * hair_response_scale * strength
		left_hair_lock.rotation.z += side_bend * 0.042 * hair_response_scale * strength
	if right_hair_lock != null:
		right_hair_lock.rotation.x += forward_bend * 0.030 * hair_response_scale * strength
		right_hair_lock.rotation.z += side_bend * 0.042 * hair_response_scale * strength
	applied_frames += 1


func sample_environment_wind_for_test() -> Vector3:
	return _sample_environment_wind()


func get_debug_data() -> Dictionary:
	return {
		"player_accessory_wind_response": true,
		"director": motion_director.name if motion_director != null and is_instance_valid(motion_director) else "",
		"last_wind": last_wind,
		"smoothed_wind": smoothed_wind,
		"applied_frames": applied_frames,
		"sash": sash_tail != null,
		"hair_locks": left_hair_lock != null and right_hair_lock != null,
		"additive_only": true,
	}
