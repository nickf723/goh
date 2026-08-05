extends Node
class_name LabResourceRegeneratorInstaller

const RegeneratorScript: Script = preload(
	"res://scripts/systems/lab_resource_regenerator.gd"
)
const EXPLICIT_LAB_GROUP: StringName = &"lab_resource_regeneration"

@export var install_automatically: bool = true
@export var print_debug: bool = false

var installed_regenerator: LabResourceRegenerator
var checked_scene_instance_id: int = 0
var install_count: int = 0
var reused_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("lab_resource_regenerator_installers")
	add_to_group("debuggable")
	if install_automatically:
		call_deferred("install_for_current_scene")


func install_for_current_scene() -> LabResourceRegenerator:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	return install_for_scene(scene)


func install_for_scene(scene: Node) -> LabResourceRegenerator:
	if scene == null or not is_instance_valid(scene):
		return null
	checked_scene_instance_id = scene.get_instance_id()
	if not is_lab_scene(scene):
		return null

	var existing: LabResourceRegenerator = _find_existing_regenerator(scene)
	if existing != null:
		installed_regenerator = existing
		reused_count += 1
		if print_debug:
			print("Reusing lab resource regenerator: ", existing.get_path())
		return installed_regenerator

	var regenerator := RegeneratorScript.new() as LabResourceRegenerator
	regenerator.name = "LabResourceRegenerator"
	scene.add_child(regenerator)
	installed_regenerator = regenerator
	install_count += 1
	if print_debug:
		print("Installed lab resource regenerator in ", scene.get_path())
	return installed_regenerator


func is_lab_scene(scene: Node) -> bool:
	if scene == null or not is_instance_valid(scene):
		return false
	if scene.is_in_group(EXPLICIT_LAB_GROUP):
		return true
	return matches_lab_identity(scene.scene_file_path, str(scene.name))


func matches_lab_identity(scene_path: String, root_name: String) -> bool:
	var normalized_path: String = scene_path.to_lower().replace("\\", "/")
	if normalized_path.contains("/tests/"):
		return false
	if not normalized_path.contains("/levels/"):
		return false
	var filename: String = normalized_path.get_file()
	var normalized_name: String = root_name.to_lower().strip_edges()
	return filename.contains("lab") or normalized_name.contains("lab")


func _find_existing_regenerator(scene: Node) -> LabResourceRegenerator:
	for candidate: Node in get_tree().get_nodes_in_group("lab_resource_regenerators"):
		if not (candidate is LabResourceRegenerator):
			continue
		if candidate == scene or scene.is_ancestor_of(candidate):
			return candidate as LabResourceRegenerator
	return null


func get_debug_data() -> Dictionary:
	return {
		"lab_resource_regenerator_installer": true,
		"checked_scene_instance_id": checked_scene_instance_id,
		"installed": installed_regenerator != null and is_instance_valid(installed_regenerator),
		"installed_path": (
			str(installed_regenerator.get_path())
			if installed_regenerator != null and is_instance_valid(installed_regenerator)
			else "none"
		),
		"install_count": install_count,
		"reused_count": reused_count,
	}
