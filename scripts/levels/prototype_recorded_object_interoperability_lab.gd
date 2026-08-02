extends "res://scripts/levels/prototype_recorded_object_lab.gd"
class_name PrototypeRecordedObjectInteroperabilityLab

const PayloadConsoleScript = preload(
	"res://scripts/interaction/recorded_object_payload_console.gd"
)
const Catalog = preload("res://scripts/objects/recorded_object_catalog.gd")

var interoperability_root: Node3D
var interaction_pad_position: Vector3 = Vector3(0.0, 0.0, 10.0)
var water_basin: FluidForceVolume


func _ready() -> void:
	super._ready()
	_build_interoperability_wing()
	_show_message(
		"Interoperability Wing ready. F5 places the selected recorded object on the elemental pad."
	)


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F5:
		place_selected_on_interaction_pad()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F6:
		place_crate_in_water_basin()
		get_viewport().set_input_as_handled()


func _build_interoperability_wing() -> void:
	interoperability_root = Node3D.new()
	interoperability_root.name = "InteroperabilityWing"
	add_child(interoperability_root)

	_create_static_box(
		"InteroperabilityDeck",
		Vector3(0.0, 0.05, 10.0),
		Vector3(13.0, 0.32, 7.0),
		Color(0.07, 0.11, 0.17, 1.0),
		interoperability_root
	)
	_create_label(
		"ELEMENTAL INTEROPERABILITY",
		Vector3(0.0, 5.0, 10.0),
		Color(0.72, 0.88, 1.0, 1.0),
		38,
		interoperability_root
	)
	_create_label(
		"F5 PLACE SELECTED OBJECT ON PAD",
		Vector3(0.0, 3.6, 10.0),
		Color(0.64, 0.74, 0.88, 1.0),
		24,
		interoperability_root
	)

	var pad := MeshInstance3D.new()
	pad.name = "ElementalInteractionPad"
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 1.75
	pad_mesh.bottom_radius = 1.9
	pad_mesh.height = 0.16
	pad_mesh.radial_segments = 32
	pad.mesh = pad_mesh
	pad.position = interaction_pad_position + Vector3.UP * 0.24
	pad.material_override = _make_wing_material(Color(0.18, 0.34, 0.52, 1.0))
	interoperability_root.add_child(pad)

	_create_payload_console(
		"FireConsole",
		Vector3(-5.0, 0.2, 8.0),
		"fire",
		"FIRE",
		Color(1.0, 0.3, 0.08, 1.0),
		3,
		1.0,
		0.0,
		["heat", "ignite"]
	)
	_create_payload_console(
		"WaterConsole",
		Vector3(-2.5, 0.2, 7.2),
		"water",
		"WATER",
		Color(0.18, 0.64, 1.0, 1.0),
		3,
		1.0,
		0.0,
		["douse", "extinguish"]
	)
	_create_payload_console(
		"IceConsole",
		Vector3(0.0, 0.2, 6.9),
		"ice",
		"ICE",
		Color(0.56, 0.94, 1.0, 1.0),
		4,
		1.2,
		0.0,
		["cold", "freeze"]
	)
	_create_payload_console(
		"LightningConsole",
		Vector3(2.5, 0.2, 7.2),
		"lightning",
		"LIGHTNING",
		Color(1.0, 0.86, 0.2, 1.0),
		3,
		1.0,
		0.0,
		["electrical", "conduct"]
	)
	_create_payload_console(
		"ForceConsole",
		Vector3(5.0, 0.2, 8.0),
		"neutral",
		"FORCE",
		Color(0.88, 0.72, 1.0, 1.0),
		4,
		1.0,
		8.0,
		["heavy", "force", "impact"]
	)

	_build_water_basin()


func _build_water_basin() -> void:
	_create_static_box(
		"WaterBasinFloor",
		Vector3(-9.0, -1.85, -11.0),
		Vector3(7.0, 0.4, 7.0),
		Color(0.035, 0.06, 0.1, 1.0),
		interoperability_root
	)
	for wall_data: Dictionary in [
		{"position": Vector3(-12.4, -0.75, -11.0), "size": Vector3(0.35, 2.5, 7.0)},
		{"position": Vector3(-5.6, -0.75, -11.0), "size": Vector3(0.35, 2.5, 7.0)},
		{"position": Vector3(-9.0, -0.75, -14.4), "size": Vector3(7.0, 2.5, 0.35)},
		{"position": Vector3(-9.0, -0.75, -7.6), "size": Vector3(7.0, 2.5, 0.35)},
	]:
		_create_static_box(
			"WaterBasinWall",
			wall_data["position"] as Vector3,
			wall_data["size"] as Vector3,
			Color(0.08, 0.13, 0.19, 1.0),
			interoperability_root
		)

	water_basin = FluidForceVolume.new()
	water_basin.name = "RecordedObjectWaterBasin"
	water_basin.position = Vector3(-9.0, -0.6, -11.0)
	water_basin.volume_size = Vector3(6.4, 2.4, 6.4)
	water_basin.fluid_density_kg_m3 = 1000.0
	water_basin.buoyancy_multiplier = 1.0
	water_basin.shallow_color = Color(0.1, 0.62, 0.9, 0.66)
	water_basin.deep_color = Color(0.015, 0.12, 0.32, 0.86)
	interoperability_root.add_child(water_basin)

	_create_label(
		"BUOYANCY + DAMPENING\nF6 PLACES A CRATE IN WATER",
		Vector3(-9.0, 3.0, -11.0),
		Color(0.48, 0.84, 1.0, 1.0),
		28,
		interoperability_root
	)


func _create_payload_console(
	console_name: String,
	position: Vector3,
	element: String,
	label_text: String,
	color: Color,
	amount: int,
	strength: float,
	knockback: float,
	tags: Array[String]
) -> void:
	var console := Area3D.new()
	console.name = console_name
	console.set_script(PayloadConsoleScript)
	console.position = position
	console.set("element", element)
	console.set("console_label", label_text)
	console.set("payload_amount", amount)
	console.set("payload_strength", strength)
	console.set("knockback_strength", knockback)
	console.set("search_radius", 7.0)
	console.set("color", color)
	console.set("extra_tags", tags)
	interoperability_root.add_child(console)


func place_selected_on_interaction_pad() -> RecordedObjectInstance:
	if manager == null:
		return null
	if Catalog.get_selected_blueprint_id() == "":
		record_all_for_debug()
	manager.clear_spawned_objects()
	var object: RecordedObjectInstance = manager.place_selected_at(
		interaction_pad_position,
		0.0,
		true,
		true
	)
	if object != null:
		_show_message(
			str(object.definition.get("display_name", object.blueprint_id.capitalize()))
			+ " placed on the interoperability pad."
		)
	return object


func place_crate_in_water_basin() -> RecordedObjectInstance:
	if manager == null:
		return null
	if not Catalog.is_recorded("crate"):
		manager.record_blueprint("crate")
	manager.select_blueprint("crate")
	var object: RecordedObjectInstance = manager.place_selected_at(
		Vector3(-9.0, 0.15, -11.0),
		0.0,
		true,
		true
	)
	if object != null:
		_show_message("Recorded Crate dropped into the buoyancy basin.")
	return object


func _make_wing_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.32
	material.roughness = 0.45
	material.emission_enabled = true
	material.emission = color.darkened(0.42)
	material.emission_energy_multiplier = 0.55
	return material


func get_interoperability_debug_data() -> Dictionary:
	return {
		"console_count": get_tree().get_nodes_in_group(
			"recorded_object_payload_console"
		).size(),
		"has_water_basin": water_basin != null,
		"interaction_pad_position": interaction_pad_position,
		"manager_ready": manager != null,
	}
