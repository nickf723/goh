extends "res://scripts/weapons/weapon_staff_focus_controller_v2.gd"
class_name WeaponStaffFocusControllerV3

# Staff charges and the timed aerial vault aim with the movement stick, while
# camera look remains entirely on the camera stick. The actor root owns the
# camera in the current player rig, so rotating that root for staff facing made
# the left stick orbit the camera and could snap the view when a vault launched.
# V3 turns only the combat presentation instead: WeaponController and Grace's
# skeletal root receive the same relative yaw while hit geometry keeps using the
# authored world-space attack heading.

const STAFF_VISUAL_FACING_META: StringName = &"staff_visual_facing_yaw"

@export_group("Staff Camera Decoupling")
@export_range(90.0, 720.0, 5.0) var staff_visual_return_degrees_per_second: float = 420.0

var staff_visual_heading_active: bool = false
var staff_visual_world_heading: Vector3 = Vector3.FORWARD
var staff_controller_base_rotation_y: float = 0.0


func _ready() -> void:
	staff_controller_base_rotation_y = rotation.y
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	_update_staff_visual_facing(delta)


func _exit_tree() -> void:
	_clear_staff_visual_facing(true)
	super._exit_tree()


func equip_weapon(new_weapon: WeaponDefinition) -> void:
	if new_weapon == null or new_weapon.weapon_class != "staff":
		_clear_staff_visual_facing(true)
	super.equip_weapon(new_weapon)


func _apply_actor_heading(direction: Vector3) -> void:
	if not _is_staff_equipped():
		super._apply_actor_heading(direction)
		return
	_set_staff_visual_heading(direction)


func apply_attack_facing(direction: Vector3) -> void:
	if _staff_attack_uses_visual_facing(current_attack):
		_set_staff_visual_heading(direction)
		return
	super.apply_attack_facing(direction)


func _set_staff_visual_heading(direction: Vector3) -> void:
	var planar: Vector3 = direction
	planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		return
	staff_visual_world_heading = planar.normalized()
	staff_visual_heading_active = true
	_apply_staff_visual_heading_now()


func _update_staff_visual_facing(delta: float) -> void:
	if not _is_staff_equipped():
		_clear_staff_visual_facing(true)
		return

	if _staff_should_hold_visual_heading():
		var live_heading: Vector3 = _get_live_staff_special_heading()
		if live_heading.length_squared() > 0.0001:
			staff_visual_world_heading = live_heading.normalized()
			staff_visual_heading_active = true
		if staff_visual_heading_active:
			_apply_staff_visual_heading_now()
		return

	_return_staff_visual_facing(delta)


func _staff_should_hold_visual_heading() -> bool:
	if charge_active:
		var charge_id: String = str(charge_profile.get("id", ""))
		if charge_id in ["staff_returning_throw", "staff_angel_ring"]:
			return true
	if staff_vault_state != STAFF_VAULT_IDLE:
		return true
	return _staff_attack_uses_visual_facing(current_attack)


func _staff_attack_uses_visual_facing(
	attack: WeaponAttackDefinition
) -> bool:
	if not _is_staff_equipped() or attack == null:
		return false
	return (
		attack.extra_tags.has("staff_returning_throw")
		or attack.extra_tags.has("staff_angel_ring_release")
		or attack.extra_tags.has("staff_aerial_vault")
	)


func _get_live_staff_special_heading() -> Vector3:
	var heading: Vector3 = Vector3.ZERO
	if staff_vault_state != STAFF_VAULT_IDLE:
		heading = staff_vault_heading
	elif attack_forward_override.length_squared() > 0.0001:
		heading = attack_forward_override
	elif staff_charge_heading_initialized:
		heading = staff_charge_heading
	else:
		heading = staff_visual_world_heading
	heading.y = 0.0
	return heading.normalized() if heading.length_squared() > 0.0001 else Vector3.ZERO


func _apply_staff_visual_heading_now() -> void:
	var actor: Node3D = get_actor()
	if actor == null or staff_visual_world_heading.length_squared() <= 0.0001:
		return
	var actor_forward: Vector3 = -actor.global_transform.basis.z
	actor_forward.y = 0.0
	if actor_forward.length_squared() <= 0.0001:
		actor_forward = Vector3.FORWARD
	else:
		actor_forward = actor_forward.normalized()
	var desired: Vector3 = staff_visual_world_heading.normalized()
	var relative_yaw: float = atan2(
		actor_forward.cross(desired).dot(Vector3.UP),
		clampf(actor_forward.dot(desired), -1.0, 1.0)
	)
	rotation.y = staff_controller_base_rotation_y + relative_yaw
	actor.set_meta(STAFF_VISUAL_FACING_META, relative_yaw)


func _return_staff_visual_facing(delta: float) -> void:
	var maximum_step: float = deg_to_rad(staff_visual_return_degrees_per_second) * maxf(delta, 0.0)
	var difference: float = wrapf(
		staff_controller_base_rotation_y - rotation.y,
		-PI,
		PI
	)
	rotation.y += clampf(difference, -maximum_step, maximum_step)
	var relative_yaw: float = wrapf(
		rotation.y - staff_controller_base_rotation_y,
		-PI,
		PI
	)
	var actor: Node3D = get_actor()
	if absf(relative_yaw) <= deg_to_rad(0.35):
		rotation.y = staff_controller_base_rotation_y
		staff_visual_heading_active = false
		if actor != null and actor.has_meta(STAFF_VISUAL_FACING_META):
			actor.remove_meta(STAFF_VISUAL_FACING_META)
		return
	if actor != null:
		actor.set_meta(STAFF_VISUAL_FACING_META, relative_yaw)


func _clear_staff_visual_facing(immediate: bool) -> void:
	if immediate:
		rotation.y = staff_controller_base_rotation_y
	staff_visual_heading_active = false
	var actor: Node3D = get_actor()
	if actor != null and actor.has_meta(STAFF_VISUAL_FACING_META):
		actor.remove_meta(STAFF_VISUAL_FACING_META)


func get_staff_focus_v3_debug_data() -> Dictionary:
	return {
		"staff_focus_v3": true,
		"camera_yaw_decoupled": true,
		"left_stick_aims_staff_only": true,
		"staff_visual_heading_active": staff_visual_heading_active,
		"staff_visual_heading": staff_visual_world_heading,
		"staff_visual_relative_yaw": snappedf(
			rotation.y - staff_controller_base_rotation_y,
			0.001
		),
	}
