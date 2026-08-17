extends "res://scripts/visuals/grace_0_5_blockout_model_v5.gd"
class_name Grace05BlockoutModelV6

# A tiny facial-life pass. The model is still a rigid production proxy, but an
# irregular blink cadence removes a surprising amount of mannequin energy at
# gameplay distance without introducing a facial rig dependency.

@export_group("Facial Micro Motion")
@export_range(1.0, 8.0, 0.1) var minimum_blink_interval: float = 2.6
@export_range(1.0, 10.0, 0.1) var maximum_blink_interval: float = 5.6
@export_range(0.05, 0.3, 0.01) var blink_duration: float = 0.12
@export_range(0.02, 0.3, 0.01) var closed_eye_scale: float = 0.08

var blink_rng := RandomNumberGenerator.new()
var blink_wait_remaining: float = 0.0
var blink_elapsed: float = -1.0
var blink_count: int = 0
var current_blink_scale: float = 1.0


func _enter_tree() -> void:
	blink_rng.randomize()
	blink_wait_remaining = _next_blink_interval()
	super._enter_tree()
	set_meta("grace_0_5_blink_v6", true)


func _process(delta: float) -> void:
	super._process(delta)
	_update_blink(maxf(delta, 0.0))
	_apply_blink_pose()


func _update_blink(delta: float) -> void:
	if blink_elapsed >= 0.0:
		blink_elapsed += delta
		var duration: float = maxf(blink_duration, 0.05)
		var p: float = clampf(blink_elapsed / duration, 0.0, 1.0)
		var closure: float = (
			smoothstep(0.0, 1.0, p / 0.42)
			if p < 0.42
			else 1.0 - smoothstep(0.42, 1.0, p)
		)
		current_blink_scale = lerpf(1.0, closed_eye_scale, closure)
		if p >= 1.0:
			blink_elapsed = -1.0
			current_blink_scale = 1.0
			blink_count += 1
			blink_wait_remaining = _next_blink_interval()
		return

	blink_wait_remaining -= delta
	if blink_wait_remaining <= 0.0:
		blink_elapsed = 0.0


func _apply_blink_pose() -> void:
	for part_name: String in [
		"EyeWhiteLeft",
		"EyeWhiteRight",
		"EyeLeft",
		"EyeRight",
		"EyeGlintLeft",
		"EyeGlintRight",
	]:
		var part: MeshInstance3D = get_node_or_null(part_name) as MeshInstance3D
		if part == null:
			continue
		part.scale.y *= current_blink_scale


func _next_blink_interval() -> float:
	var low: float = minf(minimum_blink_interval, maximum_blink_interval)
	var high: float = maxf(minimum_blink_interval, maximum_blink_interval)
	return blink_rng.randf_range(maxf(low, 0.2), maxf(high, low + 0.1))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["grace_0_5_blink_v6"] = true
	data["blink_count"] = blink_count
	data["blink_active"] = blink_elapsed >= 0.0
	data["blink_scale"] = snappedf(current_blink_scale, 0.01)
	data["next_blink"] = snappedf(maxf(blink_wait_remaining, 0.0), 0.01)
	return data
