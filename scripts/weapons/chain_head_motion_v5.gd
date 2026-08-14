extends "res://scripts/weapons/chain_head_motion_v4.gd"
class_name ChainHeadMotionV5

# Runtime rigs are reset before every attack visual begins. A rigid weapon does
# not care, but snapping a weighted Chain head back to idle between combo beats
# destroys the motion the next swing should inherit. Preserve the head position
# across that reset and only ease home when no follow-up arrives.

var returning_to_idle: bool = false


func begin_attack(
	attack: WeaponAttackDefinition,
	attack_speed: float
) -> void:
	super.begin_attack(attack, attack_speed)
	returning_to_idle = false
	attack_start_tip = _visual_tip


func end_attack() -> void:
	is_attacking = false
	active_attack_id = ""
	_contact_strengths.clear()
	_desired_tip = _visual_tip
	returning_to_idle = true
	# Keep recent samples until the next attack begins. A buffered follow-up is
	# started in the same frame and can therefore inherit the real end position.


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
		returning_to_idle = false
	elif not is_attacking:
		var idle: Vector3 = _head_idle_position()
		var return_weight: float = clampf(maxf(delta, 0.0) * 5.8, 0.0, 1.0)
		_visual_tip = _visual_tip.lerp(idle, return_weight)
		_desired_tip = _visual_tip
		if _visual_tip.distance_to(idle) <= 0.035:
			_visual_tip = idle
			_desired_tip = idle
			returning_to_idle = false
	charge_orbit_was_active = charging
	_record_tip_history()
	_update_trailing_line()
	_update_tip_speed(maxf(delta, 0.0001))
	_update_tip_visual()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "weighted_head_motion_v5"
	data["combo_head_continuity"] = true
	data["returning_to_idle"] = returning_to_idle
	return data
