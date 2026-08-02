extends RefCounted
class_name EngineeringBuildCatalog

const SELECTED_BUILD_FLAG: String = "__engineering_builds__::selected_build"

const BUILD_ORDER: Array[String] = [
	"bridge_frame",
	"launch_tower",
	"blast_cart",
	"conductive_raft",
]

const DEFINITIONS: Dictionary = {
	"bridge_frame": {
		"id": "bridge_frame",
		"item_id": "bridge_frame_blueprint",
		"family": "build",
		"display_name": "Bridge Frame",
		"short_name": "Bridge Frame",
		"icon": "▰",
		"description": "Two reproduced supports lock beneath a broad platform to create stable elevated footing across a short gap.",
		"behavior": "bridge_frame",
		"body_mode": "anchored",
		"size": Vector3(5.6, 1.75, 2.4),
		"mass": 24.0,
		"mana_cost": 4,
		"maximum_active": 2,
		"placement_range": 14.0,
		"color": Color(0.34, 0.68, 0.94, 1.0),
		"components": [
			{"blueprint_id": "crate", "item_id": "recorded_crate_blueprint", "label": "Recorded Crate"},
			{"blueprint_id": "platform", "item_id": "recorded_platform_blueprint", "label": "Recorded Platform"},
		],
		"test_prompt": "Bridge the construction-yard trench or create elevated footing.",
	},
	"launch_tower": {
		"id": "launch_tower",
		"item_id": "launch_tower_blueprint",
		"family": "build",
		"display_name": "Launch Tower",
		"short_name": "Launch Tower",
		"icon": "↟",
		"description": "A braced platform and spring assembly that provides a repeatable high launch and accepts Lightning overcharge.",
		"behavior": "launch_tower",
		"body_mode": "anchored",
		"size": Vector3(3.2, 3.25, 3.2),
		"mass": 28.0,
		"mana_cost": 6,
		"maximum_active": 1,
		"placement_range": 12.0,
		"launch_speed": 14.0,
		"color": Color(0.38, 0.94, 0.56, 1.0),
		"components": [
			{"blueprint_id": "crate", "item_id": "recorded_crate_blueprint", "label": "Recorded Crate"},
			{"blueprint_id": "platform", "item_id": "recorded_platform_blueprint", "label": "Recorded Platform"},
			{"blueprint_id": "spring", "item_id": "recorded_spring_blueprint", "label": "Recorded Spring"},
		],
		"test_prompt": "Reach the high shelf, then overcharge the launch with Lightning.",
	},
	"blast_cart": {
		"id": "blast_cart",
		"item_id": "blast_cart_blueprint",
		"family": "build",
		"display_name": "Blast Cart",
		"short_name": "Blast Cart",
		"icon": "✹",
		"description": "A movable reinforced crate chassis carrying a reproduced blast barrel for repositionable demolition.",
		"behavior": "blast_cart",
		"body_mode": "dynamic",
		"size": Vector3(2.5, 1.8, 1.8),
		"mass": 11.0,
		"mana_cost": 5,
		"maximum_active": 2,
		"placement_range": 12.0,
		"blast_radius": 6.0,
		"blast_damage": 5,
		"blast_force": 11.0,
		"color": Color(0.96, 0.34, 0.12, 1.0),
		"components": [
			{"blueprint_id": "crate", "item_id": "recorded_crate_blueprint", "label": "Recorded Crate"},
			{"blueprint_id": "blast_barrel", "item_id": "recorded_blast_barrel_blueprint", "label": "Recorded Blast Barrel"},
		],
		"test_prompt": "Push it into the target cluster, dampen it, or trigger a chain blast.",
	},
	"conductive_raft": {
		"id": "conductive_raft",
		"item_id": "conductive_raft_blueprint",
		"family": "build",
		"display_name": "Conductive Raft",
		"short_name": "Conductive Raft",
		"icon": "≈",
		"description": "A buoyant twin-pontoon platform that follows water flow and can carry a temporary electrical contact field.",
		"behavior": "conductive_raft",
		"body_mode": "dynamic",
		"size": Vector3(4.2, 1.15, 3.0),
		"mass": 13.0,
		"mana_cost": 6,
		"maximum_active": 1,
		"placement_range": 13.0,
		"color": Color(0.2, 0.76, 0.92, 1.0),
		"components": [
			{"blueprint_id": "crate", "item_id": "recorded_crate_blueprint", "label": "Recorded Crate"},
			{"blueprint_id": "platform", "item_id": "recorded_platform_blueprint", "label": "Recorded Platform"},
		],
		"test_prompt": "Launch it into water, ride the flow, and energize its deck.",
	},
}


static func has_build(build_id: String) -> bool:
	return DEFINITIONS.has(build_id)


static func get_definition(build_id: String) -> Dictionary:
	if not has_build(build_id):
		return {}
	return (DEFINITIONS[build_id] as Dictionary).duplicate(true)


static func get_definitions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for build_id: String in BUILD_ORDER:
		rows.append(get_definition(build_id))
	return rows


static func get_item_id(build_id: String) -> String:
	return str(get_definition(build_id).get("item_id", ""))


static func get_build_id_for_item(item_id: String) -> String:
	for build_id: String in BUILD_ORDER:
		if get_item_id(build_id) == item_id:
			return build_id
	return ""


static func is_saved(build_id: String) -> bool:
	var item_id: String = get_item_id(build_id)
	return item_id != "" and GameState.get_inventory_count(item_id) > 0


static func requirements_met(build_id: String) -> bool:
	return get_missing_requirements(build_id).is_empty()


static func get_missing_requirements(build_id: String) -> Array[String]:
	var missing: Array[String] = []
	var definition: Dictionary = get_definition(build_id)
	for raw_component: Variant in definition.get("components", []):
		if not raw_component is Dictionary:
			continue
		var component: Dictionary = raw_component as Dictionary
		var item_id: String = str(component.get("item_id", ""))
		if item_id == "" or GameState.get_inventory_count(item_id) <= 0:
			missing.append(str(component.get("label", item_id.replace("_", " ").capitalize())))
	return missing


static func save_build(build_id: String) -> Dictionary:
	var definition: Dictionary = get_definition(build_id)
	if definition.is_empty():
		return {"ok": false, "newly_saved": false, "error": "unknown build"}
	var missing: Array[String] = get_missing_requirements(build_id)
	if not missing.is_empty():
		return {
			"ok": false,
			"newly_saved": false,
			"error": "missing recorded components",
			"missing": missing,
		}
	var newly_saved: bool = not is_saved(build_id)
	if newly_saved:
		GameState.add_inventory_item(get_item_id(build_id), 1)
		_record_build_discovery(build_id, definition)
	select_build(build_id)
	return {
		"ok": true,
		"newly_saved": newly_saved,
		"build_id": build_id,
		"item_id": get_item_id(build_id),
		"definition": definition,
	}


static func select_build(build_id: String) -> bool:
	if not has_build(build_id) or not is_saved(build_id):
		return false
	GameState.story_flags[SELECTED_BUILD_FLAG] = build_id
	return true


static func get_selected_build_id() -> String:
	var selected: String = str(GameState.story_flags.get(SELECTED_BUILD_FLAG, ""))
	if selected != "" and is_saved(selected):
		return selected
	for build_id: String in BUILD_ORDER:
		if is_saved(build_id):
			return build_id
	return ""


static func get_saved_build_ids() -> Array[String]:
	var ids: Array[String] = []
	for build_id: String in BUILD_ORDER:
		if is_saved(build_id):
			ids.append(build_id)
	return ids


static func get_component_summary(build_id: String) -> String:
	var labels: Array[String] = []
	for raw_component: Variant in get_definition(build_id).get("components", []):
		if raw_component is Dictionary:
			labels.append(str((raw_component as Dictionary).get("label", "Component")))
	return " + ".join(labels)


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	var seen_items: Dictionary = {}
	for build_id: String in BUILD_ORDER:
		var definition: Dictionary = get_definition(build_id)
		if definition.is_empty():
			failures.append("missing engineering build: " + build_id)
			continue
		var item_id: String = str(definition.get("item_id", ""))
		if item_id == "":
			failures.append(build_id + " has no inventory item")
		elif seen_items.has(item_id):
			failures.append("duplicate engineering build item: " + item_id)
		seen_items[item_id] = true
		if str(definition.get("family", "")) != "build":
			failures.append(build_id + " is not classified as a build")
		var size_value: Variant = definition.get("size", Vector3.ZERO)
		if not size_value is Vector3 or (size_value as Vector3).length() <= 0.1:
			failures.append(build_id + " has invalid dimensions")
		if (definition.get("components", []) as Array).is_empty():
			failures.append(build_id + " has no component requirements")
		if int(definition.get("maximum_active", 0)) <= 0:
			failures.append(build_id + " needs an active limit")
	return failures


static func _record_build_discovery(
	build_id: String,
	definition: Dictionary
) -> void:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return
	var tree := main_loop as SceneTree
	var tracker: Node = tree.root.get_node_or_null(
		"FullMenuDirector/ProgressionTracker"
	)
	if tracker != null and tracker.has_method("record_discovery"):
		tracker.call(
			"record_discovery",
			"blueprint",
			build_id,
			{
				"source": "engineering_build",
				"display_name": str(definition.get("display_name", build_id.capitalize())),
				"components": get_component_summary(build_id),
			}
		)
