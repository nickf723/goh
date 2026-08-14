extends "res://scripts/weapons/chain_head_motion_v3.gd"
class_name ChainHeadMotionV4


func _ready() -> void:
	trail_sample_count = 16
	super._ready()


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or controller == null:
		return
	if attack.extra_tags.has("weapon_charge_hold"):
		return
	var is_slam: bool = attack.extra_tags.has("ground_slam") or attack.extra_tags.has("slam")
	if is_slam:
		_update_smoother_slam(attack, elapsed, attack_speed)
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
	var launcher: bool = attack.extra_tags.has("launcher")
	var start_angle: float = (-118.0 if heavy else -102.0) * side
	var contact_angle: float = (18.0 if heavy else 10.0) * side
	var end_angle: float = (136.0 if heavy else 112.0) * side
	var lift: float = 0.62 if launcher else (0.38 if heavy else 0.29)
	var loaded_point: Vector3 = _arc_point(
		handle,
		forward,
		right,
		reach,
		start_angle,
		lift * 0.72
	)

	if elapsed < startup:
		var raw_p: float = clampf(elapsed / startup, 0.0, 1.0)
		if raw_p < 0.4:
			var gather: float = smoothstep(0.0, 1.0, raw_p / 0.4)
			var control: Vector3 = handle
			control += right * side * reach * 0.22
			control += Vector3.UP * 0.22
			_visual_tip = _quadratic_bezier(
				attack_start_tip,
				control,
				loaded_point,
				gather
			)
		else:
			var sweep_p: float = smoothstep(0.0, 1.0, (raw_p - 0.4) / 0.6)
			var angle: float = lerpf(start_angle, contact_angle, sweep_p)
			_visual_tip = _arc_point(
				handle,
				forward,
				right,
				reach,
				angle,
				lift + sin(sweep_p * PI) * (0.13 if heavy else 0.09)
			)
	elif elapsed <= active_end:
		var strike_p: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - startup) / active, 0.0, 1.0)
		)
		var angle: float = lerpf(contact_angle, end_angle, strike_p)
		_visual_tip = _arc_point(
			handle,
			forward,
			right,
			reach,
			angle,
			lift + sin(strike_p * PI) * (0.14 if heavy else 0.08)
		)
	else:
		var recovery: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0)
		)
		var end_point: Vector3 = _arc_point(
			handle,
			forward,
			right,
			reach,
			end_angle,
			lift
		)
		_visual_tip = end_point.lerp(_head_idle_position(), recovery)

	_desired_tip = _visual_tip
	_record_tip_history()
	_update_trailing_line()
	_update_tip_visual()


func _update_smoother_slam(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
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
	var loaded: Vector3 = handle - forward * reach * 0.32
	loaded += right * side * reach * 0.32
	loaded += Vector3.UP * 0.18
	var overhead: Vector3 = handle + forward * reach * 0.46
	overhead += right * side * reach * 0.08
	overhead += Vector3.UP * 1.52
	var landing: Vector3 = _ground_project(handle + forward * reach * 0.72)

	if elapsed < startup:
		var raw_p: float = clampf(elapsed / startup, 0.0, 1.0)
		if raw_p < 0.38:
			var gather: float = smoothstep(0.0, 1.0, raw_p / 0.38)
			var control: Vector3 = handle + right * side * reach * 0.2 + Vector3.UP * 0.34
			_visual_tip = _quadratic_bezier(
				attack_start_tip,
				control,
				loaded,
				gather
			)
		else:
			var lift_p: float = smoothstep(0.0, 1.0, (raw_p - 0.38) / 0.62)
			_visual_tip = loaded.lerp(overhead, lift_p)
	elif elapsed <= active_end:
		var drop_p: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - startup) / active, 0.0, 1.0)
		)
		_visual_tip = overhead.lerp(landing, drop_p)
	else:
		var recovery: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0)
		)
		_visual_tip = landing.lerp(_head_idle_position(), recovery)

	_desired_tip = _visual_tip
	_record_tip_history()
	_update_trailing_line()
	_update_tip_visual()


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
	_update_trailing_line()
	_update_tip_speed(maxf(delta, 0.0001))
	_update_tip_visual()


func _update_trailing_line() -> void:
	if line == null or handle_anchor == null:
		return
	var handle: Vector3 = handle_anchor.global_position
	var points: Array[Vector3] = []
	var dynamic_sag: float = 0.14 if _is_charge_orbit_active() else (0.24 if is_attacking else 0.5)
	var trail_direction: Vector3 = Vector3.ZERO
	if _tip_velocity.length_squared() > 0.0001:
		trail_direction = -_tip_velocity.normalized()
	var trail_amount: float = 0.0
	if _is_charge_orbit_active():
		trail_amount = 0.28
	elif is_attacking:
		trail_amount = 0.18
	for index: int in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var arc_weight: float = sin(t * PI)
		var point: Vector3 = handle.lerp(_visual_tip, t)
		point += Vector3.DOWN * arc_weight * dynamic_sag
		point += trail_direction * arc_weight * trail_amount * t
		points.append(point)
	line.set_points(points)


func _quadratic_bezier(
	point_a: Vector3,
	control: Vector3,
	point_b: Vector3,
	t: float
) -> Vector3:
	var clamped: float = clampf(t, 0.0, 1.0)
	var inverse: float = 1.0 - clamped
	return point_a * inverse * inverse + control * 2.0 * inverse * clamped + point_b * clamped * clamped


func get_head_world_position() -> Vector3:
	return _visual_tip


func get_handle_world_position() -> Vector3:
	return handle_anchor.global_position if handle_anchor != null else global_position


func get_head_speed_ratio() -> float:
	return clampf(current_tip_speed / maxf(head_max_speed, 0.1), 0.0, 1.0)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "weighted_head_motion_v4"
	data["bezier_gather"] = true
	data["trailing_links"] = true
	data["trail_sample_count"] = trail_sample_count
	return data
