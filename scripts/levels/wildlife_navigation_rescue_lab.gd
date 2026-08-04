extends Node3D
class_name WildlifeNavigationRescueLab

const WildlifeAnimalScript = preload("res://scripts/animals/navigation_bonded_animal_actor.gd")
const ANIMAL_ID: String = "wildlife_navigation_lab:juniper"
const ANIMAL_START: Vector3 = Vector3(-12.0, 0.42, 7.0)
const PLAYER_START: Vector3 = Vector3(0.0, 1.05, 10.5)
const TREAT_COUNT: int = 4

var player: Node3D
var animal: WildlifeAnimalScript
var navigation_region: NavigationRegion3D
var navigation_mesh: NavigationMesh
var rescue_gate: StaticBody3D
var rescue_zone: Area3D
var treat_pickup_root: Node3D
var treat_pickup_area: Area3D
var status_label: Label
var posture_toggle: CheckButton
var navigation_ready: bool = false
var navigation_bake_count: int = 0
var rescue_zone_active: bool = false
var treat_pickup_available: bool = true
var grace_threatening: bool = false
var noise_position: Vector3 = Vector3.ZERO
var noise_strength: float = 0.0
var noise_time_remaining: float = 0.0
var chase_event_cooldown: float = 0.0
var last_message: String = "Enter the field course and find Juniper."


func _ready() -> void:
	player = get_node_or_null("Player") as Node3D
	_build_environment()
	_build_navigation_course()
	_spawn_animal()
	_build_rescue_zone()
	_build_treat_pickup()
	_build_overlay()
	_update_objective()
	call_deferred("_rebake_navigation")


func _process(delta: float) -> void:
	noise_time_remaining = maxf(noise_time_remaining - delta, 0.0)
	if noise_time_remaining <= 0.0:
		noise_strength = 0.0
	chase_event_cooldown = maxf(chase_event_cooldown - delta, 0.0)
	_update_chase_bridge()
	_update_status_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		reset_encounter()
		get_viewport().set_input_as_handled()
		return
	if InputMap.has_action("interact") and event.is_action_pressed("interact") and rescue_zone_active:
		rescue_animal()
		get_viewport().set_input_as_handled()


func get_test_animal() -> WildlifeAnimalScript:
	return animal


func get_test_player() -> Node3D:
	return player


func is_navigation_ready() -> bool:
	return navigation_ready


func get_navigation_polygon_count() -> int:
	return navigation_mesh.get_polygon_count() if navigation_mesh != null else 0


func get_navigation_bake_count() -> int:
	return navigation_bake_count


func get_animal_grace_target(_animal: GenericAnimalActor) -> Node3D:
	return player


func get_animal_threat_target(_animal: GenericAnimalActor) -> Node3D:
	return player


func is_grace_threatening(_animal: GenericAnimalActor) -> bool:
	return grace_threatening


func is_animal_threat_mode_enabled(_animal: GenericAnimalActor) -> bool:
	return grace_threatening


func get_animal_noise_position(_animal: GenericAnimalActor) -> Vector3:
	return noise_position


func get_animal_noise_strength(_animal: GenericAnimalActor) -> float:
	return noise_strength if noise_time_remaining > 0.0 else 0.0


func get_animal_forage_position(_animal: GenericAnimalActor) -> Vector3:
	return Vector3(-8.5, 0.1, -8.5)


func get_animal_water_position(_animal: GenericAnimalActor) -> Vector3:
	return Vector3(12.0, 0.1, -9.0)


func broadcast_animal_alert(
	_source: GenericAnimalActor,
	_position_value: Vector3,
	_severity: float
) -> void:
	pass


func clamp_animal_position(value: Vector3) -> Vector3:
	return Vector3(
		clampf(value.x, -17.2, 17.2),
		value.y,
		clampf(value.z, -12.2, 12.2)
	)


func rescue_animal() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	if animal.rescued:
		_show_message("Juniper is already free of the debris.")
		return {"ok": true, "already_rescued": true}
	if rescue_gate != null and is_instance_valid(rescue_gate):
		var gate_parent: Node = rescue_gate.get_parent()
		if gate_parent != null:
			gate_parent.remove_child(rescue_gate)
		rescue_gate.queue_free()
		rescue_gate = null
	var result: Dictionary = animal.set_rescued(true, true)
	_show_message("Grace clears the debris. Juniper can now leave the pen.")
	call_deferred("_rebake_navigation")
	return result


func heal_animal() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.receive_healing_from_grace(2)
	_show_message(
		"Grace treats Juniper's injury. Trust rises."
		if bool(result.get("ok", false))
		else "Healing could not reach Juniper."
	)
	return result


func collect_treat_pickup() -> Dictionary:
	if not treat_pickup_available:
		return {"ok": false, "error": "pickup already collected"}
	var gained: int = GameState.add_inventory_item("field_treat", TREAT_COUNT)
	treat_pickup_available = false
	if treat_pickup_root != null:
		treat_pickup_root.visible = false
	if treat_pickup_area != null:
		treat_pickup_area.monitoring = false
	_show_message("Collected " + str(gained) + " Field Treats from the supply basket.")
	return {"ok": gained > 0, "gained": gained}


func feed_animal() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.interact_with_grace("feed")
	if bool(result.get("ok", false)):
		_show_message("Juniper accepts a Field Treat. " + str(GameState.get_inventory_count("field_treat")) + " remain.")
	elif str(result.get("error", "")) == "too far":
		_show_message("Move closer to Juniper before offering a treat.")
	elif str(result.get("error", "")) == "no treats":
		_show_message("Collect the glowing Field Treat basket first.")
	else:
		_show_message("Juniper will not take the treat yet.")
	return result


func bond_animal() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.attempt_bond()
	if bool(result.get("ok", false)):
		_show_message("Juniper bonds with Grace. Walk through the obstacle course to test following.")
	else:
		_show_message("Juniper needs more trust, familiarity, calm, and proximity before bonding.")
	return result


func toggle_follow() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.toggle_follow()
	if bool(result.get("ok", false)):
		_show_message("Juniper is following Grace." if bool(result.get("follow_enabled", false)) else "Juniper will stay here.")
	else:
		_show_message("Bond with Juniper before changing follow behavior.")
	return result


func report_attack_test() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.receive_damage_payload({
		"amount": 2,
		"source_name": "Grace",
	})
	_show_message("Test harm event reported. Juniper's trust and fear now reflect it.")
	return result


func make_noise() -> void:
	noise_position = player.global_position if player != null else Vector3.ZERO
	noise_strength = 1.5
	noise_time_remaining = 0.85
	_show_message("Grace makes a loud field disturbance.")
	if animal != null:
		animal.force_decision(true)


func separate_grace() -> void:
	if player == null or animal == null:
		return
	animal.global_position = Vector3(-15.0, 0.48, 10.0)
	animal.velocity = Vector3.ZERO
	player.global_position = Vector3(16.0, 1.05, -10.5)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	animal.force_navigation_repath()
	animal.force_decision(true)
	_show_message("Grace and Juniper were separated beyond the recovery threshold.")


func force_repath() -> void:
	if animal == null:
		return
	animal.force_navigation_repath()
	animal.force_decision(true)
	_show_message("Forced a navigation repath.")


func save_bond() -> Dictionary:
	if animal == null:
		return {"ok": false, "error": "animal unavailable"}
	var result: Dictionary = animal.persist_named_state(true)
	_show_message("Saved Juniper's named relationship record.")
	return {"ok": not result.is_empty(), "record": result}


func reload_bond() -> bool:
	if animal == null:
		return false
	var loaded: bool = animal.reload_persistent_state()
	_show_message("Reloaded Juniper's saved relationship." if loaded else "No saved relationship was found for Juniper.")
	return loaded


func clear_bond() -> bool:
	if animal == null:
		return false
	var removed: bool = animal.clear_persistent_bond()
	animal.set_rescued(rescue_gate == null, false)
	animal.set_injured(true, 0.65)
	_show_message("Cleared Juniper's saved relationship.")
	return removed


func prepare_navigation_test_positions() -> void:
	if animal == null or player == null:
		return
	if not animal.rescued:
		rescue_animal()
	animal.global_position = Vector3(-7.0, 0.48, 3.4)
	animal.velocity = Vector3.ZERO
	player.global_position = Vector3(8.0, 1.05, -2.2)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	animal.set_navigation_ready(navigation_ready)
	animal.force_navigation_repath()
	animal.force_decision(true)


func reset_encounter() -> void:
	grace_threatening = false
	noise_strength = 0.0
	noise_time_remaining = 0.0
	chase_event_cooldown = 0.0
	if posture_toggle != null:
		posture_toggle.set_pressed_no_signal(false)
	if rescue_gate == null or not is_instance_valid(rescue_gate):
		rescue_gate = _create_rescue_gate()
	if animal != null:
		animal.reset_actor()
		animal.global_position = ANIMAL_START
		animal.velocity = Vector3.ZERO
		animal.set_rescued(false, false)
		animal.set_injured(true, 0.65)
	if player != null:
		player.global_position = PLAYER_START
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	_respawn_treat_pickup()
	call_deferred("_rebake_navigation")
	_show_message("Wildlife encounter reset. Saved trust and bond records remain.")


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.045, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.64, 0.74)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.34
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	add_child(sun)


func _build_navigation_course() -> void:
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "NavigationCourse"
	navigation_mesh = NavigationMesh.new()
	navigation_mesh.agent_radius = 0.52
	navigation_mesh.agent_height = 1.35
	navigation_mesh.agent_max_climb = 0.55
	navigation_mesh.agent_max_slope = 50.0
	navigation_mesh.cell_size = 0.25
	navigation_mesh.cell_height = 0.2
	navigation_mesh.region_min_size = 1.0
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	navigation_mesh.geometry_collision_mask = 1
	navigation_mesh.filter_baking_aabb = AABB(Vector3(-18.0, -2.0, -13.0), Vector3(36.0, 8.0, 26.0))
	navigation_region.navigation_mesh = navigation_mesh
	add_child(navigation_region)

	_add_nav_box("Ground", Vector3(35.0, 0.5, 25.0), Vector3(0.0, -0.25, 0.0), Color(0.11, 0.24, 0.16))
	for x: float in [-17.5, 17.5]:
		_add_nav_box("Boundary", Vector3(0.45, 2.4, 25.0), Vector3(x, 1.2, 0.0), Color(0.12, 0.14, 0.18))
	for z: float in [-12.5, 12.5]:
		_add_nav_box("Boundary", Vector3(35.0, 2.4, 0.45), Vector3(0.0, 1.2, z), Color(0.12, 0.14, 0.18))

	_add_nav_box("PenBack", Vector3(5.8, 2.0, 0.45), Vector3(-12.0, 1.0, 9.7), Color(0.34, 0.24, 0.14))
	_add_nav_box("PenLeft", Vector3(0.45, 2.0, 5.7), Vector3(-14.7, 1.0, 7.0), Color(0.34, 0.24, 0.14))
	_add_nav_box("PenRight", Vector3(0.45, 2.0, 5.7), Vector3(-9.3, 1.0, 7.0), Color(0.34, 0.24, 0.14))
	rescue_gate = _create_rescue_gate()

	_add_nav_box("MazeWallNorthLeft", Vector3(19.0, 2.2, 0.55), Vector3(-7.5, 1.1, 1.2), Color(0.22, 0.25, 0.29))
	_add_nav_box("MazeWallNorthRight", Vector3(11.0, 2.2, 0.55), Vector3(11.5, 1.1, 1.2), Color(0.22, 0.25, 0.29))
	_add_nav_box("MazeWallSouthLeft", Vector3(11.0, 2.2, 0.55), Vector3(-11.5, 1.1, -4.4), Color(0.22, 0.25, 0.29))
	_add_nav_box("MazeWallSouthRight", Vector3(19.0, 2.2, 0.55), Vector3(7.5, 1.1, -4.4), Color(0.22, 0.25, 0.29))

	_add_nav_box("Ramp", Vector3(5.0, 0.45, 4.0), Vector3(8.6, 0.48, 7.0), Color(0.28, 0.34, 0.24), Vector3(0.0, 0.0, -15.0))
	_add_nav_box("RaisedLookout", Vector3(5.0, 1.5, 4.0), Vector3(12.4, 0.75, 7.0), Color(0.24, 0.3, 0.22))
	_add_world_label("RESCUE PEN", Vector3(-12.0, 0.12, 10.8), Color(1.0, 0.76, 0.34))
	_add_world_label("S-PATH FOLLOW COURSE", Vector3(0.0, 0.12, -1.7), Color(0.54, 0.84, 1.0))
	_add_world_label("RAMP + LOOKOUT", Vector3(11.0, 1.65, 7.0), Color(0.62, 1.0, 0.56))


func _create_rescue_gate() -> StaticBody3D:
	return _add_nav_box(
		"RescueDebris",
		Vector3(4.7, 1.65, 0.65),
		Vector3(-12.0, 0.82, 4.35),
		Color(0.5, 0.25, 0.1),
		Vector3(0.0, 0.0, 7.0)
	)


func _spawn_animal() -> void:
	animal = WildlifeAnimalScript.new()
	animal.animal_name = "Juniper"
	animal.species_id = "sheep"
	animal.personality_profile_id = "cautious"
	animal.persistent_animal_id = ANIMAL_ID
	animal.move_speed = 3.15
	animal.decision_interval = 0.55
	animal.movement_locked = true
	animal.rescued = false
	animal.injured = true
	animal.injury_ratio = 0.65
	animal.position = ANIMAL_START
	add_child(animal)
	animal.set_navigation_ready(false)


func _build_rescue_zone() -> void:
	rescue_zone = Area3D.new()
	rescue_zone.name = "RescueInteractionZone"
	rescue_zone.position = Vector3(-12.0, 1.0, 3.3)
	rescue_zone.collision_layer = 0
	rescue_zone.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 2.2, 3.0)
	collision.shape = shape
	rescue_zone.add_child(collision)
	rescue_zone.body_entered.connect(_on_rescue_zone_body_entered)
	rescue_zone.body_exited.connect(_on_rescue_zone_body_exited)
	add_child(rescue_zone)
	var label := Label3D.new()
	label.text = "CLEAR DEBRIS\nInteract or use panel"
	label.position = Vector3(0.0, 1.8, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.006
	label.outline_size = 8
	label.modulate = Color(1.0, 0.68, 0.24)
	rescue_zone.add_child(label)


func _build_treat_pickup() -> void:
	treat_pickup_root = Node3D.new()
	treat_pickup_root.name = "FieldTreatBasket"
	treat_pickup_root.position = Vector3(5.5, 0.45, 9.2)
	add_child(treat_pickup_root)
	var basket := MeshInstance3D.new()
	var basket_mesh := CylinderMesh.new()
	basket_mesh.top_radius = 0.5
	basket_mesh.bottom_radius = 0.62
	basket_mesh.height = 0.55
	basket.mesh = basket_mesh
	var basket_material := StandardMaterial3D.new()
	basket_material.albedo_color = Color(0.62, 0.34, 0.12)
	basket_material.roughness = 0.9
	basket.material_override = basket_material
	treat_pickup_root.add_child(basket)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.72, 1.0, 0.28)
	glow.light_energy = 2.1
	glow.omni_range = 3.0
	glow.position.y = 0.65
	treat_pickup_root.add_child(glow)
	var label := Label3D.new()
	label.text = "FIELD TREATS"
	label.position = Vector3(0.0, 1.25, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.006
	label.outline_size = 8
	label.modulate = Color(0.72, 1.0, 0.32)
	treat_pickup_root.add_child(label)
	treat_pickup_area = Area3D.new()
	treat_pickup_area.collision_layer = 0
	treat_pickup_area.collision_mask = 1
	var pickup_collision := CollisionShape3D.new()
	var pickup_shape := SphereShape3D.new()
	pickup_shape.radius = 1.1
	pickup_collision.shape = pickup_shape
	treat_pickup_area.add_child(pickup_collision)
	treat_pickup_area.body_entered.connect(_on_treat_pickup_body_entered)
	treat_pickup_root.add_child(treat_pickup_area)


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 35
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 72.0)
	panel.custom_minimum_size = Vector2(590.0, 0.0)
	canvas.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.03, 0.052, 0.94)
	style.border_color = Color(0.35, 0.74, 0.64, 0.82)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 15.0
	style.content_margin_right = 15.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := Label.new()
	title.text = "WILDLIFE RESCUE + NAVIGATION LAB"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.78))
	box.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)
	posture_toggle = CheckButton.new()
	posture_toggle.text = "Grace threatening posture"
	posture_toggle.focus_mode = Control.FOCUS_ALL
	posture_toggle.toggled.connect(_on_posture_toggled)
	box.add_child(posture_toggle)
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	_add_button(grid, "Rescue / Rebuild Nav", Callable(self, "rescue_animal"))
	_add_button(grid, "Heal / Help", Callable(self, "heal_animal"))
	_add_button(grid, "Feed Treat", Callable(self, "feed_animal"))
	_add_button(grid, "Bond Juniper", Callable(self, "bond_animal"))
	_add_button(grid, "Follow / Stay", Callable(self, "toggle_follow"))
	_add_button(grid, "Make Noise", Callable(self, "make_noise"))
	_add_button(grid, "Separate Grace", Callable(self, "separate_grace"))
	_add_button(grid, "Force Repath", Callable(self, "force_repath"))
	_add_button(grid, "Test Attack", Callable(self, "report_attack_test"))
	_add_button(grid, "Save Bond", Callable(self, "save_bond"))
	_add_button(grid, "Reload Bond", Callable(self, "reload_bond"))
	_add_button(grid, "Clear Bond", Callable(self, "clear_bond"))
	_add_button(grid, "Respawn Treats", Callable(self, "_respawn_treat_pickup"))
	_add_button(grid, "Reset Encounter", Callable(self, "reset_encounter"))
	var hint := Label.new()
	hint.text = "Collect the glowing basket, clear the debris, heal and feed Juniper, then bond and cross the S-path. The normal sword can also hit her, so lower it unless you are testing consequences."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.68, 0.76, 0.82))
	box.add_child(hint)


func _update_status_panel() -> void:
	if status_label == null or animal == null:
		return
	var relationship_data: Dictionary = animal.get_relationship_data()
	var bond_data: Dictionary = animal.get_bond_data()
	var navigation_data: Dictionary = animal.get_navigation_debug_data()
	status_label.text = (
		"Navmesh: " + ("READY" if navigation_ready else "BAKING")
		+ "   Polygons " + str(get_navigation_polygon_count())
		+ "   Bakes " + str(navigation_bake_count)
		+ "\nJuniper: " + ("RESCUED" if animal.rescued else "TRAPPED")
		+ "   Injury " + _percent(animal.injury_ratio)
		+ "   Action " + animal.current_action_id.replace("_", " ").capitalize()
		+ "\nBond: " + ("YES" if bool(bond_data.get("bonded", false)) else "NO")
		+ "   Mode " + ("FOLLOW" if bool(bond_data.get("follow_enabled", false)) else "STAY")
		+ "   Treats " + str(GameState.get_inventory_count("field_treat"))
		+ "\nTrust " + _signed_percent(float(relationship_data.get("trust", 0.0)))
		+ "   Familiarity " + _percent(float(relationship_data.get("familiarity", 0.0)))
		+ "   Fear memory " + _percent(float(relationship_data.get("fear_association", 0.0)))
		+ "\nPath points " + str(navigation_data.get("path_point_count", 0))
		+ "   Queries " + str(navigation_data.get("navigation_queries", 0))
		+ "   Repaths " + str(navigation_data.get("repath_count", 0))
		+ "   Recoveries " + str(navigation_data.get("recovery_count", 0))
		+ "\nStuck " + str(snappedf(float(navigation_data.get("stuck_seconds", 0.0)), 0.1)) + "s"
		+ "   Last: " + last_message
	)


func _update_chase_bridge() -> void:
	if animal == null or player == null or not animal.rescued or chase_event_cooldown > 0.0:
		return
	if not (player is CharacterBody3D):
		return
	var player_body: CharacterBody3D = player as CharacterBody3D
	var planar_speed: float = Vector2(player_body.velocity.x, player_body.velocity.z).length()
	var distance: float = player.global_position.distance_to(animal.global_position)
	if planar_speed < 5.2 or distance > 4.2:
		return
	var animal_forward: Vector3 = -animal.global_transform.basis.z
	animal_forward.y = 0.0
	var to_player: Vector3 = player.global_position - animal.global_position
	to_player.y = 0.0
	if animal_forward.length_squared() > 0.001 and to_player.length_squared() > 0.001:
		if animal_forward.normalized().dot(to_player.normalized()) > -0.05:
			return
	animal.report_grace_event("chase", 0.55)
	chase_event_cooldown = 4.5
	_show_message("Juniper interpreted Grace's close sprint as a chase.")


func _rebake_navigation() -> void:
	if navigation_region == null or navigation_mesh == null:
		return
	navigation_ready = false
	if animal != null:
		animal.set_navigation_ready(false)
	navigation_region.bake_navigation_mesh(false)
	navigation_bake_count += 1
	navigation_ready = navigation_mesh.get_polygon_count() > 0
	if animal != null:
		animal.set_navigation_ready(navigation_ready)
	_show_message(
		"Navigation mesh rebuilt with " + str(navigation_mesh.get_polygon_count()) + " polygons."
		if navigation_ready
		else "Navigation mesh bake produced no walkable polygons."
	)


func _add_nav_box(
	body_name: String,
	size: Vector3,
	position_value: Vector3,
	color: Color,
	rotation_value: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position_value
	body.rotation_degrees = rotation_value
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.emission_enabled = true
	material.emission = color.darkened(0.5)
	material.emission_energy_multiplier = 0.12
	visual.material_override = material
	body.add_child(visual)
	navigation_region.add_child(body)
	return body


func _add_world_label(text_value: String, position_value: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.rotation_degrees.x = -90.0
	label.font_size = 26
	label.pixel_size = 0.009
	label.outline_size = 8
	label.modulate = color
	add_child(label)


func _add_button(parent: Control, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(158.0, 34.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _on_rescue_zone_body_entered(body: Node3D) -> void:
	if body == player:
		rescue_zone_active = true
		_show_message("Debris is within reach. Use Interact or the Rescue button.")


func _on_rescue_zone_body_exited(body: Node3D) -> void:
	if body == player:
		rescue_zone_active = false


func _on_treat_pickup_body_entered(body: Node3D) -> void:
	if body == player:
		collect_treat_pickup()


func _on_posture_toggled(value: bool) -> void:
	grace_threatening = value
	_show_message("Grace posture: " + ("threatening" if value else "peaceful"))
	if animal != null:
		animal.force_decision(true)


func _respawn_treat_pickup() -> void:
	treat_pickup_available = true
	if treat_pickup_root != null:
		treat_pickup_root.visible = true
	if treat_pickup_area != null:
		treat_pickup_area.monitoring = true
	_show_message("Field Treat basket respawned.")


func _show_message(message: String) -> void:
	last_message = message
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null and game_ui.has_method("show_message"):
		game_ui.call("show_message", message)
	else:
		print(message)


func _update_objective() -> void:
	var objective: String = "Collect Field Treats, rescue and heal Juniper, then bond and guide her through the navigation course."
	GameState.set_objective(objective)
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null and game_ui.has_method("set_objective"):
		game_ui.call("set_objective", objective)


func _percent(value: float) -> String:
	return str(int(round(clampf(value, 0.0, 1.0) * 100.0))) + "%"


func _signed_percent(value: float) -> String:
	var amount: int = int(round(clampf(value, -1.0, 1.0) * 100.0))
	return ("+" if amount >= 0 else "") + str(amount) + "%"
