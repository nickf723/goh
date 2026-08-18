extends "res://scripts/visuals/grace_humanoid_skeletal_proxy_animation_v27.gd"
class_name GraceHumanoidSkeletalProxyAnimationV28

# V28 gives defeat a stable presentation pose. Health/death/respawn remain owned
# elsewhere; this layer simply prevents the animation resolver from falling back
# to an upright idle after Grace has been defeated.

@export_group("Defeat Animation")
@export_range(0.2, 1.5, 0.05) var defeat_collapse_seconds: float = 0.62
@export_range(0.0, 1.0, 0.05) var defeat_twist_strength: float = 0.82

var defeat_started_at: float = -100.0
var defeat_side: float = 1.0
var defeat_was_active: bool = false
var defeat_count: int = 0


func _process(delta: float) -> void:
	_update_defeat_state()
	super._process(delta)


func _resolve_state() -> String:
	if action_state != null and action_state.is_defeated:
		# Route through idle dispatch so the existing V16 sample loop does not need
		# another duplicated state table. _pose_idle below replaces the idle target.
		return "idle"
	return super._resolve_state()


func _pose_idle(targets: Dictionary) -> Vector3:
	if action_state != null and action_state.is_defeated:
		return _pose_defeated(targets)
	return super._pose_idle(targets)


func _update_defeat_state() -> void:
	var active: bool = action_state != null and action_state.is_defeated
	if active and not defeat_was_active:
		defeat_started_at = elapsed
		# Alternate collapse side across deaths so repeated debug tests are not
		# visually identical while remaining deterministic within each defeat.
		defeat_side = 1.0 if defeat_count % 2 == 0 else -1.0
		defeat_count += 1
	defeat_was_active = active


func _pose_defeated(targets: Dictionary) -> Vector3:
	var age: float = maxf(elapsed - defeat_started_at, 0.0)
	var progress: float = clampf(
		age / maxf(defeat_collapse_seconds, 0.05),
		0.0,
		1.0
	)
	var collapse: float = smoothstep(0.0, 1.0, progress)
	var settle: float = smoothstep(0.58, 1.0, progress)
	var side: float = defeat_side
	var twist: float = defeat_twist_strength

	_set_deg(targets, "pelvis", Vector3(
		lerpf(8.0, 64.0, collapse),
		side * lerpf(4.0, 22.0 * twist, collapse),
		-side * lerpf(5.0, 56.0 * twist, collapse)
	))
	_set_deg(targets, "spine_01", Vector3(
		lerpf(7.0, 34.0, collapse),
		-side * lerpf(2.0, 15.0 * twist, collapse),
		side * lerpf(3.0, 26.0 * twist, collapse)
	))
	_set_deg(targets, "spine_02", Vector3(
		lerpf(5.0, 25.0, collapse),
		-side * lerpf(3.0, 17.0 * twist, collapse),
		side * lerpf(4.0, 32.0 * twist, collapse)
	))
	_set_deg(targets, "chest", Vector3(
		lerpf(3.0, 18.0, collapse),
		-side * lerpf(4.0, 19.0 * twist, collapse),
		side * lerpf(5.0, 38.0 * twist, collapse)
	))
	_set_deg(targets, "neck", Vector3(-8.0 * collapse, side * 4.0 * collapse, -side * 8.0 * collapse))
	_set_deg(targets, "head", Vector3(-14.0 * collapse + settle * 4.0, side * 7.0 * collapse, -side * 16.0 * collapse))

	_set_deg(targets, "upper_arm_l", Vector3(38.0 * collapse, -side * 12.0 * collapse, -42.0 * collapse))
	_set_deg(targets, "upper_arm_r", Vector3(52.0 * collapse, -side * 9.0 * collapse, 29.0 * collapse))
	_set_deg(targets, "forearm_l", Vector3(-19.0 * collapse, side * 5.0 * collapse, 0.0))
	_set_deg(targets, "forearm_r", Vector3(-28.0 * collapse, -side * 5.0 * collapse, 0.0))
	_set_deg(targets, "hand_l", Vector3(5.0 * settle, 0.0, -8.0 * collapse))
	_set_deg(targets, "hand_r", Vector3(8.0 * settle, 0.0, 7.0 * collapse))

	var down_leg_left: bool = side > 0.0
	_set_deg(targets, "thigh_l", Vector3(
		(38.0 if down_leg_left else 18.0) * collapse,
		0.0,
		(-27.0 if down_leg_left else -9.0) * collapse
	))
	_set_deg(targets, "thigh_r", Vector3(
		(18.0 if down_leg_left else 38.0) * collapse,
		0.0,
		(9.0 if down_leg_left else 27.0) * collapse
	))
	_set_deg(targets, "shin_l", Vector3((57.0 if down_leg_left else 32.0) * collapse, 0.0, 0.0))
	_set_deg(targets, "shin_r", Vector3((32.0 if down_leg_left else 57.0) * collapse, 0.0, 0.0))
	_set_deg(targets, "foot_l", Vector3(-10.0 * collapse, side * 6.0 * collapse, 0.0))
	_set_deg(targets, "foot_r", Vector3(-10.0 * collapse, side * 6.0 * collapse, 0.0))
	animation_weight = collapse
	return Vector3(
		side * lerpf(0.0, 0.16, collapse),
		-lerpf(0.0, 0.52, collapse),
		lerpf(0.0, 0.05, settle)
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["animation_v28"] = true
	data["defeat_animation"] = true
	data["defeat_active"] = action_state != null and action_state.is_defeated
	data["defeat_side"] = defeat_side
	data["defeat_count"] = defeat_count
	return data
