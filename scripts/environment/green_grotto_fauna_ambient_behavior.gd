extends Node
class_name GreenGrottoFaunaAmbientBehavior

@export var enabled: bool = true
@export_range(1.0, 20.0, 0.1) var curiosity_distance: float = 7.5
@export_range(0.5, 10.0, 0.1) var startled_distance: float = 3.2
@export_range(0.0, 3.0, 0.05) var startled_step_distance: float = 1.1
@export_range(0.1, 20.0, 0.1) var position_response: float = 3.8
@export_range(0.1, 20.0, 0.1) var rotation_response: float = 5.5
@export_range(0.1, 20.0, 0.1) var pose_response: float = 6.5

var fauna: GreenGrottoFaunaVisual = null
var target_actor: Node3D = null
var elapsed: float = 0.0
var resolve_timer: float = 0.0
var patrol_angle: float = 0.0
var startled_offset: Vector3 = Vector3.ZERO
var behavior_state: String = "roam"
var previous_state: String = ""
var state_changes: int = 0
var curiosity_samples: int = 0
var closest_actor_distance: float = INF


func _ready() -> void:
	process_priority = 25
	fauna = get_parent() as GreenGrottoFaunaVisual
	if fauna == null:
		set_process(false)
		return
	fauna.animate_creature = false
	patrol_angle = fauna.idle_phase
	add_to_group("ambient_fauna_behavior")
	add_to_group("debuggable")
	_resolve_target_actor()


func set_enabled(value: bool) -> void:
	enabled = value
	if fauna == null or not is_instance_valid(fauna):
		return
	# The benchmark's baseline hands authority back to the exact simple animator
	# that GreenGrottoFaunaVisual shipped with before this presentation layer.
	fauna.animate_creature = not enabled
	if enabled:
		patrol_angle = fauna.idle_phase
		startled_offset = Vector3.ZERO
		previous_state = ""


func _process(delta: float) -> void:
	if not enabled or fauna == null or not is_instance_valid(fauna):
		return
	var safe_delta: float = maxf(delta, 0.0)
	elapsed += safe_delta
	resolve_timer -= safe_delta
	if resolve_timer <= 0.0:
		resolve_timer = 0.45
		_resolve_target_actor()

	behavior_state = _resolve_behavior_state()
	if behavior_state != previous_state:
		previous_state = behavior_state
		state_changes += 1
	_update_position(safe_delta)
	_update_body_orientation(safe_delta)
	_update_pose(safe_delta)


func _resolve_target_actor() -> void:
	target_actor = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group("player")
	if candidate is Node3D:
		target_actor = candidate as Node3D


func _resolve_behavior_state() -> String:
	closest_actor_distance = INF
	if target_actor != null and is_instance_valid(target_actor):
		closest_actor_distance = fauna.global_position.distance_to(
			target_actor.global_position
		)
		if fauna.species == "raptor":
			if closest_actor_distance < startled_distance:
				curiosity_samples += 1
				return "startled"
			if closest_actor_distance < curiosity_distance:
				curiosity_samples += 1
				return "curious"

	var cycle_time: float = elapsed + fauna.idle_phase * 2.7
	if fauna.species == "sauropod":
		var sauropod_cycle: float = fposmod(cycle_time, 18.0)
		if sauropod_cycle < 8.5:
			return "roam"
		if sauropod_cycle < 13.8:
			return "forage"
		return "pause"

	var raptor_cycle: float = fposmod(cycle_time, 13.5)
	if raptor_cycle < 5.2:
		return "roam"
	if raptor_cycle < 7.0:
		return "pause"
	if raptor_cycle < 10.1:
		return "forage"
	return "roam"


func _update_position(delta: float) -> void:
	var species_speed: float = 1.55 if fauna.species == "raptor" else 0.58
	var movement_weight: float = 1.0 if behavior_state == "roam" else 0.0
	if behavior_state == "startled":
		movement_weight = 0.35
	patrol_angle += (
		delta
		* fauna.patrol_speed
		* species_speed
		* movement_weight
	)

	var patrol_offset: Vector3 = Vector3.ZERO
	if fauna.patrol_radius > 0.01:
		patrol_offset = Vector3(
			cos(patrol_angle) * fauna.patrol_radius,
			0.0,
			sin(patrol_angle) * fauna.patrol_radius * 0.65
		)

	var target_startled_offset: Vector3 = Vector3.ZERO
	if (
		behavior_state == "startled"
		and target_actor != null
		and is_instance_valid(target_actor)
	):
		var away_world: Vector3 = fauna.global_position - target_actor.global_position
		away_world.y = 0.0
		if away_world.length_squared() > 0.0001:
			away_world = away_world.normalized() * startled_step_distance
			var parent_3d: Node3D = fauna.get_parent() as Node3D
			if parent_3d != null:
				var away_target_local: Vector3 = parent_3d.to_local(
					fauna.global_position + away_world
				)
				target_startled_offset = (
					away_target_local
					- fauna.home_position
					- patrol_offset
				)
	var offset_alpha: float = 1.0 - exp(-delta * position_response * 1.4)
	startled_offset = startled_offset.lerp(
		target_startled_offset,
		clampf(offset_alpha, 0.0, 1.0)
	)

	var target_position: Vector3 = fauna.home_position + patrol_offset + startled_offset
	var position_alpha: float = 1.0 - exp(-delta * position_response)
	fauna.position = fauna.position.lerp(
		target_position,
		clampf(position_alpha, 0.0, 1.0)
	)


func _update_body_orientation(delta: float) -> void:
	var desired_yaw: float = fauna.rotation.y
	if (
		behavior_state in ["curious", "startled"]
		and target_actor != null
		and is_instance_valid(target_actor)
	):
		var direction: Vector3 = target_actor.global_position - fauna.global_position
		direction.y = 0.0
		if behavior_state == "startled":
			direction = -direction
		if direction.length_squared() > 0.0001:
			var local_direction: Vector3 = direction
			var parent_3d: Node3D = fauna.get_parent() as Node3D
			if parent_3d != null:
				local_direction = parent_3d.global_basis.inverse() * direction
			desired_yaw = atan2(local_direction.x, local_direction.z)
	elif behavior_state == "roam" and fauna.patrol_radius > 0.01:
		var tangent := Vector3(
			-sin(patrol_angle),
			0.0,
			cos(patrol_angle) * 0.65
		)
		if tangent.length_squared() > 0.0001:
			desired_yaw = atan2(tangent.x, tangent.z)
	elif behavior_state == "pause":
		desired_yaw += sin(elapsed * 0.34 + fauna.idle_phase) * 0.002

	var rotation_alpha: float = 1.0 - exp(-delta * rotation_response)
	fauna.rotation.y = lerp_angle(
		fauna.rotation.y,
		desired_yaw,
		clampf(rotation_alpha, 0.0, 1.0)
	)


func _update_pose(delta: float) -> void:
	if fauna.visual_root == null:
		return
	var time_scale: float = 1.6 if fauna.species == "raptor" else 0.65
	var time_value: float = elapsed * time_scale + fauna.idle_phase
	var bob_scale: float = 1.0
	var root_pitch: float = 0.0
	var head_pitch: float = 0.0
	var head_yaw: float = 0.0
	var head_roll: float = 0.0
	var tail_amplitude: float = 0.08 if fauna.species == "raptor" else 0.035

	match behavior_state:
		"pause":
			bob_scale = 0.25
			head_yaw = sin(elapsed * 0.72 + fauna.idle_phase) * (
				0.24 if fauna.species == "raptor" else 0.07
			)
			head_roll = sin(elapsed * 0.43) * 0.035
		"forage":
			bob_scale = 0.40
			root_pitch = 0.08 if fauna.species == "raptor" else 0.025
			head_pitch = 0.30 if fauna.species == "raptor" else 0.09
			head_yaw = sin(elapsed * 0.55 + fauna.idle_phase) * 0.08
			tail_amplitude *= 0.55
		"curious":
			bob_scale = 0.18
			root_pitch = -0.025
			head_pitch = -0.05
			head_yaw = sin(elapsed * 0.9 + fauna.idle_phase) * 0.12
			tail_amplitude *= 0.35
		"startled":
			bob_scale = 1.30
			root_pitch = -0.08
			head_pitch = -0.12
			head_yaw = sin(elapsed * 2.4 + fauna.idle_phase) * 0.10
			tail_amplitude *= 1.8
		_:
			head_roll = sin(time_value * 0.73) * (
				0.055 if fauna.species == "raptor" else 0.025
			)
			head_yaw = sin(time_value * 0.41) * (
				0.11 if fauna.species == "raptor" else 0.04
			)

	var bob_height: float = (
		0.018 if fauna.species == "raptor" else 0.028
	) * fauna.creature_scale * bob_scale
	var pose_alpha: float = 1.0 - exp(-delta * pose_response)
	var target_root_position := Vector3(0.0, sin(time_value) * bob_height, 0.0)
	fauna.visual_root.position = fauna.visual_root.position.lerp(
		target_root_position,
		clampf(pose_alpha, 0.0, 1.0)
	)
	fauna.visual_root.rotation.x = lerp_angle(
		fauna.visual_root.rotation.x,
		root_pitch,
		clampf(pose_alpha, 0.0, 1.0)
	)
	if fauna.head_root != null:
		var target_head := Vector3(head_pitch, head_yaw, head_roll)
		fauna.head_root.rotation = fauna.head_root.rotation.lerp(
			target_head,
			clampf(pose_alpha, 0.0, 1.0)
		)
	if fauna.tail_root != null:
		var target_tail_y: float = sin(time_value * 0.84) * tail_amplitude
		fauna.tail_root.rotation.y = lerp_angle(
			fauna.tail_root.rotation.y,
			target_tail_y,
			clampf(pose_alpha, 0.0, 1.0)
		)


func get_debug_data() -> Dictionary:
	return {
		"green_grotto_fauna_ambient_behavior": true,
		"species": fauna.species if fauna != null else "",
		"state": behavior_state,
		"enabled": enabled,
		"legacy_animator_active": fauna.animate_creature if fauna != null else false,
		"state_changes": state_changes,
		"curiosity_samples": curiosity_samples,
		"actor_distance": closest_actor_distance,
		"presentation_only": true,
		"uses_navigation": false,
		"combat_authority": false,
	}
