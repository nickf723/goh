extends Area3D
class_name EngineeringBuildStation

const Catalog = preload("res://scripts/builds/engineering_build_catalog.gd")

@export var build_id: String = "bridge_frame"
@export var prompt_text: String = "Save construction"
@export var station_color: Color = Color(0.34, 0.68, 0.94, 1.0)

var label: Label3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("engineering_build_station")
	add_to_group("debuggable")
	_build_collision()
	_build_visuals()
	_refresh_label()


func interact() -> Dictionary:
	var manager: EngineeringBuildManager = get_tree().get_first_node_in_group(
		"engineering_build_manager"
	) as EngineeringBuildManager
	if manager == null:
		return {
			"message": "The construction station cannot find Grace's build manager.",
			"objective": "",
		}
	var was_saved: bool = Catalog.is_saved(build_id)
	var result: Dictionary = manager.save_build(build_id)
	_refresh_label()
	if bool(result.get("ok", false)):
		var definition: Dictionary = Catalog.get_definition(build_id)
		if was_saved:
			manager.select_build(build_id)
			manager.begin_placement()
			return {
				"message": (
					"Placing "
					+ str(definition.get("display_name", build_id.capitalize()))
					+ ". A confirms, B cancels, and L/R cycle while placement is active."
				),
				"objective": "Aim the construction preview at a valid surface.",
			}
		return {
			"message": (
				"Construction saved: "
				+ str(definition.get("display_name", build_id.capitalize()))
				+ ". Interact with this station again to begin placement."
			),
			"objective": str(definition.get("test_prompt", "Test the construction.")),
		}
	var missing: Array = result.get("missing", []) as Array
	return {
		"message": "Missing recorded components: " + (", ".join(missing) if not missing.is_empty() else "unknown"),
		"objective": "Record the component objects before saving this construction.",
	}


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 1.5
	collision.shape = shape
	add_child(collision)


func _build_visuals() -> void:
	var pedestal := MeshInstance3D.new()
	pedestal.name = "BuildStationPedestal"
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.82
	pedestal_mesh.bottom_radius = 1.0
	pedestal_mesh.height = 1.0
	pedestal_mesh.radial_segments = 20
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.5
	pedestal.material_override = _make_material(station_color.darkened(0.55))
	add_child(pedestal)

	var hologram := MeshInstance3D.new()
	hologram.name = "BuildHologram"
	var hologram_mesh := BoxMesh.new()
	hologram_mesh.size = Vector3(1.35, 0.16, 0.9)
	hologram.mesh = hologram_mesh
	hologram.position.y = 1.45
	hologram.rotation_degrees.y = 18.0
	hologram.material_override = _make_transparent_material(
		Color(station_color.r, station_color.g, station_color.b, 0.64)
	)
	add_child(hologram)

	label = Label3D.new()
	label.name = "BuildStationLabel"
	label.position = Vector3(0.0, 2.7, 0.0)
	label.font_size = 32
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = station_color
	add_child(label)


func _refresh_label() -> void:
	if label == null:
		return
	var definition: Dictionary = Catalog.get_definition(build_id)
	var state: String = "SAVED • INTERACT TO PLACE" if Catalog.is_saved(build_id) else "UNSAVED"
	var missing: Array[String] = Catalog.get_missing_requirements(build_id)
	if not missing.is_empty():
		state = "NEEDS " + ", ".join(missing)
	label.text = (
		str(definition.get("icon", "⚙"))
		+ "  "
		+ str(definition.get("display_name", build_id.capitalize())).to_upper()
		+ "\n"
		+ state
		+ "\n"
		+ prompt_text
	)


func get_debug_data() -> Dictionary:
	return {
		"build_id": build_id,
		"saved": Catalog.is_saved(build_id),
		"requirements_met": Catalog.requirements_met(build_id),
		"missing": Catalog.get_missing_requirements(build_id),
	}


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.32
	material.roughness = 0.46
	material.emission_enabled = true
	material.emission = color.darkened(0.35)
	material.emission_energy_multiplier = 0.7
	return material


func _make_transparent_material(color: Color) -> StandardMaterial3D:
	var material := _make_material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material
