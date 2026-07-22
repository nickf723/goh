extends "res://scripts/weather/weather_controller.gd"
class_name SnowWeatherController

const SnowElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

var snow_elapsed: float = 0.0


func start_weather(source_player: Node3D = null) -> bool:
	resolve_dependencies(source_player)
	if weather_definition == null or concentration_manager == null:
		show_message("Snowfall cannot form without a weather definition and concentration manager.")
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
	snow_elapsed = 0.0
	last_exposed_targets.clear()
	set_rain_visuals_visible(true)
	apply_weather_environment()
	reset_all_drops()
	weather_started.emit(get_weather_id())

	if show_messages:
		show_message("Snowfall answers Grace's concentration. Ice spells now draw from the frozen sky.")
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
		show_message("The snowfall thins and the reserved mana ceiling is released.")


func create_rain_visuals() -> void:
	if rain_visual_root != null:
		return

	rain_visual_root = Node3D.new()
	rain_visual_root.name = "SnowVisualRoot"
	add_child(rain_visual_root)

	var flake_mesh := SphereMesh.new()
	flake_mesh.radius = 0.035
	flake_mesh.height = 0.07
	flake_mesh.radial_segments = 6
	flake_mesh.rings = 3
	var flake_material: StandardMaterial3D = SnowElementVisuals.make_material(
		Color(0.86, 0.96, 1.0, 1.0),
		1.55,
		0.78,
		true
	)

	var flake_count: int = int(get_definition_float("snowflake_count", 108.0))
	for index: int in range(max(flake_count, 8)):
		var flake := MeshInstance3D.new()
		flake.name = "Snowflake" + str(index)
		flake.mesh = flake_mesh
		flake.material_override = flake_material
		flake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var scale_factor: float = random.randf_range(0.65, 1.55)
		flake.scale = Vector3(scale_factor, scale_factor * random.randf_range(0.45, 0.9), scale_factor)
		rain_visual_root.add_child(flake)
		rain_drops.append(flake)


func reset_drop(drop: MeshInstance3D, randomize_height: bool = false) -> void:
	if drop == null:
		return
	if player == null:
		resolve_dependencies()
	var center: Vector3 = player.global_position if player != null else global_position
	var radius: float = max(get_definition_float("snow_radius", 10.0), 1.0)
	var height: float = max(get_definition_float("snow_height", 8.5), 2.0)
	var angle: float = random.randf_range(0.0, TAU)
	var radial_distance: float = sqrt(random.randf()) * radius
	var y_offset: float = random.randf_range(0.5, height) if randomize_height else height
	drop.global_position = center + Vector3(
		cos(angle) * radial_distance,
		y_offset,
		sin(angle) * radial_distance
	)
	drop.rotation = Vector3(
		random.randf_range(-PI, PI),
		random.randf_range(-PI, PI),
		random.randf_range(-PI, PI)
	)


func update_rain_visuals(delta: float) -> void:
	if player == null:
		resolve_dependencies()
	var center: Vector3 = player.global_position if player != null else global_position
	var radius: float = max(get_definition_float("snow_radius", 10.0), 1.0)
	var fall_speed: float = max(get_definition_float("snow_fall_speed", 4.5), 0.5)
	var sway_strength: float = max(get_definition_float("snow_sway_strength", 0.8), 0.0)
	var wind: Vector3 = get_definition_vector("wind_velocity", Vector3.ZERO)
	snow_elapsed += max(delta, 0.0)

	for index: int in range(rain_drops.size()):
		var drop: MeshInstance3D = rain_drops[index]
		if drop == null or not is_instance_valid(drop):
			continue
		var phase: float = snow_elapsed * 1.7 + float(index) * 0.73
		var swirl := Vector3(sin(phase), 0.0, cos(phase * 0.81)) * sway_strength
		drop.global_position += (wind + swirl + Vector3.DOWN * fall_speed) * max(delta, 0.0)
		drop.rotate_y(delta * (0.8 + float(index % 5) * 0.16))
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
	payload.element = "ice"
	payload.source_name = str(weather_definition.get("display_name")) if weather_definition != null else "Snowfall"
	payload.hit_type = "weather"
	payload.status_effect = ""
	payload.status_duration = get_definition_float("status_duration", 4.0)
	payload.status_strength = get_definition_float("exposure_strength", 0.45)
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

	return delivered


func get_weather_tags() -> Array[String]:
	var tags: Array[String] = ["snow", "ice", "cold", "weather", "environment", "element_source"]
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
		original_fog_light_color = environment.fog_light_color
		original_fog_light_energy = environment.fog_light_energy
		original_fog_density = environment.fog_density
		environment_snapshot_valid = true

	environment.background_color = Color(0.16, 0.2, 0.27, 1.0)
	environment.ambient_light_color = Color(0.62, 0.75, 0.9, 1.0)
	environment.ambient_light_energy = 0.76
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.82, 0.94, 1.0)
	environment.fog_light_energy = 0.8
	environment.fog_density = 0.022


func restore_weather_environment() -> void:
	if not environment_snapshot_valid or world_environment == null or world_environment.environment == null:
		return
	var environment: Environment = world_environment.environment
	environment.background_color = original_background_color
	environment.ambient_light_color = original_ambient_color
	environment.ambient_light_energy = original_ambient_energy
	environment.fog_enabled = original_fog_enabled
	environment.fog_light_color = original_fog_light_color
	environment.fog_light_energy = original_fog_light_energy
	environment.fog_density = original_fog_density


func get_debug_data() -> Dictionary:
	return {
		"weather_active": active,
		"weather_id": get_weather_id(),
		"infinite_ice": is_generating_element("ice"),
		"exposure_pulses": pulse_count,
		"last_exposed_targets": last_exposed_targets,
		"snowflakes": rain_drops.size(),
	}
