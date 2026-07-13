extends RefCounted
class_name FeatureRegistry

const REGISTRY_PATH: String = "res://data/features/feature_registry.json"
const ALLOWED_STATUSES: Array[String] = [
	"vertical_slice",
	"prototype_verified",
	"development_tool",
	"infrastructure",
	"experimental",
	"disabled",
]
const ALLOWED_TEMPORARY_STATES: Array[String] = [
	"none",
	"runtime_only",
	"persistent",
	"mixed",
]
const REQUIRED_FIELDS: Array[String] = [
	"id",
	"order",
	"display_name",
	"category",
	"version",
	"status",
	"description",
	"scene",
	"validation_scenes",
	"automated_tests",
	"dependencies",
	"controls",
	"manual_test",
	"temporary_state",
	"story_integrated",
	"limitations",
	"launchable",
	"visible_in_launcher",
	"ci_validate",
	"timeout_seconds",
]


static func load_registry(path: String = REGISTRY_PATH) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"schema_version": 0,
		"features": [],
		"errors": [],
		"feature_errors": {},
	}

	if not FileAccess.file_exists(path):
		result["errors"] = ["Registry file is missing: " + path]
		return result

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result["errors"] = ["Registry file could not be opened: " + path]
		return result

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	if parse_error != OK:
		result["errors"] = [
			"Registry JSON parse error at line "
			+ str(parser.get_error_line())
			+ ": "
			+ parser.get_error_message()
		]
		return result

	if not parser.data is Dictionary:
		result["errors"] = ["Registry root must be a Dictionary."]
		return result

	var registry: Dictionary = parser.data as Dictionary
	var validation: Dictionary = validate_registry_data(registry)
	result["schema_version"] = int(registry.get("schema_version", 0))
	result["features"] = registry.get("features", [])
	result["errors"] = validation.get("errors", [])
	result["feature_errors"] = validation.get("feature_errors", {})
	result["ok"] = (result["errors"] as Array).is_empty()
	return result


static func get_features(include_hidden: bool = true) -> Array[Dictionary]:
	var registry: Dictionary = load_registry()
	var features: Array[Dictionary] = []
	var raw_features: Variant = registry.get("features", [])

	if not raw_features is Array:
		return features

	for raw_feature: Variant in raw_features as Array:
		if not raw_feature is Dictionary:
			continue

		var feature: Dictionary = (raw_feature as Dictionary).duplicate(true)
		if not include_hidden and not bool(feature.get("visible_in_launcher", false)):
			continue
		features.append(feature)

	features.sort_custom(_compare_feature_order)
	return features


static func get_visible_features() -> Array[Dictionary]:
	return get_features(false)


static func get_feature_by_id(feature_id: String) -> Dictionary:
	for feature: Dictionary in get_features(true):
		if str(feature.get("id", "")) == feature_id:
			return feature
	return {}


static func get_feature_errors(feature_id: String, registry_result: Dictionary = {}) -> Array[String]:
	var resolved_registry: Dictionary = registry_result
	if resolved_registry.is_empty():
		resolved_registry = load_registry()

	var all_feature_errors: Variant = resolved_registry.get("feature_errors", {})
	if not all_feature_errors is Dictionary:
		return []

	var errors_by_id: Dictionary = all_feature_errors as Dictionary
	var raw_errors: Variant = errors_by_id.get(feature_id, [])
	var errors: Array[String] = []

	if raw_errors is Array:
		for raw_error: Variant in raw_errors as Array:
			errors.append(str(raw_error))

	return errors


static func get_health_summary(registry_result: Dictionary = {}) -> String:
	var resolved_registry: Dictionary = registry_result
	if resolved_registry.is_empty():
		resolved_registry = load_registry()

	var raw_features: Variant = resolved_registry.get("features", [])
	var feature_count: int = (raw_features as Array).size() if raw_features is Array else 0
	var raw_errors: Variant = resolved_registry.get("errors", [])
	var error_count: int = (raw_errors as Array).size() if raw_errors is Array else 0

	if bool(resolved_registry.get("ok", false)):
		return "REGISTRY HEALTHY • " + str(feature_count) + " FEATURES • 0 ERRORS"

	return "REGISTRY DEGRADED • " + str(feature_count) + " FEATURES • " + str(error_count) + " ERRORS"


static func validate_registry_data(registry: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var feature_errors: Dictionary = {}
	var raw_features: Variant = registry.get("features", null)

	if int(registry.get("schema_version", 0)) <= 0:
		errors.append("schema_version must be a positive integer.")

	if not raw_features is Array:
		errors.append("features must be an Array.")
		return {
			"errors": errors,
			"feature_errors": feature_errors,
		}

	var features: Array = raw_features as Array
	if features.is_empty():
		errors.append("features must not be empty.")
		return {
			"errors": errors,
			"feature_errors": feature_errors,
		}

	var id_lookup: Dictionary = {}
	var order_lookup: Dictionary = {}

	for index: int in range(features.size()):
		var raw_feature: Variant = features[index]
		if not raw_feature is Dictionary:
			errors.append("Feature at index " + str(index) + " must be a Dictionary.")
			continue

		var feature: Dictionary = raw_feature as Dictionary
		var feature_id: String = str(feature.get("id", "")).strip_edges()
		var local_errors: Array[String] = []

		for field_name: String in REQUIRED_FIELDS:
			if not feature.has(field_name):
				local_errors.append("Missing required field: " + field_name)

		if feature_id == "":
			local_errors.append("Feature id must not be empty.")
			feature_id = "index_" + str(index)
		elif id_lookup.has(feature_id):
			local_errors.append("Duplicate feature id: " + feature_id)
		else:
			id_lookup[feature_id] = feature

		var order_value: int = int(feature.get("order", -1))
		if order_value < 0:
			local_errors.append("order must be zero or greater.")
		elif order_lookup.has(order_value):
			local_errors.append("Duplicate registry order: " + str(order_value))
		else:
			order_lookup[order_value] = feature_id

		var status: String = str(feature.get("status", ""))
		if not ALLOWED_STATUSES.has(status):
			local_errors.append("Unsupported status: " + status)

		var temporary_state: String = str(feature.get("temporary_state", ""))
		if not ALLOWED_TEMPORARY_STATES.has(temporary_state):
			local_errors.append("Unsupported temporary_state: " + temporary_state)

		if bool(feature.get("visible_in_launcher", false)) and not bool(feature.get("launchable", false)):
			local_errors.append("Visible launcher entries must be launchable.")

		if int(feature.get("timeout_seconds", 0)) <= 0:
			local_errors.append("timeout_seconds must be positive.")

		validate_path_field(feature, "scene", true, local_errors)
		validate_path_array(feature, "validation_scenes", true, local_errors)
		validate_path_array(feature, "automated_tests", true, local_errors)
		validate_path_field(feature, "manual_test", false, local_errors)
		validate_string_array(feature, "dependencies", local_errors)
		validate_string_array(feature, "controls", local_errors)
		validate_string_array(feature, "limitations", local_errors)

		feature_errors[feature_id] = local_errors
		for local_error: String in local_errors:
			errors.append(feature_id + ": " + local_error)

	validate_dependencies(id_lookup, feature_errors, errors)
	validate_dependency_cycles(id_lookup, errors)

	return {
		"errors": errors,
		"feature_errors": feature_errors,
	}


static func validate_dependencies(id_lookup: Dictionary, feature_errors: Dictionary, errors: Array[String]) -> void:
	for feature_id: Variant in id_lookup.keys():
		var feature: Dictionary = id_lookup[feature_id] as Dictionary
		var raw_dependencies: Variant = feature.get("dependencies", [])
		if not raw_dependencies is Array:
			continue

		for raw_dependency: Variant in raw_dependencies as Array:
			var dependency_id: String = str(raw_dependency)
			if dependency_id == str(feature_id):
				append_feature_error(str(feature_id), "Feature cannot depend on itself.", feature_errors, errors)
			elif not id_lookup.has(dependency_id):
				append_feature_error(
					str(feature_id),
					"Unknown dependency: " + dependency_id,
					feature_errors,
					errors
				)


static func validate_dependency_cycles(id_lookup: Dictionary, errors: Array[String]) -> void:
	var indegree: Dictionary = {}
	var dependents: Dictionary = {}

	for feature_id: Variant in id_lookup.keys():
		indegree[feature_id] = 0
		dependents[feature_id] = []

	for feature_id: Variant in id_lookup.keys():
		var feature: Dictionary = id_lookup[feature_id] as Dictionary
		var raw_dependencies: Variant = feature.get("dependencies", [])
		if not raw_dependencies is Array:
			continue

		for raw_dependency: Variant in raw_dependencies as Array:
			var dependency_id: String = str(raw_dependency)
			if not id_lookup.has(dependency_id) or dependency_id == str(feature_id):
				continue
			indegree[feature_id] = int(indegree.get(feature_id, 0)) + 1
			var dependency_dependents: Array = dependents.get(dependency_id, [])
			dependency_dependents.append(str(feature_id))
			dependents[dependency_id] = dependency_dependents

	var queue: Array[String] = []
	for feature_id: Variant in indegree.keys():
		if int(indegree[feature_id]) == 0:
			queue.append(str(feature_id))

	var processed_count: int = 0
	while not queue.is_empty():
		var current_id: String = queue.pop_front()
		processed_count += 1
		var raw_dependents: Variant = dependents.get(current_id, [])
		if not raw_dependents is Array:
			continue
		for raw_dependent: Variant in raw_dependents as Array:
			var dependent_id: String = str(raw_dependent)
			indegree[dependent_id] = int(indegree.get(dependent_id, 0)) - 1
			if int(indegree[dependent_id]) == 0:
				queue.append(dependent_id)

	if processed_count != id_lookup.size():
		errors.append("Feature dependency graph contains a cycle.")


static func validate_path_field(
	feature: Dictionary,
	field_name: String,
	require_resource_path: bool,
	local_errors: Array[String]
) -> void:
	var path: String = str(feature.get(field_name, "")).strip_edges()
	if path == "":
		local_errors.append(field_name + " must not be empty.")
		return

	if require_resource_path and not path.begins_with("res://"):
		local_errors.append(field_name + " must use a res:// path: " + path)
		return

	if not registered_path_exists(path):
		local_errors.append(field_name + " does not exist: " + path)


static func validate_path_array(
	feature: Dictionary,
	field_name: String,
	require_resource_path: bool,
	local_errors: Array[String]
) -> void:
	var raw_paths: Variant = feature.get(field_name, null)
	if not raw_paths is Array:
		local_errors.append(field_name + " must be an Array.")
		return

	var seen_paths: Dictionary = {}
	for raw_path: Variant in raw_paths as Array:
		var path: String = str(raw_path).strip_edges()
		if path == "":
			local_errors.append(field_name + " contains an empty path.")
			continue
		if seen_paths.has(path):
			local_errors.append(field_name + " contains a duplicate path: " + path)
			continue
		seen_paths[path] = true
		if require_resource_path and not path.begins_with("res://"):
			local_errors.append(field_name + " must use res:// paths: " + path)
			continue
		if not registered_path_exists(path):
			local_errors.append(field_name + " path does not exist: " + path)


static func validate_string_array(
	feature: Dictionary,
	field_name: String,
	local_errors: Array[String]
) -> void:
	var raw_values: Variant = feature.get(field_name, null)
	if not raw_values is Array:
		local_errors.append(field_name + " must be an Array.")
		return

	var seen_values: Dictionary = {}
	for raw_value: Variant in raw_values as Array:
		var value: String = str(raw_value).strip_edges()
		if value == "":
			local_errors.append(field_name + " contains an empty value.")
			continue
		if seen_values.has(value):
			local_errors.append(field_name + " contains a duplicate value: " + value)
			continue
		seen_values[value] = true


static func registered_path_exists(path: String) -> bool:
	var resolved_path: String = normalize_project_path(path)
	if resolved_path.ends_with(".tscn") or resolved_path.ends_with(".tres") or resolved_path.ends_with(".res"):
		return ResourceLoader.exists(resolved_path)
	return FileAccess.file_exists(resolved_path)


static func normalize_project_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	return "res://" + path.trim_prefix("/")


static func append_feature_error(
	feature_id: String,
	message: String,
	feature_errors: Dictionary,
	errors: Array[String]
) -> void:
	var local_errors: Array = feature_errors.get(feature_id, [])
	local_errors.append(message)
	feature_errors[feature_id] = local_errors
	errors.append(feature_id + ": " + message)


static func _compare_feature_order(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("order", 0))
	var order_b: int = int(b.get("order", 0))
	if order_a == order_b:
		return str(a.get("id", "")) < str(b.get("id", ""))
	return order_a < order_b
