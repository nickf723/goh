extends Node

const RigScene: PackedScene = preload(
	"res://scenes/actors/player/grace_humanoid_skeletal_proxy_v2.tscn"
)
const VerticalMotionScript: Script = preload(
	"res://scripts/player/player_vertical_motion_controller.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	await _validate_locomotion_rig()
	_finish()


func _validate_locomotion_rig() -> void:
	var actor := CharacterBody3D.new()
	actor.name = "LocomotionV2TestActor"
	add_child(actor)

	var vertical: PlayerVerticalMotionController = (
		VerticalMotionScript.new() as PlayerVerticalMotionController
	)
	vertical.name = "VerticalMotionController"
	actor.add_child(vertical)

	var rig: Node3D = RigScene.instantiate() as Node3D
	_expect(rig != null, "locomotion V2 skeletal scene instantiates")
	if rig == null:
		actor.queue_free()
		return
	actor.add_child(rig)
	await get_tree().process_frame

	_expect(
		rig.has_method("get_debug_data"),
		"locomotion V2 rig exposes debug data"
	)
	var data: Dictionary = (
		rig.call("get_debug_data") as Dictionary
		if rig.has_method("get_debug_data")
		else {}
	)
	_expect(bool(data.get("locomotion_v2", false)), "locomotion V2 layer is live")
	_expect(bool(data.get("locomotion_v2b", false)), "center-of-mass correction layer is live")

	actor.velocity = Vector3(1.2, 0.0, -5.0)
	var run_targets: Dictionary = {}
	var run_offset: Vector3 = rig.call(
		"_pose_locomotion",
		run_targets,
		1.0 / 60.0
	) as Vector3
	_expect(run_targets.has("pelvis"), "run pose authors pelvis motion")
	_expect(run_targets.has("thigh_l") and run_targets.has("thigh_r"), "run pose authors both legs")
	_expect(run_targets.has("upper_arm_l") and run_targets.has("upper_arm_r"), "run pose authors counter-swinging arms")
	_expect(run_offset.is_finite(), "run center-of-mass offset remains finite")

	vertical.vertical_state = "landing"
	vertical.last_landing_strength = 1.0
	vertical.landing_duration = 0.28
	vertical.landing_remaining = 0.19
	actor.velocity = Vector3(0.0, 0.0, -2.0)
	var landing_targets: Dictionary = {}
	var landing_offset: Vector3 = rig.call(
		"_pose_idle",
		landing_targets
	) as Vector3
	_expect(landing_targets.has("shin_l") and landing_targets.has("shin_r"), "landing authors knee absorption")
	_expect(landing_offset.y < -0.02, "hard landing lowers Grace's center of mass")

	vertical.vertical_state = "apex"
	vertical.airborne_time = 0.35
	actor.velocity = Vector3(2.0, 0.1, -3.5)
	var air_targets: Dictionary = {}
	var air_offset: Vector3 = rig.call(
		"_pose_airborne",
		air_targets,
		"fall"
	) as Vector3
	_expect(air_targets.has("chest"), "airborne progression authors torso pose")
	_expect(air_targets.has("thigh_l") and air_targets.has("thigh_r"), "airborne progression authors leg silhouette")
	_expect(air_offset.is_finite(), "airborne center-of-mass offset remains finite")

	actor.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_LOCOMOTION_V2_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_LOCOMOTION_V2_SMOKE_TEST: " + failure)
	get_tree().quit(1)
