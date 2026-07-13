extends Node3D
class_name AnimatedArmorVisualV1

@export var idle_bob_height: float = 0.035
@export var idle_bob_speed: float = 1.35
@export var idle_core_pulse_speed: float = 3.2
@export var release_pose_duration: float = 0.24

@onready var pose_root: Node3D = $PoseRoot
@onready var core_root: Node3D = $PoseRoot/CoreRoot
@onready var outer_ring: Node3D = $PoseRoot/CoreRoot/OuterRing
@onready var inner_ring: Node3D = $PoseRoot/CoreRoot/InnerRing
@onready var left_arm_pivot: Node3D = $PoseRoot/LeftArmPivot
@onready var right_arm_pivot: Node3D = $PoseRoot/RightArmPivot
@onready var left_shoulder_pivot: Node3D = $PoseRoot/LeftShoulderPivot
@onready var right_shoulder_pivot: Node3D = $PoseRoot/RightShoulderPivot
@onready var helmet_pivot: Node3D = $PoseRoot/HelmetPivot
@onready var hammer_pivot: Node3D = $PoseRoot/HammerPivot
@onready var left_leg_pivot: Node3D = $PoseRoot/LeftLegPivot
@onready var right_leg_pivot: Node3D = $PoseRoot/RightLegPivot

var age: float = 0.0
var attack_name: String = ""
var release_timer: float = 0.0
var defeating: bool = false
var defeat_elapsed: float = 0.0
var defeat_duration: float = 1.35

var base_pose_position: Vector3
var base_pose_rotation: Vector3
var base_pose_scale: Vector3
var base_core_scale: Vector3
var base_outer_ring_scale: Vector3
var base_inner_ring_scale: Vector3
var base_left_arm_rotation: Vector3
var base_right_arm_rotation: Vector3
var base_left_shoulder_rotation: Vector3
var base_right_shoulder_rotation: Vector3
var base_helmet_rotation: Vector3
var base_hammer_rotation: Vector3
var base_left_leg_rotation: Vector3
var base_right_leg_rotation: Vector3


func _ready() -> void:
	base_pose_position = pose_root.position
	base_pose_rotation = pose_root.rotation
	base_pose_scale = pose_root.scale
	base_core_scale = core_root.scale
	base_outer_ring_scale = outer_ring.scale
	base_inner_ring_scale = inner_ring.scale
	base_left_arm_rotation = left_arm_pivot.rotation
	base_right_arm_rotation = right_arm_pivot.rotation
	base_left_shoulder_rotation = left_shoulder_pivot.rotation
	base_right_shoulder_rotation = right_shoulder_pivot.rotation
	base_helmet_rotation = helmet_pivot.rotation
	base_hammer_rotation = hammer_pivot.rotation
	base_left_leg_rotation = left_leg_pivot.rotation
	base_right_leg_rotation = right_leg_pivot.rotation


func _process(delta: float) -> void:
	age += delta

	if defeating:
		process_defeat(delta)
		return

	if release_timer > 0.0:
		process_release_pose(delta)
		return

	if attack_name == "":
		process_idle_pose(delta)


func process_idle_pose(delta: float) -> void:
	var bob: float = sin(age * idle_bob_speed) * idle_bob_height
	var core_pulse: float = 1.0 + sin(age * idle_core_pulse_speed) * 0.055
	var settle: float = clamp(delta * 8.0, 0.0, 1.0)

	pose_root.position = pose_root.position.lerp(base_pose_position + Vector3.UP * bob, settle)
	pose_root.rotation = pose_root.rotation.lerp(
		base_pose_rotation + Vector3(0.0, sin(age * 0.72) * 0.022, 0.0),
		settle
	)
	pose_root.scale = pose_root.scale.lerp(base_pose_scale, settle)
	core_root.scale = core_root.scale.lerp(base_core_scale * core_pulse, settle)
	outer_ring.scale = outer_ring.scale.lerp(base_outer_ring_scale, settle)
	inner_ring.scale = inner_ring.scale.lerp(base_inner_ring_scale, settle)
	left_arm_pivot.rotation = left_arm_pivot.rotation.lerp(base_left_arm_rotation, settle)
	right_arm_pivot.rotation = right_arm_pivot.rotation.lerp(base_right_arm_rotation, settle)
	left_shoulder_pivot.rotation = left_shoulder_pivot.rotation.lerp(base_left_shoulder_rotation, settle)
	right_shoulder_pivot.rotation = right_shoulder_pivot.rotation.lerp(base_right_shoulder_rotation, settle)
	helmet_pivot.rotation = helmet_pivot.rotation.lerp(
		base_helmet_rotation + Vector3(sin(age * 0.9) * 0.018, 0.0, 0.0),
		settle
	)
	hammer_pivot.rotation = hammer_pivot.rotation.lerp(base_hammer_rotation, settle)
	left_leg_pivot.rotation = left_leg_pivot.rotation.lerp(base_left_leg_rotation, settle)
	right_leg_pivot.rotation = right_leg_pivot.rotation.lerp(base_right_leg_rotation, settle)


func begin_attack_windup(new_attack_name: String, _duration: float) -> void:
	if defeating:
		return

	attack_name = new_attack_name
	release_timer = 0.0


func update_attack_windup(new_attack_name: String, progress: float) -> void:
	if defeating:
		return

	attack_name = new_attack_name
	var eased: float = smoothstep(0.0, 1.0, clamp(progress, 0.0, 1.0))
	reset_pose_immediately()

	if new_attack_name == "pulse":
		apply_pulse_windup(eased)
	else:
		apply_melee_windup(eased)


func apply_melee_windup(progress: float) -> void:
	pose_root.position = base_pose_position + Vector3(0.0, 0.08 * progress, 0.0)
	pose_root.rotation = base_pose_rotation + Vector3(0.0, -0.12 * progress, -0.04 * progress)
	hammer_pivot.rotation = base_hammer_rotation + Vector3(-1.4 * progress, 0.0, -0.28 * progress)
	right_arm_pivot.rotation = base_right_arm_rotation + Vector3(-0.55 * progress, 0.0, -0.22 * progress)
	right_shoulder_pivot.rotation = base_right_shoulder_rotation + Vector3(0.0, 0.0, -0.18 * progress)
	left_arm_pivot.rotation = base_left_arm_rotation + Vector3(0.18 * progress, 0.0, 0.2 * progress)
	helmet_pivot.rotation = base_helmet_rotation + Vector3(-0.11 * progress, 0.08 * progress, 0.0)
	core_root.scale = base_core_scale * (1.0 + 0.22 * progress)


func apply_pulse_windup(progress: float) -> void:
	pose_root.position = base_pose_position + Vector3.UP * (0.12 * progress)
	pose_root.rotation = base_pose_rotation + Vector3(0.0, progress * 0.22, 0.0)
	left_arm_pivot.rotation = base_left_arm_rotation + Vector3(-0.18 * progress, 0.0, 0.72 * progress)
	right_arm_pivot.rotation = base_right_arm_rotation + Vector3(-0.18 * progress, 0.0, -0.72 * progress)
	left_shoulder_pivot.rotation = base_left_shoulder_rotation + Vector3(0.0, 0.0, 0.22 * progress)
	right_shoulder_pivot.rotation = base_right_shoulder_rotation + Vector3(0.0, 0.0, -0.22 * progress)
	hammer_pivot.rotation = base_hammer_rotation + Vector3(0.2 * progress, 0.0, 0.3 * progress)
	helmet_pivot.rotation = base_helmet_rotation + Vector3(0.08 * progress, 0.0, 0.0)
	core_root.scale = base_core_scale * (1.0 + 0.72 * progress)
	outer_ring.scale = base_outer_ring_scale * (1.0 + 0.55 * progress)
	inner_ring.scale = base_inner_ring_scale * (1.0 + 0.32 * progress)
	outer_ring.rotation.y = age * 2.4
	inner_ring.rotation.x = age * 1.8


func play_attack_release(released_attack_name: String) -> void:
	if defeating:
		return

	attack_name = released_attack_name
	release_timer = release_pose_duration

	if released_attack_name == "melee":
		hammer_pivot.rotation = base_hammer_rotation + Vector3(0.95, 0.0, 0.18)
		right_arm_pivot.rotation = base_right_arm_rotation + Vector3(0.55, 0.0, 0.12)
		pose_root.rotation = base_pose_rotation + Vector3(0.16, 0.08, 0.0)
	else:
		core_root.scale = base_core_scale * 1.75
		outer_ring.scale = base_outer_ring_scale * 1.9
		inner_ring.scale = base_inner_ring_scale * 1.55
		left_arm_pivot.rotation = base_left_arm_rotation + Vector3(0.0, 0.0, 0.82)
		right_arm_pivot.rotation = base_right_arm_rotation + Vector3(0.0, 0.0, -0.82)


func process_release_pose(delta: float) -> void:
	release_timer -= delta

	if release_timer <= 0.0:
		attack_name = ""
		release_timer = 0.0


func clear_attack_pose() -> void:
	if defeating:
		return

	attack_name = ""
	release_timer = 0.0


func play_defeat(new_duration: float = 1.35) -> void:
	defeating = true
	defeat_elapsed = 0.0
	defeat_duration = max(new_duration, 0.1)
	attack_name = ""
	release_timer = 0.0
	reset_pose_immediately()


func process_defeat(delta: float) -> void:
	defeat_elapsed += delta
	var progress: float = clamp(defeat_elapsed / defeat_duration, 0.0, 1.0)
	var eased: float = smoothstep(0.0, 1.0, progress)

	pose_root.position = base_pose_position + Vector3(0.0, -1.15 * eased, 0.16 * eased)
	pose_root.rotation = base_pose_rotation + Vector3(0.42 * eased, -0.18 * eased, 0.72 * eased)
	pose_root.scale = base_pose_scale.lerp(Vector3(0.88, 0.5, 0.88), eased)
	core_root.scale = base_core_scale * max(1.0 - eased, 0.02)
	outer_ring.scale = base_outer_ring_scale * max(1.0 - eased, 0.02)
	inner_ring.scale = base_inner_ring_scale * max(1.0 - eased, 0.02)
	left_shoulder_pivot.rotation = base_left_shoulder_rotation + Vector3(0.0, 0.0, 0.9 * eased)
	right_shoulder_pivot.rotation = base_right_shoulder_rotation + Vector3(0.0, 0.0, -1.15 * eased)
	left_arm_pivot.rotation = base_left_arm_rotation + Vector3(0.45 * eased, 0.0, 0.75 * eased)
	right_arm_pivot.rotation = base_right_arm_rotation + Vector3(0.8 * eased, 0.0, -0.9 * eased)
	hammer_pivot.rotation = base_hammer_rotation + Vector3(0.65 * eased, 0.0, 1.15 * eased)
	left_leg_pivot.rotation = base_left_leg_rotation + Vector3(0.16 * eased, 0.0, 0.18 * eased)
	right_leg_pivot.rotation = base_right_leg_rotation + Vector3(-0.22 * eased, 0.0, -0.2 * eased)


func reset_pose_immediately() -> void:
	pose_root.position = base_pose_position
	pose_root.rotation = base_pose_rotation
	pose_root.scale = base_pose_scale
	core_root.scale = base_core_scale
	outer_ring.scale = base_outer_ring_scale
	inner_ring.scale = base_inner_ring_scale
	left_arm_pivot.rotation = base_left_arm_rotation
	right_arm_pivot.rotation = base_right_arm_rotation
	left_shoulder_pivot.rotation = base_left_shoulder_rotation
	right_shoulder_pivot.rotation = base_right_shoulder_rotation
	helmet_pivot.rotation = base_helmet_rotation
	hammer_pivot.rotation = base_hammer_rotation
	left_leg_pivot.rotation = base_left_leg_rotation
	right_leg_pivot.rotation = base_right_leg_rotation
