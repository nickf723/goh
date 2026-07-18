extends RefCounted
class_name EnemyZoneAwareness

const HAZARD_GROUP: String = "hazard_reactive"

const DANGER_TAGS: Array[String] = ["poison", "gas", "cloud", "fire", "flame", "burning", "explosion"]
const SLOW_TAGS: Array[String] = ["time", "slow", "tempo"]
const TRAP_TAGS: Array[String] = ["trap", "illusion", "dreams"]


static func evaluate(actor: Node3D, awareness_radius: float = 5.0, danger_margin: float = 1.1) -> Dictionary:
	if actor == null or not actor.is_inside_tree():
		return empty_result()

	var tree: SceneTree = actor.get_tree()
	if tree == null:
		return empty_result()

	var best_result: Dictionary = empty_result()
	var best_score: float = 0.0
	var combined_avoidance: Vector3 = Vector3.ZERO

	for hazard_variant: Variant in tree.get_nodes_in_group(HAZARD_GROUP):
		if hazard_variant == null:
			continue
		if not hazard_variant is Node:
			continue

		var hazard: Node = hazard_variant as Node
		if not is_instance_valid(hazard) or hazard == actor:
			continue
		if not hazard is Node3D:
			continue

		var hazard_3d: Node3D = hazard as Node3D
		var hazard_tags: Array[String] = get_hazard_tags(hazard)
		var behavior: String = classify_tags(hazard_tags)
		if behavior == "neutral":
			continue

		var radius: float = get_hazard_radius(hazard, 2.0)
		var flat_offset: Vector3 = actor.global_position - hazard_3d.global_position
		flat_offset.y = 0.0
		var distance: float = flat_offset.length()
		var scan_radius: float = max(awareness_radius, radius + danger_margin)

		if distance > scan_radius:
			continue

		var inside: bool = distance <= radius
		var closeness: float = 1.0 - clamp(distance / max(scan_radius, 0.01), 0.0, 1.0)
		var score: float = closeness * get_behavior_weight(behavior, inside)

		if flat_offset.length() > 0.01:
			combined_avoidance += flat_offset.normalized() * score

		if score > best_score:
			best_score = score
			best_result = {
				"active": true,
				"behavior": behavior,
				"summary": describe_hazard(hazard_tags),
				"tags": hazard_tags,
				"distance": distance,
				"radius": radius,
				"inside": inside,
				"hesitate": should_hesitate(behavior, inside),
				"score": score,
			}

	if not bool(best_result.get("active", false)):
		return empty_result()

	if combined_avoidance.length() > 0.01:
		best_result["avoid_direction"] = combined_avoidance.normalized()
	else:
		best_result["avoid_direction"] = Vector3.ZERO

	return best_result


static func empty_result() -> Dictionary:
	return {
		"active": false,
		"behavior": "none",
		"summary": "clear",
		"tags": [],
		"distance": INF,
		"radius": 0.0,
		"inside": false,
		"hesitate": false,
		"score": 0.0,
		"avoid_direction": Vector3.ZERO,
	}


static func get_hazard_tags(hazard: Node) -> Array[String]:
	var tags: Array[String] = []

	if hazard != null and hazard.has_method("get_hazard_tags"):
		var raw_tags: Variant = hazard.call("get_hazard_tags")
		if raw_tags is Array:
			for tag_variant: Variant in raw_tags:
				var tag: String = str(tag_variant)
				if tag != "" and not tags.has(tag):
					tags.append(tag)

	return tags


static func get_hazard_radius(hazard: Node, fallback: float) -> float:
	if hazard == null:
		return fallback

	var radius_value: Variant = hazard.get("radius")
	if radius_value == null:
		return fallback

	return max(float(radius_value), 0.1)


static func classify_tags(tags: Array[String]) -> String:
	if has_any_tag(tags, DANGER_TAGS):
		return "danger"
	if has_any_tag(tags, TRAP_TAGS):
		return "trap"
	if has_any_tag(tags, SLOW_TAGS):
		return "slow"

	return "neutral"


static func should_hesitate(behavior: String, inside: bool) -> bool:
	if not inside:
		return false

	return behavior == "slow" or behavior == "trap"


static func get_behavior_weight(behavior: String, inside: bool) -> float:
	var weight: float = 1.0

	match behavior:
		"danger":
			weight = 1.45
		"trap":
			weight = 1.05
		"slow":
			weight = 0.75
		_:
			weight = 0.5

	if inside:
		weight *= 1.7

	return weight


static func describe_hazard(tags: Array[String]) -> String:
	if has_any_tag(tags, ["poison", "gas", "cloud"]):
		return "Poison Bloom"
	if has_any_tag(tags, ["time", "slow", "tempo"]):
		return "Time Snare"
	if has_any_tag(tags, ["trap", "illusion", "dreams"]):
		return "Dream Trap"
	if has_any_tag(tags, ["fire", "flame", "burning", "explosion"]):
		return "burning hazard"

	return "hazard"


static func has_any_tag(tags: Array[String], tags_to_check: Array[String]) -> bool:
	for tag: String in tags_to_check:
		if tags.has(tag):
			return true

	return false
