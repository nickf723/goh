extends "res://scripts/visuals/grace_0_5_blockout_model_v6.gd"
class_name Grace05BlockoutModelV7

# V7 adds rotational inertia to the V5/V6 secondary-motion stack. A standing
# pivot now gives hair, robe panels, and sash tails a tiny delayed sweep even when
# world-space linear acceleration is near zero.

@export_group("Rotational Secondary Motion")
@export_range(0.1, 8.0, 0.1) var full_turn_rate: float = 2.8
@export_range(0.0, 12.0, 0.5) var hair_turn_lag_degrees: float = 5.0
@export_range(0.0, 14.0, 0.5) var robe_turn_lag_degrees: float = 5.5
@export_range(0.0, 22.0, 0.5) var sash_turn_lag_degrees: float = 9.0

var secondary_previous_yaw: float = 0.0
var secondary_yaw_initialized: bool = false
var secondary_turn_rate: float = 0.0


func _update_secondary_state(delta: float) -> void:
	super._update_secondary_state(delta)
	if secondary_actor == null or delta <= 0.0001:
		return
	var forward: Vector3 = -secondary_actor.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return
	forward = forward.normalized()
	var yaw: float = atan2(forward.x, forward.z)
	if not secondary_yaw_initialized:
		secondary_previous_yaw = yaw
		secondary_yaw_initialized = true
		return
	var yaw_delta: float = wrapf(yaw - secondary_previous_yaw, -PI, PI)
	secondary_previous_yaw = yaw
	var raw_rate: float = yaw_delta / delta
	var blend: float = 1.0 - exp(-maxf(secondary_response, 0.01) * delta)
	secondary_turn_rate = lerpf(secondary_turn_rate, raw_rate, blend)


func _apply_secondary_motion() -> void:
	super._apply_secondary_motion()
	var turn: float = clampf(
		secondary_turn_rate / maxf(full_turn_rate, 0.1),
		-1.0,
		1.0
	)
	if absf(turn) <= 0.01:
		return

	# Secondary pieces lag opposite the turn direction. The signs intentionally do
	# not match skeletal turn anticipation: bones lead, loose material trails.
	_add_part_rotation(
		"HairBack",
		Vector3(0.0, deg_to_rad(-turn * hair_turn_lag_degrees * 0.45), deg_to_rad(-turn * hair_turn_lag_degrees))
	)
	_add_part_rotation(
		"HairLockLeft",
		Vector3(0.0, deg_to_rad(-turn * hair_turn_lag_degrees * 0.75), deg_to_rad(-turn * hair_turn_lag_degrees * 1.15))
	)
	_add_part_rotation(
		"HairLockRight",
		Vector3(0.0, deg_to_rad(-turn * hair_turn_lag_degrees * 0.7), deg_to_rad(-turn * hair_turn_lag_degrees * 1.08))
	)
	for part_name: String in [
		"FrontPanelLeft",
		"FrontPanelRight",
		"SidePanelLeft",
		"SidePanelRight",
		"BackRobePanel",
	]:
		_add_part_rotation(
			part_name,
			Vector3(0.0, deg_to_rad(-turn * robe_turn_lag_degrees * 0.42), deg_to_rad(-turn * robe_turn_lag_degrees * 0.55))
		)
	_add_part_rotation(
		"SashTailLeft",
		Vector3(0.0, deg_to_rad(-turn * sash_turn_lag_degrees * 0.8), deg_to_rad(-turn * sash_turn_lag_degrees))
	)
	_add_part_rotation(
		"SashTailRight",
		Vector3(0.0, deg_to_rad(-turn * sash_turn_lag_degrees * 0.74), deg_to_rad(-turn * sash_turn_lag_degrees * 0.92))
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["grace_0_5_secondary_turn_v7"] = true
	data["secondary_turn_rate"] = snappedf(secondary_turn_rate, 0.01)
	return data
