extends Node
class_name PlayerWeaponControlAnimator

const WeaponPoseCatalogRouterScript = preload(
	"res://scripts/weapons/weapon_pose_catalog_router.gd"
)

@export var enabled: bool = true
@export_range(0.04, 0.3, 0.01) var trail_recovery_fraction: float = 0.18

var weapon_controller: WeaponController
var visual: GraceWireMotionVisual
var support_hand: Node3D
var wire_skeleton_renderer: GraceWireSkeletonRenderer
var active_attack: WeaponAttackDefinition
var active_profile_id: String = ""
var trail_started: bool = false
var last_sample: Dictionary = {}
var support_hand_locked: bool = false
var support_hand_weight: float = 0.0
var support_hand_target_world: Vector3 = Vector3.ZERO
var support_hand_error: float = 0.0


func _ready() -> void:
	process_priority = 120
	weapon_controller = get_parent().get_node_or_null("WeaponController") as WeaponController
	visual = get_parent().get_node_or_null("GraceVisualV1") as GraceWireMotionVisual
	support_hand = get_parent().get_node_or_null(
		"GraceVisualV1/VisualRoot/LeftShoulderPivot/LeftHand"
	) as Node3D
	wire_skeleton_renderer = get_parent().get_node_or_null(
		"GraceVisualV1/WireSkeletonRenderer"
	) as GraceWireSkeletonRenderer
	if weapon_controller != null:
		if not weapon_controller.attack_started.is_connected(_on_attack_started):
			weapon_controller.attack_started.connect(_on_attack_started)
		if not weapon_controller.attack_finished.is_connected(_on_attack_finished):
			weapon_controller.attack_finished.connect(_on_attack_finished)
	add_to_group("player_weapon_control_animator")


func _exit_tree() -> void:
	if weapon_controller == null:
		return
	if weapon_controller.attack_started.is_connected(_on_attack_started):
		weapon_controller.attack_started.disconnect(_on_attack_started)
	if weapon_controller.attack_finished.is_connected(_on_attack_finished):
		weapon_controller.attack_finished.disconnect(_on_attack_finished)


func _process(_delta: float) -> void:
	sample_now()


func sample_now() -> void:
	if not enabled or weapon_controller == null:
		return

	var attack: WeaponAttackDefinition = weapon_controller.current_attack
	if attack == null or not WeaponPoseCatalogRouterScript.has_profile(
		attack.character_pose_id
	):
		if active_attack != null:
			_release_control()
		return

	if active_attack != attack:
		_begin_control(attack)

	var sample: Dictionary = WeaponPoseCatalogRouterScript.sample_attack(
		attack,
		weapon_controller.current_attack_elapsed,
		weapon_controller.get_attack_speed()
	)
	if sample.is_empty():
		return

	_apply_weapon_sample(sample)
	_apply_support_hand_sample(sample)
	_maybe_start_trail(attack, sample)
	last_sample = sample.duplicate(true)


func is_controlling_attack() -> bool:
	return active_attack != null and active_profile_id != ""


func get_debug_data() -> Dictionary:
	return {
		"active": is_controlling_attack(),
		"attack_id": active_attack.attack_id if active_attack != null else "",
		"profile_id": active_profile_id,
		"phase": str(last_sample.get("phase", "idle")),
		"phase_weight": snappedf(
			float(last_sample.get("phase_weight", 0.0)),
			0.01
		),
		"weapon_rotation_share": float(
			last_sample.get("weapon_rotation_share", 1.0)
		),
		"weapon_offset_share": float(
			last_sample.get("weapon_offset_share", 1.0)
		),
		"trail_started": trail_started,
		"two_handed": bool(last_sample.get("two_handed", false)),
		"support_hand_locked": support_hand_locked,
		"support_hand_weight": snappedf(support_hand_weight, 0.01),
		"support_hand_target_world": support_hand_target_world,
		"support_hand_error": snappedf(support_hand_error, 0.001),
	}


func _on_attack_started(attack: WeaponAttackDefinition) -> void:
	if not enabled or attack == null:
		return
	if not WeaponPoseCatalogRouterScript.has_profile(attack.character_pose_id):
		return
	_begin_control(attack)


func _on_attack_finished(_attack_id: String) -> void:
	_release_control()


func _begin_control(attack: WeaponAttackDefinition) -> void:
	active_attack = attack
	active_profile_id = attack.character_pose_id
	trail_started = false
	last_sample.clear()
	support_hand_locked = false
	support_hand_weight = 0.0
	support_hand_error = 0.0
	_cancel_default_weapon_tweens()
	if weapon_controller.weapon_visual_pivot != null:
		weapon_controller.weapon_visual_pivot.visible = true
	sample_now_deferred_safe()


func sample_now_deferred_safe() -> void:
	if active_attack == null or weapon_controller == null:
		return
	var sample: Dictionary = WeaponPoseCatalogRouterScript.sample_attack(
		active_attack,
		weapon_controller.current_attack_elapsed,
		weapon_controller.get_attack_speed()
	)
	if not sample.is_empty():
		_apply_weapon_sample(sample)
		_apply_support_hand_sample(sample)
		last_sample = sample.duplicate(true)


func _release_control() -> void:
	active_attack = null
	active_profile_id = ""
	trail_started = false
	last_sample.clear()
	support_hand_locked = false
	support_hand_weight = 0.0
	support_hand_target_world = Vector3.ZERO
	support_hand_error = 0.0


func _cancel_default_weapon_tweens() -> void:
	if weapon_controller.swing_tween != null:
		weapon_controller.swing_tween.kill()
	if weapon_controller.sweep_tween != null:
		weapon_controller.sweep_tween.kill()
	if weapon_controller.slash_trail != null:
		weapon_controller.slash_trail.visible = false


func _apply_weapon_sample(sample: Dictionary) -> void:
	var pivot: Node3D = weapon_controller.weapon_visual_pivot
	if pivot == null:
		return
	var sampled_rotation: Vector3 = sample.get(
		"weapon_rotation_degrees",
		Vector3.ZERO
	)
	var sampled_offset: Vector3 = sample.get("weapon_offset", Vector3.ZERO)
	pivot.rotation_degrees = (
		weapon_controller.base_visual_rotation_degrees + sampled_rotation
	)
	pivot.position = weapon_controller.base_visual_position + sampled_offset


func _apply_support_hand_sample(sample: Dictionary) -> void:
	support_hand_locked = false
	support_hand_weight = 0.0
	support_hand_error = 0.0
	if not bool(sample.get("two_handed", false)):
		return
	if support_hand == null or weapon_controller.runtime_weapon_rig == null:
		return

	var weight: float = clampf(
		float(sample.get("support_hand_weight", 0.0)),
		0.0,
		1.0
	)
	if weight <= 0.001:
		return

	var rig: Node3D = weapon_controller.runtime_weapon_rig
	var grip_local_position: Vector3 = sample.get(
		"support_grip_position",
		Vector3(0.12, 0.0, -0.62)
	)
	var grip_local_rotation: Vector3 = sample.get(
		"support_grip_rotation",
		Vector3.ZERO
	)
	var target_position: Vector3 = rig.to_global(grip_local_position)
	var target_basis: Basis = (
		rig.global_basis.orthonormalized()
		* Basis.from_euler(grip_local_rotation)
	).orthonormalized()
	var current_transform: Transform3D = support_hand.global_transform
	var current_rotation: Quaternion = (
		current_transform.basis.orthonormalized().get_rotation_quaternion()
	)
	var target_rotation: Quaternion = target_basis.get_rotation_quaternion()
	var blended_rotation: Quaternion = current_rotation.slerp(
		target_rotation,
		weight
	)
	var blended_position: Vector3 = current_transform.origin.lerp(
		target_position,
		weight
	)
	support_hand.global_transform = Transform3D(
		Basis(blended_rotation).orthonormalized(),
		blended_position
	)

	support_hand_locked = true
	support_hand_weight = weight
	support_hand_target_world = target_position
	support_hand_error = support_hand.global_position.distance_to(target_position)
	if visual != null:
		visual.sync_animation_anchors()
	if wire_skeleton_renderer != null:
		wire_skeleton_renderer.sample_now(0.0)


func _maybe_start_trail(
	attack: WeaponAttackDefinition,
	sample: Dictionary
) -> void:
	if trail_started or str(sample.get("phase", "")) != "active":
		return
	trail_started = true
	weapon_controller.play_slash_trail(attack)
	if weapon_controller.sweep_tween == null:
		return
	# The controller's trail method already owns cleanup. The delayed start is the
	# important change: anticipation remains quiet, then the trail follows the cut.
