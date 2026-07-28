extends Node
class_name PlayerWeaponControlAnimator

const WeaponCharacterPoseCatalogScript = preload(
	"res://scripts/weapons/weapon_character_pose_catalog.gd"
)

@export var enabled: bool = true
@export_range(0.04, 0.3, 0.01) var trail_recovery_fraction: float = 0.18

var weapon_controller: WeaponController
var active_attack: WeaponAttackDefinition
var active_profile_id: String = ""
var trail_started: bool = false
var last_sample: Dictionary = {}


func _ready() -> void:
	process_priority = 120
	weapon_controller = get_parent().get_node_or_null("WeaponController") as WeaponController
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
	if attack == null or not WeaponCharacterPoseCatalogScript.has_profile(attack.character_pose_id):
		if active_attack != null:
			_release_control()
		return

	if active_attack != attack:
		_begin_control(attack)

	var sample: Dictionary = WeaponCharacterPoseCatalogScript.sample_attack(
		attack,
		weapon_controller.current_attack_elapsed,
		weapon_controller.get_attack_speed()
	)
	if sample.is_empty():
		return

	_apply_weapon_sample(sample)
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
		"phase_weight": snappedf(float(last_sample.get("phase_weight", 0.0)), 0.01),
		"weapon_rotation_share": float(last_sample.get("weapon_rotation_share", 1.0)),
		"weapon_offset_share": float(last_sample.get("weapon_offset_share", 1.0)),
		"trail_started": trail_started,
	}


func _on_attack_started(attack: WeaponAttackDefinition) -> void:
	if not enabled or attack == null:
		return
	if not WeaponCharacterPoseCatalogScript.has_profile(attack.character_pose_id):
		return
	_begin_control(attack)


func _on_attack_finished(_attack_id: String) -> void:
	_release_control()


func _begin_control(attack: WeaponAttackDefinition) -> void:
	active_attack = attack
	active_profile_id = attack.character_pose_id
	trail_started = false
	last_sample.clear()
	_cancel_default_weapon_tweens()
	if weapon_controller.weapon_visual_pivot != null:
		weapon_controller.weapon_visual_pivot.visible = true
	sample_now_deferred_safe()


func sample_now_deferred_safe() -> void:
	if active_attack == null or weapon_controller == null:
		return
	var sample: Dictionary = WeaponCharacterPoseCatalogScript.sample_attack(
		active_attack,
		weapon_controller.current_attack_elapsed,
		weapon_controller.get_attack_speed()
	)
	if not sample.is_empty():
		_apply_weapon_sample(sample)
		last_sample = sample.duplicate(true)


func _release_control() -> void:
	active_attack = null
	active_profile_id = ""
	trail_started = false
	last_sample.clear()


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
	var sampled_rotation: Vector3 = sample.get("weapon_rotation_degrees", Vector3.ZERO)
	var sampled_offset: Vector3 = sample.get("weapon_offset", Vector3.ZERO)
	pivot.rotation_degrees = weapon_controller.base_visual_rotation_degrees + sampled_rotation
	pivot.position = weapon_controller.base_visual_position + sampled_offset


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

