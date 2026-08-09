extends "res://scripts/actions/life_vine_grapple.gd"
class_name LifeVineGrappleTargeted

const VineTargeting = preload(
	"res://scripts/player/vine_grapple_targeting.gd"
)
const SpellPresentation = preload(
	"res://scripts/presentation/spell_presentation_bridge.gd"
)

var last_targeting_result: Dictionary = {}


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	set_source_actor(player)
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	_present_vine_phase("release", null, get_source_anchor_position(), "vine_cast")
	last_targeting_result = VineTargeting.resolve_target(
		source_actor,
		maximum_target_range,
		maximum_rigidbody_mass,
		soft_aim_angle_degrees,
		require_line_of_sight
	)
	var target: Node3D = _valid_target_reference(last_targeting_result.get("target"))
	var point_value: Variant = last_targeting_result.get("point")
	if target == null or not point_value is Vector3:
		_present_vine_phase("cancel", null, get_source_anchor_position(), "no_target")
		show_message("Vine Grapple found no pullable target.")
		queue_free()
		return
	if not bool(last_targeting_result.get("valid", false)):
		_present_vine_phase("cancel", target, point_value, str(last_targeting_result.get("reason", "invalid")))
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
		_present_vine_phase("cancel", target, point_value, "resisted")
		show_message("That target resists Vine Grapple.")
		queue_free()


func attach_to_target(target: Node3D, world_anchor: Vector3) -> bool:
	var attached: bool = super.attach_to_target(target, world_anchor)
	if not attached:
		return false
	_present_vine_phase("latch", target, world_anchor, "tether_attached")
	_present_vine_phase("sustain", target, world_anchor, "tension", true)
	return true


func release_grapple(
	reason: String = "released",
	should_show_message: bool = false
) -> void:
	if grapple_active or active_target != null:
		var safe_target: Node3D = _valid_target_reference(active_target)
		var position: Vector3 = (
			get_target_anchor_position()
			if safe_target != null
			else get_source_anchor_position()
		)
		var phase: String = (
			"resolve"
			if reason in ["reeled in", "vine snapped", "out of range", "target unavailable"]
			else "cancel"
		)
		_present_vine_phase(phase, safe_target, position, reason)
	super.release_grapple(reason, should_show_message)


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


func _present_vine_phase(
	phase: String,
	target: Node3D,
	position: Vector3,
	detail: String,
	subtle: bool = false
) -> void:
	var context: Dictionary = {
		"actor": source_actor,
		"target": target,
		"position": position,
		"spell_id": "vine_grapple",
		"spell_name": "Vine Grapple",
		"element": "life",
		"delivery_type": "channeled_tether",
		"targeting_style": "soft_aim",
		"detail": detail,
		"subtle": subtle,
	}
	SpellPresentation.present(self, phase, context)


func _valid_target_reference(value: Variant) -> Node3D:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as Node3D if value is Node3D else null


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["targeting_authority"] = "vine_grapple_targeting"
	data["targeting_source"] = str(last_targeting_result.get("source", "none"))
	data["targeting_valid"] = bool(last_targeting_result.get("valid", false))
	data["targeting_reason"] = str(last_targeting_result.get("reason", ""))
	data["presentation_lifecycle"] = ["prepare", "release", "latch", "sustain", "resolve"]
	return data
