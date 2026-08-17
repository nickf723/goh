extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v11.gd"
class_name GraceHumanoidSkeletalProxyAnimationV12

# V12 preserves the receiving foot after an evasive move. This is presentation
# continuity only: dodge distance, invulnerability, and locomotion remain owned
# by their gameplay controllers.

@export_group("Dodge Exit Continuity")
@export_range(0.05, 0.35, 0.01) var dodge_exit_memory_seconds: float = 0.18

var dodge_exit_remaining: float = 0.0
var dodge_exit_support_sign: float = 1.0
var dodge_to_run_count: int = 0
var dodge_to_idle_count: int = 0


func _ready() -> void:
	super._ready()
	if dodge_controller != null and dodge_controller.has_signal("dodge_finished"):
		var callback := Callable(self, "_on_animation_dodge_finished")
		if not dodge_controller.is_connected("dodge_finished", callback):
			dodge_controller.connect("dodge_finished", callback)


func _exit_tree() -> void:
	if dodge_controller != null:
		var callback := Callable(self, "_on_animation_dodge_finished")
		if dodge_controller.is_connected("dodge_finished", callback):
			dodge_controller.disconnect("dodge_finished", callback)
	super._exit_tree()


func _process(delta: float) -> void:
	dodge_exit_remaining = maxf(dodge_exit_remaining - maxf(delta, 0.0), 0.0)
	super._process(delta)


func _pose_locomotion(targets: Dictionary, delta: float) -> Vector3:
	var from_dodge: bool = (
		previous_pose_state == "dodge"
		and dodge_exit_remaining > 0.0
	)
	if from_dodge:
		landing_support_sign = dodge_exit_support_sign
		stride_phase = 0.0 if dodge_exit_support_sign > 0.0 else PI
		# Skip idle-to-run reseeding for this single transition frame.
		previous_pose_state = "locomotion"
		dodge_to_run_count += 1
	var pelvis_offset: Vector3 = super._pose_locomotion(targets, delta)
	if from_dodge:
		var memory: float = _get_dodge_exit_weight()
		pelvis_offset.x += dodge_exit_support_sign * support_weight_shift * 0.55 * memory
		pelvis_offset.y -= 0.016 * memory
	return pelvis_offset


func _pose_idle(targets: Dictionary) -> Vector3:
	var from_dodge: bool = (
		previous_pose_state == "dodge"
		and dodge_exit_remaining > 0.0
	)
	var pelvis_offset: Vector3 = super._pose_idle(targets)
	if not from_dodge:
		return pelvis_offset
	dodge_to_idle_count += 1
	var weight: float = _get_dodge_exit_weight()
	var left_receive: bool = dodge_exit_support_sign > 0.0
	_add_deg(targets, "pelvis", Vector3(4.0 * weight, 0.0, -dodge_exit_support_sign * 2.0 * weight))
	_add_deg(targets, "spine_01", Vector3(3.0 * weight, 0.0, dodge_exit_support_sign * 1.0 * weight))
	_add_deg(targets, "chest", Vector3(2.0 * weight, 0.0, dodge_exit_support_sign * 1.5 * weight))
	_add_deg(targets, "thigh_l", Vector3((-9.0 if left_receive else -2.0) * weight, 0.0, 0.0))
	_add_deg(targets, "thigh_r", Vector3((-9.0 if not left_receive else -2.0) * weight, 0.0, 0.0))
	_add_deg(targets, "shin_l", Vector3((15.0 if left_receive else 5.0) * weight, 0.0, 0.0))
	_add_deg(targets, "shin_r", Vector3((15.0 if not left_receive else 5.0) * weight, 0.0, 0.0))
	pelvis_offset.x += dodge_exit_support_sign * support_weight_shift * 0.7 * weight
	pelvis_offset.y -= 0.022 * weight
	return pelvis_offset


func _on_animation_dodge_finished(_reason: String) -> void:
	dodge_exit_support_sign = dodge_receiving_sign
	dodge_exit_remaining = dodge_exit_memory_seconds


func _get_dodge_exit_weight() -> float:
	if dodge_exit_remaining <= 0.0 or dodge_exit_memory_seconds <= 0.0:
		return 0.0
	var ratio: float = clampf(
		dodge_exit_remaining / maxf(dodge_exit_memory_seconds, 0.01),
		0.0,
		1.0
	)
	return smoothstep(0.0, 1.0, ratio)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v12"] = true
	data["dodge_exit_continuity"] = true
	data["dodge_exit_remaining"] = snappedf(dodge_exit_remaining, 0.001)
	data["dodge_exit_support"] = "left" if dodge_exit_support_sign > 0.0 else "right"
	data["dodge_to_run_count"] = dodge_to_run_count
	data["dodge_to_idle_count"] = dodge_to_idle_count
	return data
