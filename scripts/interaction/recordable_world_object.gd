extends Area3D
class_name RecordableWorldObject

@export var blueprint_id: String = "crate"
@export var prompt_text: String = "Study object"
@export var objective_after: String = ""
@export var show_label: bool = true
@export var scale_multiplier: float = 1.0

var manager: RecordedObjectManager
var label: Label3D
var visual_root: Node3D


func _ready() -> void:
	add_to_group("interactable_target")
	add_to_group("recordable_world_object")
	add_to_group("debuggable")
	manager = get_tree().get_first_node_in_group(
		"recorded_object_manager"
	) as RecordedObjectManager
	_build_collision()
	_build_visual()
	_refresh_label()


func interact() -> Dictionary:
	if manager == null or not is_instance_valid(manager):
		manager = get_tree().get_first_node_in_group(
			"recorded_object_manager"
		) as RecordedObjectManager
	if manager == null:
		return {
			"message": "Grace cannot hold the object's pattern yet.",
			"objective": objective_after,
		}
	var result: Dictionary = manager.record_blueprint(blueprint_id)
	if not bool(result.get("ok", false)):
		return {
			"message": "The object's structure refuses to resolve.",
			"objective": objective_after,
		}
	manager.select_blueprint(blueprint_id)
	GameState.set_flag("recorded_world_object_" + blueprint_id, true)
	_refresh_label()
	var definition: Dictionary = RecordedObjectCatalog.get_definition(blueprint_id)
	var newly_recorded: bool = bool(result.get("newly_recorded", false))
	return {
		"message": (
			("Blueprint recorded: " if newly_recorded else "Blueprint selected: ")
			+ str(definition.get("display_name", blueprint_id.capitalize()))
			+ ". Open Items → Objects or press V / Y to reproduce it."
		),
		"objective": objective_after,
	}


func _build_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var definition: Dictionary = RecordedObjectCatalog.get_definition(blueprint_id)
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(size.x * scale_multiplier + 0.8, 1.2),
		maxf(size.y * scale_multiplier + 1.2, 1.8),
		maxf(size.z * scale_multiplier + 0.8, 1.2)
	)
	collision.position.y = size.y * scale_multiplier * 0.5
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "RecordedSourceVisual"
	add_child(visual_root)
	var definition: Dictionary = RecordedObjectCatalog.get_definition(blueprint_id)
	var size: Vector3 = definition.get("size", Vector3.ONE) as Vector3 * scale_multiplier
	var color: Color = definition.get("color", Color(0.5, 0.75, 1.0, 1.0)) as Color
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SourceObjectMesh"
	if str(definition.get("behavior", "")) == "blast_barrel":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.48
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		cylinder.radial_segments = 18
		mesh_instance.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
	mesh_instance.position.y = size.y * 0.5
	mesh_instance.material_override = _make_material(color)
	visual_root.add_child(mesh_instance)

	if blueprint_id == "crate":
		for offset: Vector3 in [
			Vector3(0.0, size.y * 0.5, size.z * 0.51),
			Vector3(0.0, size.y * 0.5, -size.z * 0.51),
		]:
			var brace := MeshInstance3D.new()
			var brace_mesh := BoxMesh.new()
			brace_mesh.size = Vector3(size.x * 0.82, 0.12, 0.08)
			brace.mesh = brace_mesh
			brace.position = offset
			brace.rotation_degrees.z = 28.0 if offset.z > 0.0 else -28.0
			brace.material_override = _make_material(color.darkened(0.38))
			visual_root.add_child(brace)
	elif blueprint_id == "platform":
		for x_offset: float in [-size.x * 0.38, 0.0, size.x * 0.38]:
			var slat := MeshInstance3D.new()
			var slat_mesh := BoxMesh.new()
			slat_mesh.size = Vector3(0.09, size.y * 1.35, size.z * 0.94)
			slat.mesh = slat_mesh
			slat.position = Vector3(x_offset, size.y * 0.52, 0.0)
			slat.material_override = _make_material(color.lightened(0.12))
			visual_root.add_child(slat)

	if show_label:
		label = Label3D.new()
		label.name = "RecordableLabel"
		label.position = Vector3(0.0, size.y + 1.05, 0.0)
		label.font_size = 32
		label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 7
		label.modulate = color.lightened(0.22)
		add_child(label)


func _refresh_label() -> void:
	if label == null:
		return
	var definition: Dictionary = RecordedObjectCatalog.get_definition(blueprint_id)
	var recorded: bool = RecordedObjectCatalog.is_recorded(blueprint_id)
	label.text = (
		str(definition.get("icon", "▣"))
		+ "  "
		+ str(definition.get("short_name", blueprint_id.capitalize())).to_upper()
		+ "\n"
		+ ("RECORDED" if recorded else "STUDY PATTERN")
	)


func get_debug_data() -> Dictionary:
	return {
		"blueprint_id": blueprint_id,
		"recorded": RecordedObjectCatalog.is_recorded(blueprint_id),
		"manager_ready": manager != null and is_instance_valid(manager),
		"natural_source": true,
	}


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.08
	material.roughness = 0.72
	return material
