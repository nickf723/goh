extends Node
class_name GraceAgilityCalibration

# Dojo-only calibration for Grace's intended physical rhythm before the skeletal
# animation pipeline is promoted to the canonical player. Gameplay remains
# authoritative; this node swaps data profiles and adjusts active presentation.

@export var ground_profile: GroundMotionProfile
@export var dodge_profile: DodgeMotionProfile

@export_group("Proportions")
@export_range(0.8, 1.05, 0.01) var visual_scale: float = 0.93

@export_group("Locomotion Presentation")
@export_range(3.0, 8.0, 0.05) var visual_speed_reference: float = 5.45
@export_range(4.0, 20.0, 0.5) var locomotion_blend_response: float = 12.0
@export_range(4.0, 14.0, 0.1) var movement_bob_speed: float = 9.0
@export_range(0.2, 1.0, 0.01) var stride_radians: float = 0.61
@export_range(0.2, 0.8, 0.01) var arm_swing_radians: float = 0.46
@export_range(0.05, 0.25, 0.01) var maximum_lean_radians: float = 0.13

var ground_motion_motor: PlayerGroundMotionMotor
var dodge_controller: PlayerDodgeController
var grace_visual: Node3D
var weapon_controller: Node


func _ready() -> void:
	var actor: Node = get_parent()
	if actor == null:
		return
	ground_motion_motor = actor.get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
	dodge_controller = actor.get_node_or_null("PlayerDodgeController") as PlayerDodgeController
	# Prefer the real Skeleton3D proxy when present; fall back to the procedural
	# visual so this calibration remains usable outside the animation experiment.
	grace_visual = actor.get_node_or_null("GraceSkeletalVisualV1") as Node3D
	if grace_visual == null:
		grace_visual = actor.get_node_or_null("GraceVisualV1") as Node3D
	weapon_controller = actor.get_node_or_null("WeaponController")

	if ground_motion_motor != null and ground_profile != null:
		ground_motion_motor.profile = ground_profile
	if dodge_controller != null and dodge_profile != null:
		dodge_controller.profile = dodge_profile

	_apply_visual_calibration()
	add_to_group("grace_agility_calibration")
	add_to_group("debuggable")


func _apply_visual_calibration() -> void:
	if grace_visual == null:
		return
	grace_visual.scale = Vector3.ONE * visual_scale
	if "presentation_scale" in grace_visual:
		grace_visual.set("presentation_scale", visual_scale)
	if "locomotion_speed_reference" in grace_visual:
		grace_visual.set("locomotion_speed_reference", visual_speed_reference)
	if "locomotion_blend_response" in grace_visual:
		grace_visual.set("locomotion_blend_response", locomotion_blend_response)
	if "movement_bob_speed" in grace_visual:
		grace_visual.set("movement_bob_speed", movement_bob_speed)
	if "stride_radians" in grace_visual:
		grace_visual.set("stride_radians", stride_radians)
	if "stride_strength" in grace_visual:
		grace_visual.set("stride_strength", stride_radians)
	if "arm_swing_radians" in grace_visual:
		grace_visual.set("arm_swing_radians", arm_swing_radians)
	if "arm_swing_strength" in grace_visual:
		grace_visual.set("arm_swing_strength", arm_swing_radians)
	if "maximum_lean_radians" in grace_visual:
		grace_visual.set("maximum_lean_radians", maximum_lean_radians)


func get_debug_data() -> Dictionary:
	return {
		"agile_grace": true,
		"visual_scale": visual_scale,
		"visual_node": grace_visual.name if grace_visual != null else "none",
		"skeletal_visual_active": (
			grace_visual != null
			and grace_visual.name == "GraceSkeletalVisualV1"
		),
		"maximum_speed": (
			ground_motion_motor.get_configured_maximum_speed()
			if ground_motion_motor != null
			else -1.0
		),
		"ground_acceleration": (
			ground_motion_motor.profile.acceleration
			if ground_motion_motor != null and ground_motion_motor.profile != null
			else -1.0
		),
		"dodge_duration": (
			dodge_controller.profile.duration
			if dodge_controller != null and dodge_controller.profile != null
			else -1.0
		),
		"dodge_distance": (
			dodge_controller.profile.distance
			if dodge_controller != null and dodge_controller.profile != null
			else -1.0
		),
	}
