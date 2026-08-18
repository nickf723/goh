extends Node

const RigScene: PackedScene = preload(
	"res://scenes/actors/player/grace_humanoid_skeletal_proxy_v2.tscn"
)
const VerticalMotionScript: Script = preload(
	"res://scripts/player/player_vertical_motion_controller.gd"
)
const GroundMotionScript: Script = preload(
	"res://scripts/player/player_ground_motion_motor.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	await _validate_locomotion_rig()
	_finish()


func _validate_locomotion_rig() -> void:
	var actor := CharacterBody3D.new()
	actor.name = "GraceAnimationStackTestActor"
	add_child(actor)

	var ground: PlayerGroundMotionMotor = (
		GroundMotionScript.new() as PlayerGroundMotionMotor
	)
	ground.name = "GroundMotionMotor"
	actor.add_child(ground)

	var vertical: PlayerVerticalMotionController = (
		VerticalMotionScript.new() as PlayerVerticalMotionController
	)
	vertical.name = "VerticalMotionController"
	actor.add_child(vertical)

	var rig: Node3D = RigScene.instantiate() as Node3D
	_expect(rig != null, "complete Grace animation skeletal scene instantiates")
	if rig == null:
		actor.queue_free()
		return
	actor.add_child(rig)
	await get_tree().process_frame

	_expect(
		rig.has_method("get_debug_data"),
		"Grace animation rig exposes debug data"
	)
	var data: Dictionary = rig.call("get_debug_data") as Dictionary
	_expect(bool(data.get("locomotion_v2", false)), "locomotion V2 foundation is live")
	_expect(bool(data.get("locomotion_v2b", false)), "landing center-of-mass layer is live")
	_expect(bool(data.get("locomotion_v2c", false)), "foot-contact layer is live")
	_expect(bool(data.get("locomotion_v2d", false)), "support center-of-mass layer is live")
	_expect(bool(data.get("locomotion_v3", false)), "transition-continuity layer is live")
	_expect(bool(data.get("animation_v4", false)), "phase-authored dodge layer is live")
	_expect(bool(data.get("animation_v5", false)), "directional hit-reaction layer is live")
	_expect(bool(data.get("animation_v6", false)), "weapon-aware locomotion layer is live")
	_expect(bool(data.get("animation_v7", false)), "attack-exit continuity layer is live")
	_expect(bool(data.get("animation_v8", false)), "turn-intention layer is live")
	_expect(bool(data.get("animation_v9", false)), "context-action overlay layer is live")
	_expect(bool(data.get("animation_v10", false)), "directional-gait layer is live")
	_expect(bool(data.get("animation_v11", false)), "start-step and turn-in-place layer is live")
	_expect(bool(data.get("animation_v12", false)), "dodge-exit continuity layer is live")
	_expect(bool(data.get("animation_v13", false)), "attack-entry continuity layer is live")
	_expect(bool(data.get("animation_v14", false)), "regional response layer is live")
	_expect(bool(data.get("animation_v15", false)), "terrain-posture layer is live")
	_expect(bool(data.get("animation_v16", false)), "climb/swim traversal layer is live")
	_expect(bool(data.get("animation_v17", false)), "riding animation layer is live")
	_expect(bool(data.get("animation_v18", false)), "special aerial animation layer is live")
	_expect(bool(data.get("animation_v19", false)), "neutral combat gaze layer is live")
	_expect(bool(data.get("animation_v20", false)), "stealth crouch layer is live")
	_expect(bool(data.get("animation_v21", false)), "exertion presentation layer is live")
	_expect(bool(data.get("animation_v22", false)), "combo handoff layer is live")
	_expect(bool(data.get("animation_v23", false)), "airborne weapon carry layer is live")
	_expect(bool(data.get("animation_v24", false)), "dodge weapon-control layer is live")
	_expect(bool(data.get("animation_v25", false)), "step-up animation layer is live")
	_expect(bool(data.get("animation_v26", false)), "slippery-surface layer is live")
	_expect(bool(data.get("animation_v27", false)), "airflow body-response layer is live")
	_expect(bool(data.get("animation_v28", false)), "defeat presentation layer is live")
	_expect(bool(data.get("animation_v29", false)), "walk-run blend layer is live")
	_expect(bool(data.get("animation_v30", false)), "metal tether animation layer is live")
	_expect(bool(data.get("animation_v31", false)), "footage redirect-cleanup layer is live")

	# Force a left-support portion of the gait and make sure the visible pose knows
	# which leg is loaded instead of treating both feet identically.
	rig.set("previous_pose_state", "locomotion")
	rig.set("stride_phase", 0.0)
	actor.velocity = Vector3(0.6, 0.0, -5.0)
	var run_targets: Dictionary = {}
	var run_offset: Vector3 = rig.call(
		"_pose_locomotion",
		run_targets,
		1.0 / 120.0
	) as Vector3
	data = rig.call("get_debug_data") as Dictionary
	_expect(run_targets.has("pelvis"), "run pose authors pelvis motion")
	_expect(run_targets.has("thigh_l") and run_targets.has("thigh_r"), "run pose authors both legs")
	_expect(run_targets.has("foot_l") and run_targets.has("foot_r"), "run pose authors both feet")
	_expect(run_targets.has("toe_l") and run_targets.has("toe_r"), "run pose authors toe clearance and loading")
	_expect(float(data.get("left_support", 0.0)) > float(data.get("right_support", 1.0)), "gait resolves a dominant support foot")
	_expect(absf(run_offset.x) > 0.001, "support foot shifts Grace's center of mass laterally")
	_expect(run_offset.is_finite(), "run center-of-mass offset remains finite")

	# Slow analog travel must read as walking rather than a slowed run cycle.
	rig.set("previous_pose_state", "locomotion")
	actor.velocity = Vector3(0.0, 0.0, -1.2)
	var walk_targets: Dictionary = {}
	rig.call("_pose_locomotion", walk_targets, 1.0 / 60.0)
	data = rig.call("get_debug_data") as Dictionary
	_expect(float(data.get("walk_weight", 0.0)) > 0.5, "slow travel resolves the walk-scaled gait")
	_expect(walk_targets.has("thigh_l") and walk_targets.has("upper_arm_l"), "walk blend keeps full-body gait authored")

	# Backward locomotion should not be a forward run played in reverse.
	rig.set("previous_pose_state", "locomotion")
	actor.velocity = Vector3(0.0, 0.0, 4.5)
	var backward_targets: Dictionary = {}
	rig.call("_pose_locomotion", backward_targets, 1.0 / 60.0)
	data = rig.call("get_debug_data") as Dictionary
	_expect(float(data.get("backward_weight", 0.0)) > 0.4, "backward travel activates guarded backward gait")

	# A sharp turn should produce a planted pivot rather than only rotating the torso,
	# while the footage cleanup suppresses stacked sidestep/stride exaggeration.
	ground.turning_weight = 1.0
	ground.reversal_weight = 0.0
	ground.turn_angle_degrees = 92.0
	ground.requested_local_direction = Vector3(1.0, 0.0, -0.35).normalized()
	rig.set("previous_pose_state", "locomotion")
	actor.velocity = Vector3(1.4, 0.0, -4.6)
	var pivot_targets: Dictionary = {}
	var pivot_offset: Vector3 = rig.call(
		"_pose_locomotion",
		pivot_targets,
		1.0 / 60.0
	) as Vector3
	data = rig.call("get_debug_data") as Dictionary
	_expect(float(data.get("pivot_weight", 0.0)) > 0.05, "sharp turn resolves a planted pivot step")
	_expect(float(data.get("redirect_cleanup_weight", 0.0)) > 0.5, "sharp redirect activates footage-driven stride cleanup")
	_expect(float(data.get("redirect_strafe_scale", 1.0)) < 1.0, "sharp redirect suppresses overlapping strafe spread")
	_expect(pivot_targets.has("foot_l") and pivot_targets.has("foot_r"), "pivot keeps foot articulation authored")
	_expect(pivot_offset.y < 0.0, "pivot lowers Grace's center of mass")

	# Preserve the takeoff leg into the beginning of the airborne silhouette.
	ground.turning_weight = 0.0
	ground.turn_angle_degrees = 0.0
	rig.set("previous_pose_state", "locomotion")
	rig.set("stride_phase", 0.0)
	vertical.vertical_state = "rising"
	vertical.airborne_time = 0.05
	actor.velocity = Vector3(1.8, 5.0, -3.7)
	var air_targets: Dictionary = {}
	var air_offset: Vector3 = rig.call(
		"_pose_airborne",
		air_targets,
		"jump"
	) as Vector3
	data = rig.call("get_debug_data") as Dictionary
	_expect(str(data.get("takeoff_support", "")) == "left", "takeoff remembers the planted stride leg")
	_expect(air_targets.has("chest"), "airborne progression authors torso pose")
	_expect(air_targets.has("thigh_l") and air_targets.has("thigh_r"), "airborne progression preserves leg asymmetry")
	_expect(air_offset.is_finite(), "airborne center-of-mass offset remains finite")

	# Landing directly into movement must seed the next gait from the receiving leg.
	rig.set("previous_pose_state", "fall")
	vertical.vertical_state = "landing"
	vertical.last_landing_strength = 0.78
	vertical.landing_duration = 0.28
	vertical.landing_remaining = 0.18
	actor.velocity = Vector3(0.7, 0.0, -3.4)
	var landing_run_targets: Dictionary = {}
	var landing_run_offset: Vector3 = rig.call(
		"_pose_locomotion",
		landing_run_targets,
		1.0 / 60.0
	) as Vector3
	data = rig.call("get_debug_data") as Dictionary
	_expect(bool(data.get("landing_phase_seeded", false)), "landing seeds the receiving foot into the next stride")
	_expect(int(data.get("landing_to_run_count", 0)) >= 1, "landing-to-run transition is explicitly recorded")
	_expect(landing_run_offset.y < -0.02, "moving landing still absorbs impact through the center of mass")

	# Stationary hard landings retain the previous absorption contract.
	actor.velocity = Vector3.ZERO
	var landing_targets: Dictionary = {}
	var landing_offset: Vector3 = rig.call(
		"_pose_idle",
		landing_targets
	) as Vector3
	_expect(landing_targets.has("shin_l") and landing_targets.has("shin_r"), "landing authors knee absorption")
	_expect(landing_offset.y < -0.02, "hard landing lowers Grace's center of mass")

	actor.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_ANIMATION_STACK_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_ANIMATION_STACK_SMOKE_TEST: " + failure)
	get_tree().quit(1)
