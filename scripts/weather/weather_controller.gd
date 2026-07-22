extends Node3D
class_name WeatherController

signal weather_started(weather_id: String)
signal weather_stopped(weather_id: String)
signal weather_exposure_pulsed(target_count: int)

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var weather_definition: Resource
@export var concentration_manager_path: NodePath
@export var player_path: NodePath
@export var environment_path: NodePath
@export var show_messages: bool = true

var concentration_manager: Node = null
var player: Node3D = null
var active: bool = false
var exposure_timer: float = 0.0
var pulse_count: int = 0
var last_exposed_targets: Array[String] = []

var rain_visual_root: Node3D = null
var rain_drops: Array[MeshInstance3D] = []
var random := RandomNumberGenerator.new()

var world_environment: WorldEnvironment = null
var original_background_color: Color = Color.BLACK
var original_ambient_color: Color = Color.WHITE
var original_ambient_energy: float = 1.0
var original_fog_enabled: bool = false
var environment_snapshot_valid: bool = false


func _ready() -> void:
	add_to_group("weather_controller")
	add_to_group("weather_source")
	add_to_group("element_source")
	add_to_group("debuggable")
	random.seed = 7232026
	resolve_dependencies()
	create_rain_visuals()
	set_rain_visuals_visible(false)


func _process(delta: float) -> void:
	if not active:
		return

	update_rain_visuals(delta)
	exposure_timer -= delta
	if exposure_timer <= 0.0:
		exposure_timer = max(get_definition_float("exposure_interval", 0.6), 0.05)
		apply_weather_exposure()


func _exit_tree() -> void:
	if active:
		stop_weather(false)


func resolve_dependencies(source_player: Node3D = null) -> void:
	if source_player != null:
		player = source_player
	elif player == null and not player_path.is_empty():
		player = get_node_or_null(player_path) as Node3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D

	if concentration_manager == null and not concentration_manager_path.is_empty():
		concentration_manager = get_node_or_null(concentration_manager_path)
	if concentration_manager == null:
		concentration_manager = get_tree().get_first_node_in_group("concentration_manager")

	if world_environment == null and not environment_path.is_empty():
		world_environment = get_node_or_null(environment_path) as WorldEnvironment
	if world_environment == null:
		world_environment = find_world_environment(get_tree().current_scene)


func toggle_weather(weather_id: String = "rain", source_player: Node3D = null) -> bool:
	if weather_definition == null:
		show_message("No weather definition is assigned.")
		return false

	var definition_id: String = str(weather_definition.get("effect_id"))
	var definition_kind: String = str(weather_definition.get("weather_kind"))
	if weather_id != "" and weather_id not in [definition_id, definition_kind]:
		return false

	if active:
		stop_weather()
		return false

	return start_weather(source_player)


func start_weather(source_player: Node3D = null) -> bool:
	resolve_dependencies(source_player)
	if weather_definition == null or concentration_manager == null:
		show_message("Rain cannot form without a weather definition and concentration manager.")
		return false

	var ability_caster: Node = null
	if player != null:
		ability_caster = player.get_node_or_null("AbilityCaster")

	if not concentration_manager.has_method("activate_effect"):
		return false
	if not bool(concentration_manager.call("activate_effect", weather_definition, ability_caster)):
		return false

	active = true
	exposure_timer = 0.0
	pulse_count = 0
	last_exposed_targets.clear()
	set_rain_visuals_visible(true)
	apply_weather_environment()
	reset_all_drops()
	weather_started.emit(get_weather_id())

	if show_messages:
		show_message("Rain answers Grace's concentration. Water spells now draw from the sky.")
	return true


func stop_weather(show_feedback: bool = true) -> void:
	if not active:
		return

	active = false
	set_rain_visuals_visible(false)
	restore_weather_environment()
	if concentration_manager != null and concentration_manager.has_method("deactivate_effect"):
		concentration_manager.call("deactivate_effect", show_feedback)
	weather_stopped.emit(get_weather_id())

	if show_feedback and show_messages:
		show_message("The rainfall thins and the reserved mana ceiling is released.")


func request_element_units(element: String, requested_units: float) -> float:
	if not active or weather_definition == null or requested_units <= 0.0:
		return 0.0
	if weather_definition.has_method("request_element_units"):
		return float(weather_definition.call("request_element_units", element, requested_units))
	var generated_value: Variant = weather_definition.get("generated_elements")
	if generated_value is Array and (generated_value as Array).has(element.to_lower().strip_edges()):
		return requested_units
	return 0.0


func is_generating_element(element: String) -> bool:
	return request_element_units(element, 1.0) >= 1.0


func create_rain_visuals() -> void:
	if rain_visual_root != null:
		return

	rain_visual_root = Node3D.new()
	rain_visual_root.name = "RainVisualRoot"
	add_child(rain_visual_root)

	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(0.026, 0.52, 0.026)
	var drop_material: StandardMaterial3D = ElementVisuals.make_material(
		Color(0.48, 0.78, 1.0, 1.0),
		1.45,
		0.55,
		true
	)

	var drop_count: int = int(get_definition_float("rain_drop_count", 84.0))
	for index: int in range(max(drop_count, 8)):
		var drop := MeshInstance3D.new()
		drop.name = "RainDrop" + str(index)
		drop.mesh = drop_mesh
		drop.material_override = drop_material
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rain_visual_root.add_child(drop)
		rain_drops.append(drop)


func set_rain_visuals_visible(visible_value: bool) -> void:
	if rain_visual_root != null:
		rain_visual_root.visible = visible_value


func reset_all_drops() -> void:
	for drop: MeshInstance3D in rain_drops:
		reset_drop(drop, true)


func reset_drop(drop: MeshInstance3D, randomize_height: bool = false) -> void:
	if drop == null:
		return
	var center: Vector3 = player.global_position if player != null else global_position
	var radius: float = max(get_definition_float("rain_radius", 10.0), 1.0)
	var height: float = max(get_definition_float("rain_height", 8.0), 2.0)
	var angle: float = random.randf_range(0.0, TAU)
	var radial_distance: float = sqrt(random.randf()) * radius
	var y_offset: float = random.randf_range(0.5, height) if randomize_height else height
	drop.global_position = center + Vector3(
		cos(angle) * radial_distance,
		y_offset,
		sin(angle) * radial_distance
	)


func update_rain_visuals(delta: float) -> void:
	if player == null:
		resolve_dependencies()
	var center: Vector3 = player.global_position if player != null else global_position
	var radius: float = max(get_definition_float("rain_radius", 10.0), 1.0)
	var fall_speed: float = max(get_definition_float("fall_speed", 18.0), 1.0)
	var wind: Vector3 = get_definition_vector("wind_velocity", Vector3.ZERO)
	var velocity: Vector3 = wind + Vector3.DOWN * fall_speed

	for drop: MeshInstance3D in rain_drops:
		if drop == null or not is_instance_valid(drop):
			continue
		drop.global_position += velocity * max(delta, 0.0)
		var horizontal_offset := Vector2(
			drop.global_position.x - center.x,
			drop.global_position.z - center.z
		)
		if drop.global_position.y < center.y - 1.2 or horizontal_offset.length() > radius * 1.25:
			reset_drop(drop)


func apply_weather_exposure() -> void:
	var payload := DamagePayload.new()
	payload.amount = 0
	payload.stance_damage = 0
	payload.element = "water"
	payload.source_name = str(weather_definition.get("display_name")) if weather_definition != null else "Rain"
	payload.hit_type = "weather"
	payload.status_effect = "wet"
	payload.status_duration = get_definition_float("status_duration", 3.0)
	payload.status_strength = get_definition_float("exposure_strength", 1.0)
	payload.tags = get_weather_tags()

	last_exposed_targets.clear()
	var seen_ids: Dictionary = {}
	for target: Node in get_tree().get_nodes_in_group("weather_exposed"):
		if target == null or not is_instance_valid(target):
			continue
		var target_id: int = target.get_instance_id()
		if seen_ids.has(target_id):
			continue
		seen_ids[target_id] = true
		if deliver_weather_payload(target, payload):
			last_exposed_targets.append(target.name)

	pulse_count += 1
	weather_exposure_pulsed.emit(last_exposed_targets.size())


func deliver_weather_payload(target: Node, payload: DamagePayload) -> bool:
	var delivered: bool = false

	if target.has_method("receive_weather_payload"):
		target.call("receive_weather_payload", payload)
		delivered = true
	elif target.has_method("receive_damage_payload"):
		target.call("receive_damage_payload", payload)
		delivered = true
	else:
		var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
		if payload_receiver != null and payload_receiver.has_method("receive_payload"):
			payload_receiver.call("receive_payload", payload)
			delivered = true

	var combustion_state: Node = target.get_node_or_null("CombustionState")
	if combustion_state != null and combustion_state.has_method("receive_damage_payload"):
		combustion_state.call("receive_damage_payload", payload)
		delivered = true

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	if status_receiver != null:
		if status_receiver.has_method("sustain_status"):
			status_receiver.call(
				"/root/placeholder" if false else "sustain_status",
				"wet",
				payload.status_duration,
				payload.status_strength,
				payload.source_name
			)
			delivered = true
		elif status_receiver.has_method("apply_status"):
			status_receiver.call(
				"apply_status",
				"wet",
				payload.status_duration,
				payload.status_strength,
				payload.source_name
			)
			delivered = true

	return delivered


func get_weather_tags() -> Array[String]:
	var tags: Array[String] = ["rain", "water", "wet", "weather", "environment", "element_source"]
	if weather_definition == null:
		return tags
	var authored_tags: Variant = weather_definition.get("weather_tags")
	if authored_tags is Array:
		for raw_tag: Variant in authored_tags as Array:
			var tag: String = str(raw_tag)
			if tag != "" and not tags.has(tag):
				tags.append(tag)
	return tags


func apply_weather_environment() -> void:
	resolve_dependencies()
	if world_environment == null or world_environment.environment == null:
		return
	var environment: Environment = world_environment.environment
	if not environment_snapshot_valid:
		original_background_color = environment.background_color
		original_ambient_color = environment.ambient_light_color
		original_ambient_energy = environment.ambient_light_energy
		original_fog_enabled = environment.fog_enabled
		environment_snapshot_valid = true

	environment.background_color = Color(0.075, 0.11, 0.16, 1.0)
	environment.ambient_light_color = Color(0.35, 0.48, 0.62, 1.0)
	environment.ambient_light_energy = 0.62
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.28, 0.36, 0.46, 1.0)
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.012


func restore_weather_environment() -> void:
	if not environment_snapshot_valid or world_environment == null or world_environment.environment == null:
		return
	var environment: Environment = world_environment.environment
	environment.background_color = original_background_color
	environment.ambient_light_color = original_ambient_color
	environment.ambient_light_energy = original_ambient_energy
	environment.fog_enabled = original_fog_enabled


func find_world_environment(root: Node) -> WorldEnvironment:
	if root == null:
		return null
	if root is WorldEnvironment:
		return root as WorldEnvironment
	for child: Node in root.get_children():
		var found: WorldEnvironment = find_world_environment(child)
		if found != null:
			return found
	return null


func get_weather_id() -> String:
	return str(weather_definition.get("effect_id")) if weather_definition != null else "weather"


func get_definition_float(field_name: String, fallback: float) -> float:
	if weather_definition == null:
		return fallback
	var value: Variant = weather_definition.get(field_name)
	return fallback if value == null else float(value)


func get_definition_vector(field_name: String, fallback: Vector3) -> Vector3:
	if weather_definition == null:
		return fallback
	var value: Variant = weather_definition.get(field_name)
	return value as Vector3 if value is Vector3 else fallback


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"weather_active": active,
		"weather_id": get_weather_id(),
		"infinite_water": is_generating_element("water"),
		"exposure_pulses": pulse_count,
		"last_exposed_targets": last_exposed_targets,
		"rain_drops": rain_drops.size(),
	}
