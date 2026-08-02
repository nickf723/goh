extends Area3D
class_name RecordedObjectBlueprintStation

@export var blueprint_id: String = "crate"
@export var prompt_text: String = "Record object"
@export var manager_path: NodePath
@export var auto_select_after_recording: bool = true

var manager: RecordedObjectManager
var label: Label3D
var base_mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("recorded_object_blueprint_station")
	add_to_group("debuggable")
	manager = get_node_or_null(manager_path) as RecordedObjectManager if manager_path != NodePath() else null
	if manager == null:
		manager = get_tree().get_first_node_in_group("recorded_object_manager") as RecordedObjectManager
	_build_collision()
	_build_visual()
	_refresh_visual()


func interact() -> Dictionary:
	if manager == null or not is_instance_valid(manager):
		manager = get_tree().get_first_node_in_group("recorded_object_manager") as RecordedObjectManager
	if manager == null:
		return {"message": "The recording lattice is not connected.", "objective": ""}
	var was_recorded: bool = RecordedObjectCatalog.is_recorded(blueprint_id)
	var result: Dictionary = manager.record_blueprint(blueprint_id)
	if auto_select_after_recording:
		manager.select_blueprint(blueprint_id)
	_refresh_visual()
	var definition: Dictionary = RecordedObjectCatalog.get_definition(blueprint_id)
	if was_recorded and bool(result.get("ok", false)):
		manager.begin_placement()
		return {
			"message": (
				"Placing "
				+ str(definition.get("display_name", blueprint_id.capitalize()))
				+ ". A confirms, B cancels, and L/R cycle while placement is active."
			),
			"objective": "Aim the placement preview at a valid surface.",
		}
	return {
		"message": (
			"Recorded "
			+ str(definition.get("display_name", blueprint_id.capitalize()))
			+ ". Interact with this station again to begin placement."
		),
		"objective": "Test the recorded object in the proving ground.",
	}


func _build_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 0.85
	shape.height = 1.6
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	var definition: Dictionary = RecordedObjectCatalog.get_definition(blueprint_id)
	var color: Color = definition.get("color", Color(0.5, 0.8, 1.0, 1.0)) as Color
	base_mesh = MeshInstance3D.new()
	base_mesh.name = "StationPedestal"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.72
	cylinder.bottom_radius = 0.86
	cylinder.height = 1.1
	cylinder.radial_segments = 18
	base_mesh.mesh = cylinder
	base_mesh.position.y = 0.55
	base_mesh.material_override = _make_material(color.darkened(0.45))
	add_child(base_mesh)

	var hologram := MeshInstance3D.new()
	hologram.name = "BlueprintHologram"
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	if str(definition.get("behavior", "")) == "blast_barrel":
		var barrel := CylinderMesh.new()
		barrel.top_radius = 0.32
		barrel.bottom_radius = 0.34
		barrel.height = 0.78
		barrel.radial_segments = 14
		hologram.mesh = barrel
	else:
		var box := BoxMesh.new()
		box.size = size.normalized() * 0.9
		hologram.mesh = box
	hologram.position.y = 1.55
	hologram.material_override = _make_hologram_material(color)
	add_child(hologram)

	label = Label3D.new()
	label.name = "StationLabel"
	label.position = Vector3(0.0, 2.55, 0.0)
	label.font_size = 38
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.modulate = color
	add_child(label)


func _refresh_visual() -> void:
	if label == null:
		return
	var definition: Dictionary = RecordedObjectCatalog.get_definition(blueprint_id)
	var recorded: bool = RecordedObjectCatalog.is_recorded(blueprint_id)
	var selected: bool = RecordedObjectCatalog.get_selected_blueprint_id() == blueprint_id
	label.text = (
		str(definition.get("icon", "▣"))
		+ "  "
		+ str(definition.get("short_name", blueprint_id.capitalize())).to_upper()
		+ "\n"
		+ ("SELECTED • INTERACT TO PLACE" if selected else ("RECORDED • INTERACT TO PLACE" if recorded else "RECORD BLUEPRINT"))
	)


func get_debug_data() -> Dictionary:
	return {
		"blueprint_id": blueprint_id,
		"recorded": RecordedObjectCatalog.is_recorded(blueprint_id),
		"selected": RecordedObjectCatalog.get_selected_blueprint_id() == blueprint_id,
		"manager_ready": manager != null and is_instance_valid(manager),
	}


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.25
	material.roughness = 0.55
	return material


func _make_hologram_material(color: Color) -> StandardMaterial3D:
	var material := _make_material(Color(color.r, color.g, color.b, 0.52))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	return material
