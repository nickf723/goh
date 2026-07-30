extends RefCounted
class_name EngagementLaneRegistry


const Blackboard = preload(
	"res://scripts/ai/tactical_blackboard.gd"
)


static func reserve_lane(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	lane_id: String,
	target_id: int = 0,
	duration: float = 0.55,
	priority: float = 0.0,
	metadata: Dictionary = {}
) -> Dictionary:
	return Blackboard.reserve_engagement_lane(
		squad_id,
		owner_id,
		owner_name,
		lane_id,
		target_id,
		duration,
		priority,
		metadata
	)


static func get_occupied_lanes(
	squad_id: String,
	exclude_owner_id: int = 0,
	target_id: int = 0
) -> Array[String]:
	var context: Dictionary = Blackboard.get_coordination_context(
		squad_id,
		exclude_owner_id,
		target_id
	)
	var result: Array[String] = []
	var value: Variant = context.get("occupied_engagement_lanes", [])
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result
