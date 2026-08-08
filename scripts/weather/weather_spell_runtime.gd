extends RefCounted
class_name WeatherSpellRuntime

const ConcentrationRuntime = preload(
	"res://scripts/concentration/concentration_runtime_access.gd"
)
const RainControllerScript = preload(
	"res://scripts/weather/weather_controller_concentration_budget.gd"
)
const SnowControllerScript = preload(
	"res://scripts/weather/snow_weather_controller_concentration_budget.gd"
)
const ThunderstormControllerScript = preload(
	"res://scripts/weather/thunderstorm_weather_controller_concentration_budget.gd"
)
const RainDefinition: Resource = preload(
	"res://data/weather/rain_weather.tres"
)
const SnowDefinition: Resource = preload(
	"res://data/weather/snow_weather.tres"
)
const ThunderstormDefinition: Resource = preload(
	"res://data/weather/thunderstorm_weather.tres"
)


static func resolve_or_create(
	tree: SceneTree,
	weather_kind: String,
	player: Node3D = null
) -> Node:
	if tree == null:
		return null
	var normalized: String = _normalize_kind(weather_kind)
	var authored: Node = _find_controller(tree, normalized)
	if authored != null:
		_release_other_runtime_controllers(tree, normalized)
		return authored

	var manager: Node = ConcentrationRuntime.ensure_manager(tree, player)
	if manager == null:
		return null
	_release_other_runtime_controllers(tree, normalized)

	var parent: Node = tree.current_scene
	if parent == null and player != null:
		parent = player.get_parent()
	if parent == null:
		parent = tree.root
	if parent == null:
		return null

	var controller: Node = _make_controller(normalized)
	var definition: Resource = _get_definition(normalized)
	if controller == null or definition == null:
		return null
	controller.name = _get_controller_name(normalized)
	controller.set("weather_definition", definition)
	controller.set("show_messages", true)
	controller.set_meta("runtime_weather_controller", true)
	controller.set_meta("runtime_weather_kind", normalized)
	controller.set_meta("concentration_budget_aware", true)
	parent.add_child(controller)
	controller.add_to_group("runtime_weather_controller")
	if controller.has_method("resolve_dependencies"):
		controller.call("resolve_dependencies", player)
	return controller


static func _find_controller(tree: SceneTree, weather_kind: String) -> Node:
	for candidate: Node in tree.get_nodes_in_group("weather_controller"):
		if (
			candidate == null
			or not is_instance_valid(candidate)
			or candidate.is_queued_for_deletion()
		):
			continue
		if _get_controller_kind(candidate) == weather_kind:
			return candidate
	return null


static func _release_other_runtime_controllers(
	tree: SceneTree,
	incoming_kind: String
) -> void:
	for candidate: Node in tree.get_nodes_in_group("runtime_weather_controller"):
		if (
			candidate == null
			or not is_instance_valid(candidate)
			or candidate.is_queued_for_deletion()
		):
			continue
		if _get_controller_kind(candidate) == incoming_kind:
			continue
		if candidate.has_method("stop_weather"):
			candidate.call("stop_weather", false)
		candidate.queue_free()


static func _get_controller_kind(controller: Node) -> String:
	if controller == null:
		return ""
	var meta_kind: String = _normalize_kind(str(
		controller.get_meta("runtime_weather_kind", "")
	))
	if meta_kind != "":
		return meta_kind
	var definition: Variant = controller.get("weather_definition")
	if definition == null:
		return ""
	var kind: String = _normalize_kind(str(definition.get("weather_kind")))
	if kind != "":
		return kind
	var effect_id: String = str(
		definition.get("effect_id")
	).strip_edges().to_lower()
	return _normalize_kind(effect_id.replace("_weather", ""))


static func _normalize_kind(weather_kind: String) -> String:
	var normalized: String = weather_kind.strip_edges().to_lower()
	match normalized:
		"snowfall":
			return "snow"
		"storm":
			return "thunderstorm"
		_:
			return normalized


static func _make_controller(weather_kind: String) -> Node:
	match _normalize_kind(weather_kind):
		"rain":
			return RainControllerScript.new()
		"snow":
			return SnowControllerScript.new()
		"thunderstorm":
			return ThunderstormControllerScript.new()
		_:
			return null


static func _get_definition(weather_kind: String) -> Resource:
	match _normalize_kind(weather_kind):
		"rain":
			return RainDefinition
		"snow":
			return SnowDefinition
		"thunderstorm":
			return ThunderstormDefinition
		_:
			return null


static func _get_controller_name(weather_kind: String) -> String:
	match _normalize_kind(weather_kind):
		"rain":
			return "RuntimeRainWeatherController"
		"snow":
			return "RuntimeSnowWeatherController"
		"thunderstorm":
			return "RuntimeThunderstormWeatherController"
		_:
			return "RuntimeWeatherController"


static func get_debug_data(tree: SceneTree) -> Dictionary:
	var kinds: Array[String] = []
	if tree != null:
		for controller: Node in tree.get_nodes_in_group("weather_controller"):
			if (
				controller == null
				or not is_instance_valid(controller)
				or controller.is_queued_for_deletion()
			):
				continue
			var kind: String = _get_controller_kind(controller)
			if kind != "" and not kinds.has(kind):
				kinds.append(kind)
	return {
		"weather_runtime": true,
		"controller_kinds": kinds,
		"runtime_controller_count": (
			tree.get_node_count_in_group("runtime_weather_controller")
			if tree != null
			else 0
		),
		"concentration_budget_aware": true,
	}
