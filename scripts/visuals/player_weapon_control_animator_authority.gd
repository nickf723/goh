extends "res://scripts/visuals/player_weapon_control_animator.gd"
class_name PlayerWeaponControlAnimatorAuthority

var elemental_authority_controller: PlayerElementalAuthorityController
var authority_cast_active: bool = false
var authority_cast_id: String = ""


func _ready() -> void:
	super._ready()
	elemental_authority_controller = get_parent().get_node_or_null(
		"ElementalAuthorityController"
	) as PlayerElementalAuthorityController


func sample_now() -> void:
	if not enabled or weapon_controller == null:
		return

	if weapon_controller.current_attack != null:
		if authority_cast_active:
			_release_authority_control(false)
		super.sample_now()
		return

	var authority_sample: Dictionary = {}
	if elemental_authority_controller != null:
		authority_sample = elemental_authority_controller.get_cast_pose_sample()

	if authority_sample.is_empty():
		if authority_cast_active:
			_release_authority_control(true)
		super.sample_now()
		return

	if active_attack != null:
		_release_control()
	if not authority_cast_active:
		_cancel_default_weapon_tweens()
		authority_cast_active = true
		authority_cast_id = str(
			authority_sample.get("authority_cast_id", "authority_cast")
		)

	_apply_weapon_sample(authority_sample)
	_apply_support_hand_sample(authority_sample)
	last_sample = authority_sample.duplicate(true)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["authority_cast_active"] = authority_cast_active
	data["authority_cast_id"] = authority_cast_id if authority_cast_active else "none"
	data["authority_cast_control"] = (
		"two_handed_halberd"
		if authority_cast_active
		else "none"
	)
	return data


func _release_authority_control(reset_weapon_pose: bool) -> void:
	authority_cast_active = false
	authority_cast_id = ""
	support_hand_locked = false
	support_hand_weight = 0.0
	support_hand_target_world = Vector3.ZERO
	support_hand_error = 0.0
	last_sample.clear()
	if reset_weapon_pose and weapon_controller != null:
		weapon_controller.reset_visual_pose()
