extends "res://scripts/weapons/chain_head_motion_v2.gd"
class_name ChainHeadMotionV3


func _ready() -> void:
	trail_sample_count = 12
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
		super.update_attack_pose(attack, elapsed, attack_speed)
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
	var start_angle: float = (-126.0 if heavy else -108.0) * side
	var contact_angle: float = (28.0 if heavy else 20.0) * side
	var end_angle: float = (142.0 if heavy else 116.0) * side
	var lift: float = 0.58 if attack.extra_tags.has("launcher") else (0.34 if heavy else 0.27)

	if elapsed < startup:
		var raw_p: float = clampf(elapsed / startup, 0.0, 1.0)
		var windup_point: Vector3 = _arc_point(handle, forward, right, reach, start_angle, lift * 0.72)
		if raw_p < 0.34:
			var gather: float = smoothstep(0.0, 1.0, raw_p / 0.34)
			_visual_tip = attack_start_tip.lerp(windup_point, gather)
		else:
			var sweep_p: float = smoothstep(0.0, 1.0, (raw_p - 0.34) / 0.66)
			var angle: float = lerpf(start_angle, contact_angle, sweep_p)
			_visual_tip = _arc_point(
				handle,
				forward,
				right,
				reach,
				angle,
				lift + sin(sweep_p * PI) * (0.12 if heavy else 0.08)
			)
	elif elapsed <= active_end:
		var p: float = smoothstep(0.0, 1.0, clampf((elapsed - startup) / active, 0.0, 1.0))
		var angle: float = lerpf(contact_angle, end_angle, p)
		_visual_tip = _arc_point(
			handle,
			forward,
			right,
			reach,
			angle,
			lift + sin(p * PI) * (0.1 if heavy else 0.06)
		)
	else:
		var recovery: float = smoothstep(
			0.0,
			1.0,
			clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0)
		)
		var end_point: Vector3 = _arc_point(handle, forward, right, reach, end_angle, lift)
		_visual_tip = end_point.lerp(_head_idle_position(), recovery)

	_desired_tip = _visual_tip
	_record_tip_history()
	_update_head_driven_line_v2()
	_update_tip_visual()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "weighted_head_motion_v3"
	data["sweep_begins_during_startup"] = true
	data["trail_sample_count"] = trail_sample_count
	return data
