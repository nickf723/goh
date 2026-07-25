extends RefCounted

const SERVICE_PATH: NodePath = NodePath("/root/GameplayEffects")
const SERVICE_SCRIPT_PATH: String = "res://scripts/effects/gameplay_effect_service.gd"


static func get_service() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree: SceneTree = main_loop as SceneTree
	var existing: Node = tree.root.get_node_or_null(SERVICE_PATH)
	if existing != null:
		return existing
	var service_script: Script = load(SERVICE_SCRIPT_PATH) as Script
	if service_script == null:
		return null
	var service: Node = service_script.new() as Node
	if service == null:
		return null
	service.name = "GameplayEffects"
	tree.root.add_child(service)
	return service


static func modify_float(channel_id: String, base_value: float) -> float:
	var service: Node = get_service()
	if service == null or not service.has_method("modify_float"):
		return base_value
	return float(service.call("modify_float", channel_id, base_value))


static func modify_int(channel_id: String, base_value: int, rounding_mode: String = "round") -> int:
	var service: Node = get_service()
	if service == null or not service.has_method("modify_int"):
		return base_value
	return int(service.call("modify_int", channel_id, base_value, rounding_mode))


static func set_effect_source(source_id: String, effect_ids: Array[String], duration: float = -1.0, tags: Array[String] = []) -> void:
	var service: Node = get_service()
	if service != null and service.has_method("set_effect_source"):
		service.call("set_effect_source", source_id, effect_ids, duration, tags)


static func add_effect(source_id: String, effect_id: String, duration: float = -1.0, tags: Array[String] = []) -> void:
	var service: Node = get_service()
	if service != null and service.has_method("add_effect"):
		service.call("add_effect", source_id, effect_id, duration, tags)


static func remove_effect_source(source_id: String) -> void:
	var service: Node = get_service()
	if service != null and service.has_method("remove_effect_source"):
		service.call("remove_effect_source", source_id)


static func has_effect(effect_id: String) -> bool:
	var service: Node = get_service()
	return service != null and service.has_method("has_effect") and bool(service.call("has_effect", effect_id))


static func has_effect_with_tag(tag: String) -> bool:
	var service: Node = get_service()
	return service != null and service.has_method("has_effect_with_tag") and bool(service.call("has_effect_with_tag", tag))


static func remove_effects_with_tag(tag: String) -> int:
	var service: Node = get_service()
	if service == null or not service.has_method("remove_effects_with_tag"):
		return 0
	return int(service.call("remove_effects_with_tag", tag))


static func get_active_source_rows(include_permanent: bool = true) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var service: Node = get_service()
	if service == null or not service.has_method("get_active_source_rows"):
		return rows
	var result: Variant = service.call("get_active_source_rows", include_permanent)
	if not (result is Array):
		return rows
	var result_array: Array = result as Array
	for row_variant: Variant in result_array:
		if row_variant is Dictionary:
			rows.append((row_variant as Dictionary).duplicate(true))
	return rows


static func remove_sources_with_tag(tag: String) -> void:
	var service: Node = get_service()
	if service != null and service.has_method("remove_sources_with_tag"):
		service.call("remove_sources_with_tag", tag)
