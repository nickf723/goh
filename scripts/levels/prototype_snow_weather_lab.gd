extends Node3D
class_name PrototypeSnowWeatherLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const SnowLabLoadout: Resource = preload("res://data/loadouts/grace_snow_weather_lab_loadout.tres")
const ThermalStateScript = preload("res://scripts/physics/thermal_state.gd")
const CombustionStateScript = preload("res://scripts/physics/combustion_state.gd")
const CombustionPresenterScript = preload("res://scripts/presentation/combustion_presenter.gd")
const WeatherExposureProbeScript = preload("res://scripts/weather/weather_exposure_probe.gd")
const SnowAccumulationFieldScript = preload("res://scripts/weather/snow_accumulation_field.gd")
const SnowPhaseBasinScript = preload("res://scripts/weather/snow_phase_basin.gd")

@export var enable_editor_f8_reset: bool = true
@export var readout_refresh_interval: float = 0.12

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var concentration_manager: Node = get_node_or_null("ConcentrationManager")
@onready var weather_controller: Node = get_node_or_null("SnowWeatherController")

var stat_snapshot: Dictionary = {}
var initial_player_transform: Transform3D
var readout_timer: float = 0.0
var reset_count: int = 0

var spell_cost_label: Label3D = null
var source_label: Label3D = null
var brazier_root: Node3D = null
var brazier_thermal: Node = null
var brazier_combustion: Node = null
var accumulation_field: Node3D = null
var phase_basin: Node3D = null


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

	GameState.set_objective("Cast Snowfall, test the reserved mana ceiling, and use the frozen sky as an infinite Ice source.")
	show_message("Snowfall Laboratory ready. Cast Snowfall once to reserve mana and make Ice spells free. Cast it again to dismiss the weather.")
	update_readouts()


func _process(delta: float) -> void:
	readout_timer -= delta
	if readout_timer <= 0.0:
		readout_timer = max(readout_refresh_interval, 0.05)
		update_readouts()


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
		var runtime_loadout: Resource = SnowLabLoadout.duplicate(true)
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
	var started_callable := Callable(self, "_on_weather_started")
	var stopped_callable := Callable(self, "_on_weather_stopped")
	if weather_controller.has_signal("weather_started") and not weather_controller.is_connected("weather_started", started_callable):
		weather_controller.connect("weather_started", started_callable)
	if weather_controller.has_signal("weather_stopped") and not weather_controller.is_connected("weather_stopped", stopped_callable):
		weather_controller.connect("weather_stopped", stopped_callable)


func build_arena() -> void:
	create_floor()
	create_boundaries()
	create_accumulation_field()
	create_instruction_board()
	create_weather_probe("SNOW EXPOSURE A", Vector3(-4.4, 0.0, -1.5))
	create_weather_probe("SNOW EXPOSURE B", Vector3(4.4, 0.0, -1.5))
	create_burning_brazier(Vector3(0.0, 0.0, -5.3))
	create_phase_basin(Vector3(0.0, 0.0, 4.2))
	create_spell_cost_readout(Vector3(-6.0, 1.8, 4.8))


func create_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "SnowLabFloor"
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
	floor_mesh.material_override = ElementVisuals.make_material(Color(0.18, 0.2, 0.24, 1.0), 0.04, 1.0, false)
	floor_body.add_child(floor_mesh)
	add_child(floor_body)

	for index: int in range(5):
		var seam := MeshInstance3D.new()
		seam.name = "StoneSeam" + str(index)
		var seam_mesh := BoxMesh.new()
		seam_mesh.size = Vector3(0.06, 0.025, 16.0)
		seam.mesh = seam_mesh
		seam.position = Vector3(-6.4 + float(index) * 3.2, 0.018, 0.0)
		seam.material_override = ElementVisuals.make_material(Color(0.08, 0.12, 0.18, 1.0), 0.15, 0.8, true)
		add_child(seam)


func create_boundaries() -> void:
	var wall_color := Color(0.12, 0.15, 0.21, 1.0)
	create_static_box("NorthWall", Vector3(0.0, 1.5, -9.0), Vector3(18.0, 3.0, 0.5), wall_color)
	create_static_box("SouthWall", Vector3(0.0, 1.5, 9.0), Vector3(18.0, 3.0, 0.5), wall_color)
	create_static_box("WestWall", Vector3(-9.0, 1.5, 0.0), Vector3(0.5, 3.0, 18.0), wall_color)
	create_static_box("EastWall", Vector3(9.0, 1.5, 0.0), Vector3(0.5, 3.0, 18.0), wall_color)


func create_accumulation_field() -> void:
	accumulation_field = SnowAccumulationFieldScript.new() as Node3D
	accumulation_field.name = "SnowAccumulationField"
	accumulation_field.set("field_size", Vector2(17.0, 17.0))
	add_child(accumulation_field)


func create_instruction_board() -> void:
	var board := Node3D.new()
	board.name = "InstructionBoard"
	board.position = Vector3(0.0, 2.15, 7.8)
	add_child(board)
	ElementVisuals.add_box(board, "Board", Vector3(10.2, 2.6, 0.18), Color(0.035, 0.06, 0.1, 1.0), Vector3.ZERO, Vector3.ZERO, 0.25, 0.95)

	var label := Label3D.new()
	label.text = "SNOWFALL CONCENTRATION LAB\n1  Cast Snowfall   •   2  Switch to Ice Lance   •   3  Cast freely\nWatch frost gather, the basin freeze, footprints form, and the brazier weaken.\nFire can melt accumulated snow and basin ice. Cast Snowfall again to release it."
	label.position = Vector3(0.0, 0.0, 0.11)
	label.font_size = 27
	label.pixel_size = 0.0058
	label.outline_size = 5
	label.modulate = Color(0.78, 0.92, 1.0, 1.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(label)


func create_weather_probe(label_text: String, position_value: Vector3) -> void:
	var probe: Node3D = WeatherExposureProbeScript.new() as Node3D
	probe.name = label_text.replace(" ", "")
	probe.position = position_value
	probe.set("probe_label", label_text)
	probe.set("snow_exposure_to_freeze", 1.2)
	add_child(probe)


func create_burning_brazier(position_value: Vector3) -> void:
	brazier_root = Node3D.new()
	brazier_root.name = "SnowExposedBrazier"
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
	label.text = "SNOW-EXPOSED FIRE\nRepeated cold should extinguish this"
	label.position = Vector3(0.0, 2.4, 0.0)
	label.font_size = 28
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	label.modulate = Color(1.0, 0.58, 0.24, 1.0)
	brazier_root.add_child(label)


func create_phase_basin(position_value: Vector3) -> void:
	phase_basin = SnowPhaseBasinScript.new() as Node3D
	phase_basin.name = "SnowPhaseBasin"
	phase_basin.position = position_value
	phase_basin.set("basin_label", "SNOW PHASE BASIN")
	add_child(phase_basin)


func create_spell_cost_readout(position_value: Vector3) -> void:
	spell_cost_label = Label3D.new()
	spell_cost_label.name = "SpellCostReadout"
	spell_cost_label.position = position_value
	spell_cost_label.font_size = 27
	spell_cost_label.pixel_size = 0.0065
	spell_cost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spell_cost_label.outline_size = 5
	spell_cost_label.modulate = Color(0.76, 0.9, 1.0, 1.0)
	add_child(spell_cost_label)

	source_label = Label3D.new()
	source_label.name = "AtmosphericSourceReadout"
	source_label.position = Vector3(5.9, 2.1, 4.8)
	source_label.font_size = 28
	source_label.pixel_size = 0.0065
	source_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	source_label.outline_size = 5
	add_child(source_label)


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


func update_readouts() -> void:
	var snowing: bool = weather_controller != null and bool(weather_controller.get("active"))
	var current_mana: int = GameState.get_stat("mana")
	var maximum_mana: int = GameState.get_stat("max_mana")
	var usable_cap: int = maximum_mana
	var reserved: int = 0
	if concentration_manager != null and concentration_manager.has_method("get_usable_mana_cap"):
		usable_cap = int(concentration_manager.call("get_usable_mana_cap"))
		reserved = int(concentration_manager.call("get_reserved_mana"))

	var ice_cost: int = get_spell_cost("ice_lance")
	var water_cost: int = get_spell_cost("water_jet")
	var fire_cost: int = get_spell_cost("firebolt")
	var coverage: float = float(accumulation_field.get("coverage")) if accumulation_field != null else 0.0
	var basin_frozen: bool = bool(phase_basin.call("is_frozen")) if phase_basin != null and phase_basin.has_method("is_frozen") else false
	var brazier_burning: bool = bool(brazier_combustion.get("burning")) if brazier_combustion != null else false

	if spell_cost_label != null:
		spell_cost_label.text = (
			("SNOWFALL ACTIVE" if snowing else "SNOWFALL DORMANT")
			+ "\nMana: " + str(current_mana) + " / " + str(usable_cap)
			+ " usable   •   " + str(reserved) + " reserved"
			+ "\nIce Lance: " + ("FREE" if ice_cost <= 0 else str(ice_cost) + " mana")
			+ "   •   Water: " + str(water_cost) + "   •   Fire: " + str(fire_cost)
			+ "\nSnow cover: " + str(int(round(coverage * 100.0))) + "%"
			+ "   •   Basin: " + ("FROZEN" if basin_frozen else "WATER")
			+ "   •   Fire: " + ("BURNING" if brazier_burning else "OUT")
		)
		spell_cost_label.modulate = Color(0.72, 0.94, 1.0, 1.0) if snowing else Color(0.72, 0.78, 0.86, 1.0)

	if source_label != null:
		source_label.text = (
			"ATMOSPHERIC ICE SOURCE\n"
			+ ("INFINITE WHILE SNOW FALLS" if snowing else "INACTIVE")
		)
		source_label.modulate = Color(0.68, 0.94, 1.0, 1.0) if snowing else Color(0.56, 0.6, 0.66, 1.0)


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
	GameState.set_objective("Snowfall is active. Ice spells are free; watch cold accumulate across the laboratory.")
	update_readouts()


func _on_weather_stopped(_weather_id: String) -> void:
	GameState.set_objective("Snowfall dismissed. The full mana capacity is available for regeneration again.")
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
		brazier_thermal.call("set_temperature", 230.0, "Snow Lab Reset")
	if brazier_combustion != null and brazier_combustion.has_method("force_ignite"):
		brazier_combustion.call("force_ignite", "Snow Lab Reset")

	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
	configure_player()
	GameState.set_objective("Cast Snowfall, test the reserved mana ceiling, and use the frozen sky as an infinite Ice source.")
	show_message("Snowfall Laboratory reset #" + str(reset_count) + ".")
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
		"snow_weather_lab": true,
		"snowing": weather_controller != null and bool(weather_controller.get("active")),
		"mana": GameState.get_stat("mana"),
		"max_mana": GameState.get_stat("max_mana"),
		"ice_cost": get_spell_cost("ice_lance"),
		"fire_cost": get_spell_cost("firebolt"),
		"snow_coverage": float(accumulation_field.get("coverage")) if accumulation_field != null else 0.0,
		"basin_frozen": bool(phase_basin.call("is_frozen")) if phase_basin != null and phase_basin.has_method("is_frozen") else false,
		"reset_count": reset_count,
	}
