extends "res://scripts/weapons/chain_head_rig_clean.gd"
class_name ChainHeadMotionV2

var attack_start_tip: Vector3 = Vector3.ZERO
var charge_orbit_phase_offset: float = 0.0
var charge_orbit_was_active: bool = false


func _physics_process(delta: float) -> void:
	if controller == null or line == null:
		return
	_update_handle()
	var charging: bool = _is_charge_orbit_active()
	if charging:
		if not charge_orbit_was_active:
			_sync_charge_orbit_phase()
		_visual_tip = _sample_charge_orbit_head_v2()
		_desired_tip = _visual_tip
	elif not is_attacking:
		_visual_tip = _head_idle_position()
		_desired_tip = _visual_tip
	charge_orbit_was_active = charging
	_record_tip_history()
	_update_head_driven_line_v2()
	_update_tip_speed(maxf(delta, 0.0001))
	_update_tip_visual()


func begin_attack(attack: WeaponAttackDefinition, attack_speed: float) -> void:
	super.begin_attack(attack, attack_speed)
	attack_start_tip = _visual_tip


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or controller == null:
		return
	if attack.extra_tags.has("weapon_charge_hold"):
		return
	_update_handle()
	var startup: float = maxf(attack.get_startup_duration(attack_speed), 0.01)
	var active: float = maxf(attack.get_active_duration(attack_speed), 0.01)
	var active_end: float = startup + active
	var total: float = maxf(attack.get_total_duration(attack_speed), active_end + 0.01)
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var side: float = -1.0 if attack.extra_tags.has("reverse") else 1.0
	var reach: float = minf(chain_length, maxf(attack.attack_range, 1.0))
	var heavy: bool = attack.input_kind == "heavy"
	var is_slam: bool = attack.extra_tags.has("ground_slam") or attack.extra_tags.has("slam")

	if is_slam:
		_update_slam_head(attack_start_tip, handle, forward, right, side, reach, elapsed, startup, active_end, total)
	else:
		var start_angle: float = (-126.0 if heavy else -108.0) * side
		var end_angle: float = (142.0 if heavy else 116.0) * side
		var lift: float = 0.58 if attack.extra_tags.has("launcher") else (0.34 if heavy else 0.27)
		if elapsed < startup:
			var p: float = smoothstep(0.0, 1.0, clampf(elapsed / startup, 0.0, 1.0))
			var windup_point: Vector3 = _arc_point(handle, forward, right, reach, start_angle, lift * 0.72)
			_visual_tip = attack_start_tip.lerp(windup_point, p)
		elif elapsed <= active_end:
			var p: float = smoothstep(0.0, 1.0, clampf((elapsed - startup) / active, 0.0, 1.0))
			var angle: float = lerpf(start_angle, end_angle, p)
			var arc_lift: float = lift + sin(p * PI) * (0.16 if heavy else 0.1)
			_visual_tip = _arc_point(handle, forward, right, reach, angle, arc_lift)
		else:
			var recovery: float = smoothstep(0.0, 1.0, clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0))
			var end_point: Vector3 = _arc_point(handle, forward, right, reach, end_angle, lift)
			_visual_tip = end_point.lerp(_head_idle_position(), recovery)
	_desired_tip = _visual_tip
	_record_tip_history()
	_update_head_driven_line_v2()
	_update_tip_visual()


func _update_slam_head(
	start_tip: Vector3,
	handle: Vector3,
	forward: Vector3,
	right: Vector3,
	side: float,
	reach: float,
	elapsed: float,
	startup: float,
	active_end: float,
	total: float
) -> void:
	var active: float = maxf(active_end - startup, 0.01)
	var loaded: Vector3 = handle - forward * reach * 0.3 + right * side * reach * 0.34 + Vector3.UP * 0.2
	var overhead: Vector3 = handle + forward * reach * 0.5 + right * side * reach * 0.08 + Vector3.UP * 1.55
	var landing: Vector3 = _ground_project(handle + forward * reach * 0.72)
	if elapsed < startup:
		var p: float = smoothstep(0.0, 1.0, clampf(elapsed / startup, 0.0, 1.0))
		if p < 0.42:
			_visual_tip = start_tip.lerp(loaded, smoothstep(0.0, 1.0, p / 0.42))
		else:
			_visual_tip = loaded.lerp(overhead, smoothstep(0.0, 1.0, (p - 0.42) / 0.58))
	elif elapsed <= active_end:
		var p: float = smoothstep(0.0, 1.0, clampf((elapsed - startup) / active, 0.0, 1.0))
		_visual_tip = overhead.lerp(landing, p)
	else:
		var recovery: float = smoothstep(0.0, 1.0, clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0))
		_visual_tip = landing.lerp(_head_idle_position(), recovery)


func _sync_charge_orbit_phase() -> void:
	var actor: Node3D = controller.get_actor()
	if actor == null:
		charge_orbit_phase_offset = 0.0
		return
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var center: Vector3 = actor.global_position + Vector3.UP * 0.52
	var offset: Vector3 = _visual_tip - center
	offset.y = 0.0
	var current_angle: float = atan2(offset.dot(right), offset.dot(forward)) if offset.length_squared() > 0.0001 else 0.0
	var charge: float = _get_charge_ratio()
	var speed: float = lerpf(1.75, 2.5, charge)
	charge_orbit_phase_offset = current_angle - _get_charge_elapsed() * speed


func _sample_charge_orbit_head_v2() -> Vector3:
	var actor: Node3D = controller.get_actor()
	if actor == null:
		return _head_idle_position()
	var charge: float = _get_charge_ratio()
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var radius: float = lerpf(3.1, 3.9, charge)
	var angular_speed: float = lerpf(1.75, 2.5, charge)
	var angle: float = _get_charge_elapsed() * angular_speed + charge_orbit_phase_offset
	var center: Vector3 = actor.global_position + Vector3.UP * lerpf(0.48, 0.58, charge)
	return center + forward * cos(angle) * radius + right * sin(angle) * radius + Vector3.UP * sin(angle * 2.0) * 0.14


func _update_head_driven_line_v2() -> void:
	if line == null or handle_anchor == null:
		return
	var handle: Vector3 = handle_anchor.global_position
	var points: Array[Vector3] = []
	var dynamic_sag: float = 0.16 if _is_charge_orbit_active() else (0.26 if is_attacking else 0.5)
	for index: int in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var point: Vector3 = handle.lerp(_visual_tip, t)
		point += Vector3.DOWN * sin(t * PI) * dynamic_sag
		points.append(point)
	line.set_points(points)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "weighted_head_motion_v2"
	data["charge_orbit_phase_synced"] = true
	data["authored_head_arc"] = true
	return data
