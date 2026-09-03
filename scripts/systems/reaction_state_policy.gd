extends RefCounted
class_name ReactionStatePolicy


const STATUS_ALIASES: Dictionary = {
	"chilled": "chill",
	"freeze": "frozen",
	"electrified": "electrified",
	"conducting": "conductive",
	"obscure": "obscured",
	"steam": "steamed",
}

const STATUS_ELEMENTS: Dictionary = {
	"burning": "fire",
	"scorched": "fire",
	"poisoned": "poison",
	"toxic": "poison",
	"wet": "water",
	"steamed": "water",
	"frozen": "ice",
	"chill": "ice",
	"brittle": "ice",
	"stunned": "lightning",
	"electrified": "lightning",
	"conductive": "lightning",
	"leaf_pelted": "life",
	"rooted": "life",
	"hexed": "death",
	"stasis": "time",
	"oily": "neutral",
	"obscured": "neutral",
	"revealed": "sound",
}

# These are state-level incompatibilities, not reactions. Reactions are resolved
# before a new direct status is applied, so these rules only keep the resulting
# state set coherent after the chemistry transaction has finished.
#
# Fire and ice states (burning <-> frozen) are deliberately NOT listed as mutual
# conflicts: their interaction is owned by the reaction rules (wet_freeze,
# frozen_shatter, and the fire_x_frozen Steam Burst), which need a target to hold
# both frozen and burning for one transaction so Steam Burst can consume each.
const STATUS_CONFLICTS: Dictionary = {
	"wet": ["oily", "burning"],
	"burning": ["chill", "wet", "steamed"],
	"frozen": ["chill", "steamed"],
	"steamed": ["frozen", "burning", "chill", "wet"],
	"revealed": ["obscured"],
}


static func normalize_state(state_name: String) -> String:
	var normalized: String = state_name.strip_edges().to_lower()
	return str(STATUS_ALIASES.get(normalized, normalized))


static func get_state_element(state_name: String) -> String:
	return str(STATUS_ELEMENTS.get(normalize_state(state_name), "neutral"))


static func get_conflicts_for(state_name: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = STATUS_CONFLICTS.get(normalize_state(state_name), [])
	if raw is Array:
		for value: Variant in raw as Array:
			var normalized: String = normalize_state(str(value))
			if normalized != "" and not result.has(normalized):
				result.append(normalized)
	return result


static func resolve_conflicts(receiver: Node, incoming_state: String) -> Array[String]:
	var removed: Array[String] = []
	if receiver == null or not receiver.has_method("remove_status"):
		return removed
	for conflict: String in get_conflicts_for(incoming_state):
		if receiver.has_method("has_status") and not bool(receiver.call("has_status", conflict)):
			continue
		receiver.call("remove_status", conflict)
		removed.append(conflict)
	return removed


static func capture_target_state(target: Node) -> Dictionary:
	var statuses: Array[String] = []
	var tags: Array[String] = []
	if target == null:
		return {"statuses": statuses, "tags": tags}

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	if status_receiver != null:
		var active_value: Variant = status_receiver.get("active_statuses")
		if active_value is Dictionary:
			for key: Variant in (active_value as Dictionary).keys():
				_append_unique(statuses, normalize_state(str(key)))
		elif status_receiver.has_method("get_active_status_names"):
			var names_value: Variant = status_receiver.call("get_active_status_names")
			if names_value is Array:
				for name_value: Variant in names_value as Array:
					_append_unique(statuses, normalize_state(str(name_value)))

	var tag_component: Node = target.get_node_or_null("TagComponent")
	if tag_component != null:
		var tag_value: Variant = tag_component.get("tags")
		if tag_value is Array:
			for raw_tag: Variant in tag_value as Array:
				_append_unique(tags, str(raw_tag).strip_edges().to_lower())
		elif tag_component.has_method("get_tags"):
			var tags_result: Variant = tag_component.call("get_tags")
			if tags_result is Array:
				for raw_tag: Variant in tags_result as Array:
					_append_unique(tags, str(raw_tag).strip_edges().to_lower())

	if target.has_method("get_hazard_tags"):
		var hazard_tags: Variant = target.call("get_hazard_tags")
		if hazard_tags is Array:
			for raw_tag: Variant in hazard_tags as Array:
				_append_unique(tags, str(raw_tag).strip_edges().to_lower())

	for status_name: String in statuses:
		_append_unique(tags, status_name)
	return {
		"statuses": statuses,
		"tags": tags,
	}


static func snapshot_has_status(snapshot: Dictionary, state_name: String) -> bool:
	var normalized: String = normalize_state(state_name)
	var values: Variant = snapshot.get("statuses", [])
	return values is Array and (values as Array).has(normalized)


static func snapshot_has_tag_or_status(snapshot: Dictionary, value: String) -> bool:
	var normalized: String = normalize_state(value)
	var tags: Variant = snapshot.get("tags", [])
	if tags is Array and (tags as Array).has(normalized):
		return true
	return snapshot_has_status(snapshot, normalized)


static func _append_unique(target: Array[String], value: String) -> void:
	if value == "" or target.has(value):
		return
	target.append(value)
