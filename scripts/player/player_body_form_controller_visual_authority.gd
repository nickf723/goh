extends "res://scripts/player/player_body_form_controller.gd"
class_name PlayerBodyFormControllerVisualAuthority

# Grace's articulated presentation rig samples after most gameplay controllers.
# Body form scale is gameplay state, not an animation pose, so this authority runs
# after the visual rig and reapplies the transformed root scale every frame.
# This prevents locomotion/avatar presentation from snapping the model back to
# normal while the real collision capsule remains grown or shrunk.

var visual_authority_frames: int = 0
var visual_reassertions: int = 0


func _ready() -> void:
	process_priority = 80
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	_enforce_body_form_visual_authority()


func _enforce_body_form_visual_authority() -> void:
	if not baseline_ready:
		return
	visual_authority_frames += 1
	var target_scale: float = _get_form_scale(current_form)
	var expected_visual_scale: Vector3 = base_visual_scale * target_scale
	var expected_weapon_scale: Vector3 = base_weapon_scale * target_scale
	var expected_visual_position: Vector3 = base_visual_position
	expected_visual_position.y = (
		-current_collision_height * 0.5 + base_visual_ground_offset
	)

	if grace_visual != null:
		if not grace_visual.scale.is_equal_approx(expected_visual_scale):
			visual_reassertions += 1
		grace_visual.scale = expected_visual_scale
		grace_visual.position = expected_visual_position
	if weapon_controller != null:
		weapon_controller.scale = expected_weapon_scale


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["visual_authority"] = true
	data["visual_authority_priority"] = process_priority
	data["visual_authority_frames"] = visual_authority_frames
	data["visual_reassertions"] = visual_reassertions
	data["visual_scale"] = grace_visual.scale if grace_visual != null else Vector3.ZERO
	data["expected_visual_scale"] = (
		base_visual_scale * _get_form_scale(current_form)
	)
	return data
