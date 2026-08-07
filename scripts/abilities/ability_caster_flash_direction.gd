extends "res://scripts/abilities/ability_caster_focus_library.gd"
class_name AbilityCasterFlashDirection

const FLASH_SPELL_ID: String = "flash"


# Most free-aim spells converge from Grace's hand toward the camera-center hit
# point. Flash instead follows the camera ray itself: the direction is the spell.
# This preserves deliberate upward and downward aim rather than bending the line
# toward whichever floor or wall happened to catch the targeting ray.
func get_cast_direction(
	player: Node3D,
	cast_origin: Vector3
) -> Vector3:
	var ability: AbilityDefinition = get_current_ability()
	if ability != null and ability.get_spell_id() == FLASH_SPELL_ID:
		return _get_flash_camera_direction(player)
	return super.get_cast_direction(player, cast_origin)


func _get_flash_camera_direction(player: Node3D) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
		var screen_center: Vector2 = (
			viewport_rect.position + viewport_rect.size * 0.5
		)
		var ray_direction: Vector3 = camera.project_ray_normal(
			screen_center
		)
		if ray_direction.length_squared() > 0.0001:
			return ray_direction.normalized()
	if player != null:
		var fallback: Vector3 = -player.global_transform.basis.z
		if fallback.length_squared() > 0.0001:
			return fallback.normalized()
	return Vector3.FORWARD


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["flash_direction_authority"] = "camera_ray"
	data["flash_preserves_vertical_aim"] = true
	return data
