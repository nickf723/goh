extends Node3D
class_name PrototypeRainWeatherLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const RainLabLoadout: Resource = preload("res://data/loadouts/grace_rain_weather_lab_loadout.tres")
const ThermalStateScript = preload("res://scripts/physics/thermal_state.gd")
const CombustionStateScript = preload("res://scripts/physics/combustion_state.gd")
const CombustionPresenterScript = preload("res://scripts/presentation/combustion_presenter.gd")
const WeatherExposureProbeScript = preload("res://scripts/weather/weather_exposure_probe.gd")

@export var enable_editor_f8_reset: bool = true
@export var readout_refresh_interval: float = 0.12

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var concentration_manager: Node = get_node_or_null("ConcentrationManager")
@onready var weather_controller: Node = get_node_or_null("RainWeatherController")

var stat_snapshot: Dictionary = {}
var initial_player_transform: Transform3D
var readout_timer: float = 0.0
var reset_count: int = 0

var spell_cost_label: Label3D = null
var source_label: Label3D = null
var basin_water: MeshInstance3D = null
var brazier_root: Node3D = null
var brazier_thermal: Node = null
var brazier_combustion: Node = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	build_arena()
	configure_player()
	connect_weather_signals()

	if player != null:
		initial_player_transform = player.transform
		player.add_to_group("player")
		player.add_to_group("weather_exposed")

	GameState.set_objective("Cast Rain, test the reserved mana ceiling, and use the sky as an infinite Water source.")
	show_message("Rain Laboratory ready. Cast Rain once to reserve mana and make Water spells free. Cast it again to dismiss the weather.")
	update_readouts()


func _process(delta: float) -> void:
	readout_timer -= delta
	if readout_timer <= 0.0:
		readout_timer = max(readout_refresh_interval, 0.05)
		update_readouts()
	update_basin_visual(delta)


func _exit_tree() -> void:
	if weather_controller != null and bool(weather_controller.get("active")):
		weather_controller.call("stop_weather", false)
	restore_stat_snapshot()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.physical_keycode != KEY_F8:
		return
	get_viewport().set_input_as_handled()
	reset_lab()


func configure_player() -> void:
	if player == null:
		return
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		var runtime_loadout: Resource = RainLabLoadout.duplicate(true)
		ability_caster.set("loadout", runtime_loadout)
		ability_caster.set("current_ability_index", 0)
		if ability_caster.has_method("align_focus_menu_to_current_ability"):
			ability_caster.call("align_focus_menu_to_current_ability")
		if ability_caster.has_method("emit_current_ability"):
			ability_caster.call("emit_current_ability")

	GameState.set_stat("max_mana", 10)
	GameState.set_stat("mana", 10)
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("focus", max(GameState.get_stat("focus"), 5))


func connect_weather_signals() -> void:
	if weather_controller == null:
		return
	if weather_controller.has_signal("weather_started") and not weather_controller.weather_started.is_connected(_on_weather_started):
		weather_controller.weather_started.connect(_on_weather_started)
	if weather_controller.has_signal("weather_stopped") and not weather_controller.weather_stopped.is_connected(_on_weather_stopped):
		weather_controller.weather_stopped.connect(_on_weather_stopped)


func build_arena() -> void:
	create_floor()
	create_boundaries()
	create_instruction_board()
	create_weather_probe("RAIN EXPOSURE A", Vector3(-4.4, 0.0, -1.5))
	create_weather_probe("RAIN EXPOSURE B", Vector3(4.4, 0.0, -1.5))
	create_burning_brazier(Vector3(0.0, 0.0, -5.3))
	create_rain_collector(Vector3(0.0, 0.0, 4.2))
	create_spell_cost_readout(Vector3(-6.0, 1.8, 4.8))


func create_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "WeatherLabFloor"
	floor_body.position = Vector3(0.0, -0.35, 0.0)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(18.0, 0.7, 18.0)
	collision.shape = shape
	floor_body.add_child(collision)

	var floor_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(18.0, 0.7, 18.0)
	floor_mesh.mesh = mesh
	floor_mesh.material_override = ElementVisuals.make_material(Color(0.19, 0.22, 0.2, 1.0), 0.05, 1.0, false)
	floor_body.add_child(floor_mesh)
	add_child(floor_body)

	for index: int in range(4):
		var channel := MeshInstance3D.new()
		channel.name = "DrainChannel" + str(index)
		var channel_mesh := BoxMesh.new()
		channel_mesh.size = Vector3(0.09, 0.03, 16.0)
		channel.mesh = channel_mesh
		channel.position = Vector3(-6.0 + float(index) * 4.0, 0.025, 0.0)
		channel.material_override = ElementVisuals.make_material(Color(0.14, 0.38, 0.58, 1.0), 0.55, 0.72, true)
		add_child(channel)


func create_boundaries() -> void:
	var wall_color := Color(0.12, 0.16, 0.2, 1.0)
	create_static_box("NorthWall", Vector3(0.0, 1.5, -9.0), Vector3(18.0, 3.0, 0.5), wall_color)
	create_static_box("SouthWall", Vector3(0.0, 1.5, 9.0), Vector3(18.0, 3.0, 0.5), wall_color)
	create_static_box("WestWall", Vector3(-9.0, 1.5, 0.0), Vector3(0.5, 3.0, 18.0), wall_color)
	create_static_box("EastWall", Vector3(9.0, 1.5, 0.0), Vector3(0.5, 3.0, 18.0), wall_color)


func create_instruction_board() -> void:
	var board := Node3D.new()
	board.name = "InstructionBoard"
	board.position = Vector3(0.0, 2.15, 7.8)
	add_child(board)
	ElementVisuals.add_box(board, "Board", Vector3(9.6, 2.4, 0.18), Color(0.04, 0.07, 0.1, 1.0), Vector3.ZERO, Vector3.ZERO, 0.2, 0.94)

	var label := Label3D.new()
	label.text = "RAIN CONCENTRATION LAB\n1  Cast Rain   •   2  Switch to Water Jet   •   3  Cast freely\nSpend mana on Fire or Ice and watch regeneration stop at the reserved ceiling.\nRain also wets exposed objects and extinguishes the brazier. Cast Rain again to release it."
	label.position = Vector3(0.0, 0.0, 0.11)
	label.font_size = 28
	label.pixel_size = 0.006
	label.outline_size = 5
	label.modulate = Color(0.75, 0.9, 1.0, 1.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(label)


func create_weather_probe(label_text: String, position_value: Vector3) -> void:
	var probe: Node3D = WeatherExposureProbeScript.new() as Node3D
	probe.name = label_text.replace(" ", "")
	probe.position = position_value
	probe.set("probe_label", label_text)
	add_child(probe)


func create_burning_brazier(position_value: Vector3) -> void:
	brazier_root = Node3D.new()
	brazier_root.name = "RainExposedBrazier"
	brazier_root.position = position_value
	brazier_root.add_to_group("weather_exposed")
	brazier_root.add_to_group("lab_resettable")
	add_child(brazier_root)

	ElementVisuals.add_box(brazier_root, "StoneBase", Vector3(2.2, 0.45, 2.2), Color(0.24, 0.25, 0.28, 1.0), Vector3(0.0, 0.22, 0.0), Vector3.ZERO, 0.1, 1.0)
	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0
		ElementVisuals.add_capsule(
			brazier_root,
			"FuelLog" + str(index),
			0.16,
			1.55,
			Color(0.28, 0.1, 0.04, 1.0),
			Vector3(cos(angle) * 0.25, 0.62, sin(angle) * 0.25),
			Vector3.ONE,
			Vector3(90.0, rad_to_deg(angle) + 45.0, 0.0),
			0.2,
			1.0
		)

	brazier_thermal = ThermalStateScript.new()
	brazier_thermal.name = "ThermalState"
	brazier_thermal.set("starting_temperature_c", 230.0)
	brazier_thermal.set("passive_ambient_exchange", false)
	brazier_thermal.set("heat_capacity_override_j_per_c", 8.0)
	brazier_root.add_child(brazier_thermal)

	brazier_combustion = CombustionStateScript.new()
	brazier_combustion.name = "CombustionState"
	brazier_combustion.set("combustible_override", true)
	brazier_combustion.set("initial_fuel_kg_override", 2.0)
	brazier_combustion.set("ignition_temperature_c_override", 100.0)
	brazier_combustion.set("sustain_temperature_c_override", 60.0)
	brazier_combustion.set("burn_rate_kg_per_second_override", 0.004)
	brazier_combustion.set("heat_output_j_per_second_override", 18.0)
	brazier_combustion.set("smoke_yield_override", 0.62)
	brazier_combustion.set("ember_yield_override", 0.48)
	brazier_combustion.set("starts_ignited", true)
	brazier_root.add_child(brazier_combustion)

	var presenter: Node3D = CombustionPresenterScript.new() as Node3D
	presenter.name = "CombustionPresenter"
	presenter.set("profile_kind", "bonfire")
	presenter.position = Vector3(0.0, 0.72, 0.0)
	brazier_root.add_child(presenter)

	var label := Label3D.new()
	label.text = "RAIN-EXPOSED FIRE\nRain should extinguish this"
	label.position = Vector3(0.0, 2.4, 0.0)
	label.font_size = 28
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = Color(1.0, 0.58, 0.24, 1.0)
	brazier_root.add_child(label)


func create_rain_collector(position_value: Vector3) -> void:
	var collector := Node3D.new()
	collector.name = "RainCollector"
	collector.position = position_value
	add_child(collector)

	ElementVisuals.add_torus(collector, "BasinRim", 1.45, 1.7, Color(0.42, 0.46, 0.52, 1.0), Vector3(0.0, 0.34, 0.0), Vector3.ZERO, 0.2, 1.0)
	ElementVisuals.add_box(collector, "BasinBase", Vector3(3.2, 0.32, 3.2), Color(0.22, 0.25, 0.29, 1.0), Vector3(0.0, 0.12, 0.0), Vector3.ZERO, 0.1, 1.0)

	basin_water = MeshInstance3D.new()
	basin_water.name = "CollectedRain"
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 1.42
	water_mesh.bottom_radius = 1.42
	water_mesh.height = 0.08
	water_mesh.radial_segments = 28
	basin_water.mesh = water_mesh
	basin_water.position = Vector3(0.0, 0.38, 0.0)
	basin_water.scale = Vector3(1.0, 0.05, 1.0)
	basin_water.material_override = ElementVisuals.make_material(Color(0.1, 0.52, 0.98, 1.0), 1.4, 0.72, true)
	basin_water.visible = false
	collector.add_child(basin_water)

	source_label = Label3D.new()
	source_label.position = Vector3(0.0, 2.0, 0.0)
	source_label.font_size = 30
	source_label.pixel_size = 0.007
	source_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	source_label.outline_size = 5
	collector.add_child(source_label)


func create_spell_cost_readout(position_value: Vector3) -> void:
	spell_cost_label = Label3D.new()
	spell_cost_label.name = "SpellCostReadout"
	spell_cost_label.position = position_value
	spell_cost_label.font_size = 28
	spell_cost_label.pixel_size = 0.007
	spell_cost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spell_cost_label.outline_size = 5
	spell_cost_label.modulate = Color(0.7, 0.88, 1.0, 1.0)
	add_child(spell_cost_label)


func create_static_box(name_value: String, position_value: Vector3, size_value: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = name_value
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(color, 0.08, 1.0, false)
	body.add_child(mesh_instance)
	add_child(body)


func update_basin_visual(delta: float) -> void:
	if basin_water == null:
		return
	var raining: bool = weather_controller != null and bool(weather_controller.get("active"))
	basin_water.visible = raining or basin_water.scale.y > 0.06
	var target_scale_y: float = 1.0 if raining else 0.05
	basin_water.scale.y = move_toward(basin_water.scale.y, target_scale_y, max(delta, 0.0) * (0.42 if raining else 0.12))


func update_readouts() -> void:
	var raining: bool = weather_controller != null and bool(weather_controller.get("active"))
	var current_mana: int = GameState.get_stat("mana")
	var maximum_mana: int = GameState.get_stat("max_mana")
	var usable_cap: int = maximum_mana
	var reserved: int = 0
	if concentration_manager != null and concentration_manager.has_method("get_usable_mana_cap"):
		usable_cap = int(concentration_manager.call("get_usable_mana_cap"))
		reserved = int(concentration_manager.call("get_reserved_mana"))

	var water_cost: int = get_spell_cost("water_jet")
	var fire_cost: int = get_spell_cost("firebolt")
	if spell_cost_label != null:
		spell_cost_label.text = (
			("RAIN ACTIVE" if raining else "RAIN DORMANT")
			+ "\nMana: " + str(current_mana) + " / " + str(usable_cap)
			+ " usable   •   " + str(reserved) + " reserved"
			+ "\nWater Jet: " + ("FREE" if water_cost <= 0 else str(water_cost) + " mana")
			+ "   •   Firebolt: " + str(fire_cost) + " mana"
		)
		spell_cost_label.modulate = Color(0.42, 0.78, 1.0, 1.0) if raining else Color(0.72, 0.78, 0.86, 1.0)

	if source_label != null:
		source_label.text = (
			"ATMOSPHERIC WATER SOURCE\n"
			+ ("INFINITE WHILE RAIN FALLS" if raining else "INACTIVE")
		)
		source_label.modulate = Color(0.32, 0.76, 1.0, 1.0) if raining else Color(0.56, 0.6, 0.66, 1.0)


func get_spell_cost(spell_id: String) -> int:
	if player == null:
		return -1
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster == null:
		return -1
	var loadout_value: Variant = ability_caster.get("loadout")
	if loadout_value == null:
		return -1
	var equipped_value: Variant = loadout_value.get("equipped_abilities")
	if not (equipped_value is Array):
		return -1
	for ability_value: Variant in equipped_value as Array:
		if ability_value == null:
			continue
		var candidate_id: String = str(ability_value.get("spell_id"))
		if candidate_id == spell_id:
			return int(ability_value.get("mana_cost"))
	return -1


func _on_weather_started(_weather_id: String) -> void:
	GameState.set_objective("Rain is active. Water spells are free; test other costs against the reserved mana ceiling.")
	update_readouts()


func _on_weather_stopped(_weather_id: String) -> void:
	GameState.set_objective("Rain dismissed. The full mana capacity is available for regeneration again.")
	update_readouts()


func reset_lab() -> void:
	reset_count += 1
	if weather_controller != null and bool(weather_controller.get("active")):
		weather_controller.call("stop_weather", false)

	for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if node == null or not is_instance_valid(node) or not is_ancestor_of(node):
			continue
		if node.has_method("reset_target"):
			node.call("reset_target")

	if brazier_thermal != null and brazier_thermal.has_method("set_temperature"):
		brazier_thermal.call("set_temperature", 230.0, "Rain Lab Reset")
	if brazier_combustion != null and brazier_combustion.has_method("force_ignite"):
		brazier_combustion.call("force_ignite", "Rain Lab Reset")

	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	configure_player()
	if basin_water != null:
		basin_water.scale.y = 0.05
		basin_water.visible = false
	GameState.set_objective("Cast Rain, test the reserved mana ceiling, and use the sky as an infinite Water source.")
	show_message("Rain Laboratory reset #" + str(reset_count) + ".")
	update_readouts()


func restore_stat_snapshot() -> void:
	if stat_snapshot.is_empty():
		return
	for stat_name: Variant in stat_snapshot.keys():
		GameState.set_stat(str(stat_name), int(stat_snapshot[stat_name]))


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"rain_weather_lab": true,
		"raining": weather_controller != null and bool(weather_controller.get("active")),
		"mana": GameState.get_stat("mana"),
		"max_mana": GameState.get_stat("max_mana"),
		"water_cost": get_spell_cost("water_jet"),
		"fire_cost": get_spell_cost("firebolt"),
		"reset_count": reset_count,
	}
