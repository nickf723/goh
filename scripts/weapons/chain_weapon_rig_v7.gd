extends "res://scripts/weapons/chain_weapon_rig_v5.gd"
class_name ChainWeaponRigV7

# The weighted head is the weapon state. The chain is only the visual tether
# from Grace's hand to that authored head path.

@export_range(0.2, 1.2, 0.05) var head_contact_radius: float = 0.62
@export_range(3, 12, 1) var trail_sample_count: int = 7

var tip_history: Array[Vector3] = []


func _ready() -> void:
	chain_length = 4.0
	tip_mass = 3.3
	contact_radius = head_contact_radius
	line_sag = 0.42
	super._ready()


func _physics_process(delta: float) -> void:
	if controller == null or line == null:
		return
	_update_handle()
	if _is_charge_orbit_active():
		_visual_tip = _sample_charge_orbit_head()
		_desired_tip = _visual_tip
	elif not is_attacking:
		_visual_tip = _head_idle_position()
		_desired_tip = _visual_tip
	_record_tip_history()
	_update_head_driven_line()
	_update_tip_speed(maxf(delta, 0.0001))
	_update_tip_visual()


func begin_attack(attack: WeaponAttackDefinition, _attack_speed: float) -> void:
	if attack == null:
		return
	is_attacking = true
	active_attack_id = attack.attack_id
	peak_tip_speed = 0.0
	_contact_strengths.clear()
	tip_history.clear()
	_record_tip_history()


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
	var is_slam: bool = attack.extra_tags.has("ground_slam") or attack.extra_tags.has("slam")

	if elapsed < startup:
		var p: float = smoothstep(0.0, 1.0, clampf(elapsed / startup, 0.0, 1.0))
		if is_slam:
			var behind: Vector3 = handle - forward * reach * 0.4 + right * side * reach * 0.28
			var above_front: Vector3 = handle + forward * reach * 0.62 + Vector3.UP * 1.45
			_visual_tip = behind.lerp(above_front, p)
		else:
			var angle: float = lerpf(-145.0 * side, -18.0 * side, p)
			_visual_tip = _arc_point(handle, forward, right, reach, angle, 0.18 + 0.18 * sin(p * PI))
	elif elapsed <= active_end:
		var p: float = clampf((elapsed - startup) / active, 0.0, 1.0)
		if is_slam:
			var landing: Vector3 = handle + forward * reach * 0.72
			_visual_tip = _ground_project(landing)
		else:
			var angle: float = lerpf(-18.0 * side, 86.0 * side, smoothstep(0.0, 1.0, p))
			_visual_tip = _arc_point(handle, forward, right, reach, angle, 0.25 + 0.12 * sin(p * PI))
	else:
		var recovery: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0)
		)
		_visual_tip = _visual_tip.lerp(_head_idle_position(), recovery)
	_desired_tip = _visual_tip
	_record_tip_history()
	_update_head_driven_line()
	_update_tip_visual()


func end_attack() -> void:
	is_attacking = false
	active_attack_id = ""
	_contact_strengths.clear()
	_visual_tip = _head_idle_position()
	_desired_tip = _visual_tip
	tip_history.clear()
	_record_tip_history()


func _head_idle_position() -> Vector3:
	if handle_anchor == null:
		return global_position
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	return _ground_project(
		handle_anchor.global_position
		- forward * 0.72
		+ right * 0.48
		+ Vector3.DOWN * 0.7
	)


func _sample_charge_orbit_head() -> Vector3:
	var actor: Node3D = controller.get_actor()
	if actor == null:
		return _head_idle_position()
	var charge: float = _get_charge_ratio()
	var seconds: float = _get_charge_elapsed()
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var radius: float = lerpf(2.35, 3.55, charge)
	var angular_speed: float = lerpf(2.15, 3.05, charge)
	var angle: float = seconds * angular_speed
	var center: Vector3 = actor.global_position + Vector3.UP * lerpf(0.38, 0.56, charge)
	return center + forward * cos(angle) * radius + right * sin(angle) * radius + Vector3.UP * sin(angle * 2.0) * 0.12


func _arc_point(
	handle: Vector3,
	forward: Vector3,
	right: Vector3,
	reach: float,
	angle_degrees: float,
	height: float
) -> Vector3:
	var radians: float = deg_to_rad(angle_degrees)
	return handle + forward * cos(radians) * reach + right * sin(radians) * reach + Vector3.UP * height


func _record_tip_history() -> void:
	if tip_history.is_empty() or tip_history[tip_history.size() - 1].distance_to(_visual_tip) > 0.08:
		tip_history.append(_visual_tip)
	while tip_history.size() > maxi(trail_sample_count, 3):
		tip_history.remove_at(0)


func _update_head_driven_line() -> void:
	if line == null or handle_anchor == null:
		return
	var handle: Vector3 = handle_anchor.global_position
	var points: Array[Vector3] = []
	var dynamic_sag: float = 0.22 if _is_charge_orbit_active() else (0.32 if is_attacking else 0.52)
	for index: int in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var point: Vector3 = handle.lerp(_visual_tip, t)
		point += Vector3.DOWN * sin(t * PI) * dynamic_sag
		points.append(point)
	line.set_points(points)


func _is_charge_orbit_active() -> bool:
	return controller != null and controller.has_method("is_chain_orbit_charging") and bool(controller.call("is_chain_orbit_charging"))


func _get_charge_ratio() -> float:
	if controller != null and controller.has_method("get_weapon_charge_ratio"):
		return clampf(float(controller.call("get_weapon_charge_ratio")), 0.0, 1.0)
	return 0.0


func _get_charge_elapsed() -> float:
	if controller != null and controller.has_method("get_weapon_charge_elapsed"):
		return maxf(float(controller.call("get_weapon_charge_elapsed")), 0.0)
	return 0.0
