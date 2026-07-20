extends Node3D
class_name FireGalleryWing

const ThermalStateScript = preload("res://scripts/physics/thermal_state.gd")
const CombustionStateScript = preload("res://scripts/physics/combustion_state.gd")
const CombustionPresenterScript = preload("res://scripts/presentation/combustion_presenter.gd")
const FireRendererScript = preload("res://scripts/presentation/procedural_fire_renderer.gd")
const FireEventScript = preload("res://scripts/presentation/fire_vfx_event.gd")
const FireProfileScript = preload("res://scripts/presentation/fire_presentation_profile.gd")
const FireConsoleScript = preload("res://scripts/levels/fire_gallery_console.gd")

@export var readout_interval: float = 0.08

var gallery: ElementVfxGallery
var renderer: Node3D
var exhibit: VfxGalleryExhibit
var readout: Label3D
var initialized: bool = false
var local_auto_enabled: bool = true
var readout_timer: float = 0.0
var manual_trigger_count: int = 0
var wind_index: int = 0
var extinguish_sequence_id: int = 0
var stations: Dictionary = {}
var burst_origin: Node3D
var wind_vectors: Array[Vector3] = [
	Vector3.ZERO,
	Vector3(3.5, 0.0, 0.0),
	Vector3(-3.5, 0.0, 1.2),
	Vector3(1.0, 0.0, -4.5),
]


func _ready() -> void:
	add_to_group("fire_gallery_wing")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	call_deferred("initialize_wing")


func initialize_wing() -> void:
	gallery = get_parent() as ElementVfxGallery
	if gallery == null:
		push_warning("Fire Gallery Wing requires ElementVfxGallery as its parent.")
		return
	build_stage()
	build_exhibit()
	activate_fire_bay()
	initialized = true
	set_auto_play(true)
	update_readout()


func _process(delta: float) -> void:
	if not initialized:
		return
	if gallery != null and exhibit != null:
		var desired_auto: bool = gallery.auto_replay_enabled and local_auto_enabled
		if exhibit.auto_play != desired_auto:
			exhibit.set_auto_play(desired_auto)
	readout_timer -= max(delta, 0.0)
	if readout_timer <= 0.0:
		readout_timer = max(readout_interval, 0.03)
		update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_target()


func build_stage() -> void:
	renderer = FireRendererScript.new() as Node3D
	renderer.name = "ProceduralFireRenderer"
	add_child(renderer)

	ThermalLabGeometry.add_static_box(
		self,
		"FireStageFloor",
		Vector3(-11.1, 0.05, 10.2),
		Vector3(9.6, 0.7, 12.5),
		Color(0.11, 0.025, 0.012, 1.0)
	)
	ThermalLabGeometry.add_label(
		self,
		"FireWingTitle",
		"PROCEDURAL FIRE",
		Vector3(-11.1, 7.8, 5.1),
		32,
		Color(1.0, 0.42, 0.08, 1.0)
	)
	ThermalLabGeometry.add_label(
		self,
		"FireWingSubtitle",
		"FUEL • HEAT • SMOKE • EMBERS • WIND • EXTINGUISH",
		Vector3(-11.1, 7.15, 5.2),
		15,
		Color(1.0, 0.72, 0.38, 1.0)
	)

	stations["torch"] = create_combustion_station(
		"TorchStation",
		Vector3(-14.2, 0.7, 8.2),
		"torch",
		0.6,
		0.012,
		30.0,
		true,
		Vector3(0.42, 1.25, 0.42)
	)
	stations["bonfire"] = create_combustion_station(
		"BonfireStation",
		Vector3(-11.1, 0.65, 12.4),
		"bonfire",
		2.4,
		0.038,
		58.0,
		true,
		Vector3(2.0, 0.5, 2.0)
	)
	stations["wind"] = create_combustion_station(
		"WindStation",
		Vector3(-8.25, 0.7, 8.2),
		"torch",
		0.8,
		0.018,
		34.0,
		true,
		Vector3(0.8, 0.65, 0.8)
	)
	stations["burnout"] = create_combustion_station(
		"BurnoutStation",
		Vector3(-14.0, 0.65, 14.8),
		"smolder",
		0.1,
		0.035,
		24.0,
		true,
		Vector3(1.1, 0.45, 1.1)
	)
	stations["extinguish"] = create_combustion_station(
		"ExtinguishStation",
		Vector3(-8.2, 0.7, 14.8),
		"torch",
		0.9,
		0.02,
		38.0,
		true,
		Vector3(0.9, 0.55, 0.9)
	)

	burst_origin = Node3D.new()
	burst_origin.name = "FireBurstOrigin"
	burst_origin.position = Vector3(-11.1, 1.1, 7.8)
	add_child(burst_origin)
	ThermalLabGeometry.add_box_visual(
		burst_origin,
		"BurstPedestal",
		Vector3(1.3, 0.4, 1.3),
		Color(0.35, 0.08, 0.02, 1.0),
		true,
		1.4
	)

	readout = ThermalLabGeometry.add_label(
		self,
		"FireReadout",
		"FIRE ENGINE",
		Vector3(-11.1, 4.35, 5.35),
		18,
		Color(1.0, 0.78, 0.48, 1.0)
	)
	add_console("TriggerConsole", "trigger", "TRIGGER", Vector3(-14.1, 0.85, 3.8), Color(0.72, 0.12, 0.02, 1.0))
	add_console("CycleConsole", "cycle", "NEXT TYPE", Vector3(-12.1, 0.85, 3.8), Color(0.92, 0.25, 0.03, 1.0))
	add_console("WindConsole", "wind", "WIND", Vector3(-10.1, 0.85, 3.8), Color(0.95, 0.45, 0.06, 1.0))
	add_console("DouseConsole", "extinguish", "DOUSE", Vector3(-8.1, 0.85, 3.8), Color(0.12, 0.38, 0.62, 1.0))
	add_console("ClearConsole", "clear", "CLEAR", Vector3(-6.1, 0.85, 3.8), Color(0.35, 0.09, 0.04, 1.0))


func create_combustion_station(
	node_name: String,
	position_value: Vector3,
	profile_kind: String,
	fuel_kg: float,
	burn_rate: float,
	heat_output: float,
	starts_ignited: bool,
	body_size: Vector3
) -> Dictionary:
	var root := Node3D.new()
	root.name = node_name
	root.position = position_value
	ThermalLabGeometry.add_box_visual(
		root,
		"CombustibleBody",
		body_size,
		Color(0.28, 0.095, 0.025, 1.0),
		false,
		0.0
	)
	var thermal: Node = ThermalStateScript.new()
	thermal.name = "ThermalState"
	thermal.starting_temperature_c = 210.0 if starts_ignited else 20.0
	thermal.ambient_temperature_c = 20.0
	thermal.heat_capacity_override_j_per_c = 7.0
	thermal.passive_ambient_exchange = false
	thermal.ignition_enabled = true
	thermal.use_material_ignition_point = false
	thermal.ignition_temperature_c = 180.0
	root.add_child(thermal)

	var combustion: Node = CombustionStateScript.new()
	combustion.name = "CombustionState"
	combustion.combustible_override = true
	combustion.initial_fuel_kg_override = fuel_kg
	combustion.ignition_temperature_c_override = 180.0
	combustion.sustain_temperature_c_override = 110.0
	combustion.burn_rate_kg_per_second_override = burn_rate
	combustion.heat_output_j_per_second_override = heat_output
	combustion.smoke_yield_override = 0.62
	combustion.ember_yield_override = 0.52
	combustion.starts_ignited = starts_ignited
	root.add_child(combustion)

	var presenter: Node3D = CombustionPresenterScript.new() as Node3D
	presenter.name = "CombustionPresenter"
	presenter.profile_kind = profile_kind
	presenter.visual_offset = Vector3(0.0, body_size.y * 0.48, 0.0)
	presenter.visual_scale = 1.0
	root.add_child(presenter)
	add_child(root)
	return {
		"root": root,
		"thermal": thermal,
		"combustion": combustion,
		"presenter": presenter,
	}


func build_exhibit() -> void:
	exhibit = VfxGalleryExhibit.new()
	exhibit.name = "FireExhibit"
	exhibit.auto_interval_seconds = 2.4
	exhibit.configure(
		"fire_engine",
		"fire",
		"Procedural Fire",
		"Fuel-driven flame, smoke, embers, wind response, smolder, and extinguishing.",
		["torch", "bonfire", "wind", "burnout", "extinguish", "burst"],
		Color(1.0, 0.28, 0.03, 1.0),
		Callable(self, "trigger_fire_exhibit")
	)
	add_child(exhibit)


func trigger_fire_exhibit(
	_exhibit: VfxGalleryExhibit,
	effect_kind: String,
	_requested_intensity: float
) -> bool:
	var accepted: bool = false
	match effect_kind:
		"torch":
			accepted = ignite_station("torch")
		"bonfire":
			accepted = ignite_station("bonfire")
		"wind":
			accepted = cycle_wind()
		"burnout":
			accepted = restart_burnout()
		"extinguish":
			accepted = start_extinguish_sequence()
		"burst":
			accepted = render_fire_burst()
		_:
			return false
	if accepted and exhibit != null and exhibit.auto_play:
		exhibit.cycle_kind()
	return accepted


func ignite_station(station_id: String) -> bool:
	var station: Dictionary = stations.get(station_id, {}) as Dictionary
	var combustion: Node = station.get("combustion") as Node
	if combustion == null:
		return false
	if str(combustion.state) in ["spent", "extinguished"]:
		combustion.reset_target()
	return bool(combustion.force_ignite("Gallery " + station_id.capitalize()))


func cycle_wind() -> bool:
	var station: Dictionary = stations.get("wind", {}) as Dictionary
	var combustion: Node = station.get("combustion") as Node
	if combustion == null:
		return false
	wind_index = posmod(wind_index + 1, wind_vectors.size())
	combustion.set_airflow(wind_vectors[wind_index])
	combustion.force_ignite("Gallery Wind")
	return true


func restart_burnout() -> bool:
	var station: Dictionary = stations.get("burnout", {}) as Dictionary
	var thermal: Node = station.get("thermal") as Node
	var combustion: Node = station.get("combustion") as Node
	if thermal == null or combustion == null:
		return false
	thermal.set_temperature(210.0, "Gallery Burnout")
	combustion.reset_target()
	combustion.force_ignite("Gallery Burnout")
	return true


func start_extinguish_sequence() -> bool:
	var station: Dictionary = stations.get("extinguish", {}) as Dictionary
	var combustion: Node = station.get("combustion") as Node
	if combustion == null:
		return false
	combustion.reset_target()
	combustion.force_ignite("Gallery Extinguish")
	extinguish_sequence_id += 1
	var sequence_id: int = extinguish_sequence_id
	var timer := get_tree().create_timer(0.65)
	timer.timeout.connect(func() -> void:
		if sequence_id != extinguish_sequence_id or not is_instance_valid(combustion):
			return
		combustion.apply_extinguish(1.2, 760.0, "Gallery Water")
	, CONNECT_ONE_SHOT)
	return true


func render_fire_burst() -> bool:
	if renderer == null or burst_origin == null:
		return false
	var event: RefCounted = FireEventScript.make(
		FireEventScript.KIND_BURST,
		burst_origin.global_position + Vector3.UP * 0.35,
		get_gallery_intensity(),
		0.75,
		"gallery_fire_burst",
		["gallery", "fire", "burst"]
	)
	event.smoke_strength = 0.48
	event.ember_strength = 1.25
	event.duration_seconds = 1.1
	event.wind_velocity = wind_vectors[wind_index]
	var profile: Resource = FireProfileScript.new()
	profile.apply_kind("bonfire")
	profile.flame_height = 2.2
	profile.flame_radius = 0.8
	profile.effect_lifetime = 1.2
	renderer.render_event(event, profile)
	return true


func handle_fire_action(action_id: String) -> Dictionary:
	var message: String = ""
	match action_id:
		"trigger":
			if exhibit != null and exhibit.trigger_preview(get_gallery_intensity()):
				manual_trigger_count += 1
				message = "Fire preview: " + exhibit.last_effect_kind.to_upper()
			else:
				message = "The Fire exhibit did not respond."
		"cycle":
			message = "Fire type selected: " + exhibit.cycle_kind().to_upper()
		"wind":
			cycle_wind()
			message = "Airflow: " + str(wind_vectors[wind_index])
		"extinguish":
			start_extinguish_sequence()
			message = "The extinguish specimen ignites, then receives a cooling pulse."
		"clear":
			if renderer != null:
				renderer.reset_target()
			message = "Transient Fire effects cleared."
		_:
			message = "Unknown Fire control: " + action_id
	update_readout()
	return {
		"message": message,
		"objective": "Compare generated flame, smoke, embers, wind response, fuel loss, and extinguishing.",
	}


func set_auto_play(enabled: bool) -> void:
	local_auto_enabled = enabled
	if exhibit != null:
		exhibit.set_auto_play(enabled and (gallery == null or gallery.auto_replay_enabled))


func reset_target() -> void:
	extinguish_sequence_id += 1
	wind_index = 0
	manual_trigger_count = 0
	if renderer != null:
		renderer.reset_target()
	for station_id: String in stations.keys():
		var station: Dictionary = stations[station_id] as Dictionary
		var thermal: Node = station.get("thermal") as Node
		var combustion: Node = station.get("combustion") as Node
		var presenter: Node = station.get("presenter") as Node
		if thermal != null:
			thermal.reset_target()
		if combustion != null:
			combustion.reset_target()
			combustion.set_airflow(Vector3.ZERO)
		if presenter != null and presenter.has_method("reset_target"):
			presenter.reset_target()
	if exhibit != null:
		exhibit.reset_target()
	if initialized:
		set_auto_play(true)
	update_readout()


func update_readout() -> void:
	if readout == null or exhibit == null:
		return
	var torch_data: Dictionary = get_station_debug("torch")
	var bonfire_data: Dictionary = get_station_debug("bonfire")
	var burnout_data: Dictionary = get_station_debug("burnout")
	readout.text = (
		"FIRE ENGINE"
		+ "\nSELECTED: " + exhibit.get_current_kind().to_upper()
		+ "  AUTO: " + ("ON" if exhibit.auto_play else "OFF")
		+ "\nTORCH: " + str(torch_data.get("state", "?")) + "  " + str(torch_data.get("fuel_ratio", 0.0))
		+ "  BONFIRE: " + str(bonfire_data.get("state", "?"))
		+ "\nBURNOUT: " + str(burnout_data.get("state", "?"))
		+ "  WIND: " + str(wind_vectors[wind_index])
		+ "  FX: " + str(renderer.rendered_count if renderer != null else 0)
	)


func get_station_debug(station_id: String) -> Dictionary:
	var station: Dictionary = stations.get(station_id, {}) as Dictionary
	var combustion: Node = station.get("combustion") as Node
	if combustion != null and combustion.has_method("get_debug_data"):
		return combustion.get_debug_data()
	return {}


func get_gallery_intensity() -> float:
	return gallery.get_intensity() if gallery != null else 1.0


func activate_fire_bay() -> void:
	for raw_bay: Node in get_tree().get_nodes_in_group("vfx_gallery_element_bays"):
		var bay := raw_bay as Node3D
		if bay == null or str(bay.get_meta("element_id", "")) != "fire":
			continue
		bay.set_meta("active", true)
		var pylon := bay.get_node_or_null("Pylon") as MeshInstance3D
		if pylon != null:
			pylon.material_override = ThermalLabGeometry.make_material(Color(1.0, 0.14, 0.015, 1.0), true, 4.2)
		var label := bay.get_node_or_null("Label") as Label3D
		if label != null:
			label.modulate = Color(1.0, 0.45, 0.12, 1.0)


func add_console(
	node_name: String,
	action_id: String,
	label_text: String,
	position_value: Vector3,
	color: Color
) -> Area3D:
	var console := FireConsoleScript.new() as Area3D
	console.name = node_name
	console.action_id = action_id
	console.prompt_text = label_text
	console.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.65, 0.8, 1.0)
	collision.shape = shape
	console.add_child(collision)
	ThermalLabGeometry.add_box_visual(console, "ConsoleVisual", Vector3(1.65, 0.8, 1.0), color, true, 1.8)
	ThermalLabGeometry.add_label(console, "ConsoleLabel", label_text, Vector3(0.0, 0.75, 0.0), 14, Color.WHITE)
	add_child(console)
	return console


func get_debug_data() -> Dictionary:
	return {
		"fire_gallery_wing": true,
		"initialized": initialized,
		"auto_enabled": local_auto_enabled,
		"manual_triggers": manual_trigger_count,
		"wind": wind_vectors[wind_index],
		"stations": stations.size(),
		"exhibit": exhibit.get_debug_data() if exhibit != null else {},
		"renderer": renderer.get_debug_data() if renderer != null and renderer.has_method("get_debug_data") else {},
		"torch": get_station_debug("torch"),
		"bonfire": get_station_debug("bonfire"),
		"burnout": get_station_debug("burnout"),
	}
