extends "res://scripts/actions/life_vine_grapple.gd"
class_name LifeVineGrappleTargeted

const VineTargeting = preload(
	"res://scripts/player/vine_grapple_targeting.gd"
)

var last_targeting_result: Dictionary = {}


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	set_source_actor(player)
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	last_targeting_result = VineTargeting.resolve_target(
		source_actor,
		maximum_target_range,
		maximum_rigidbody_mass,
		soft_aim_angle_degrees,
		require_line_of_sight
	)
	var target: Node3D = last_targeting_result.get("target") as Node3D
	var point_value: Variant = last_targeting_result.get("point")
	if target == null or not point_value is Vector3:
		show_message("Vine Grapple found no pullable target.")
		queue_free()
		return
	if not bool(last_targeting_result.get("valid", false)):
		show_message(
			"Vine Grapple • "
			+ VineTargeting.get_target_display_name(target)
			+ " • "
			+ VineTargeting.get_reason_label(
				str(last_targeting_result.get("reason", ""))
			)
		)
		queue_free()
		return
	if not attach_to_target(target, point_value as Vector3):
		show_message("That target resists Vine Grapple.")
		queue_free()


func find_grapple_target(_cast_direction: Vector3) -> Dictionary:
	if source_actor == null:
		return {}
	last_targeting_result = VineTargeting.resolve_target(
		source_actor,
		maximum_target_range,
		maximum_rigidbody_mass,
		soft_aim_angle_degrees,
		require_line_of_sight
	)
	return last_targeting_result if bool(last_targeting_result.get("valid", false)) else {}


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["targeting_authority"] = "vine_grapple_targeting"
	data["targeting_source"] = str(last_targeting_result.get("source", "none"))
	data["targeting_valid"] = bool(last_targeting_result.get("valid", false))
	data["targeting_reason"] = str(last_targeting_result.get("reason", ""))
	return data
