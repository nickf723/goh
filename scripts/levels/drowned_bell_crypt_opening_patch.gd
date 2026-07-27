extends Node
class_name DrownedBellCryptOpeningPatch

var mission: Node3D
var world: Node3D
var installed: bool = false
var attempts: int = 0


func _ready() -> void:
	call_deferred("_install")


func _install() -> void:
	if installed:
		return
	mission = get_parent() as Node3D
	if mission == null:
		return
	var environment_pass: Node = mission.get_node_or_null("EnvironmentPass")
	if environment_pass != null and not bool(environment_pass.get("installed")):
		attempts += 1
		if attempts < 60:
			call_deferred("_install")
		return
	world = mission.get_node_or_null("World") as Node3D
	if world == null:
		return
	var original: StaticBody3D = world.get_node_or_null("AuthoredEnvironmentV2/ChapelShell/BackWall") as StaticBody3D
	if original == null:
		return
	var material: Material = null
	var original_visual: MeshInstance3D = original.get_node_or_null("Visual") as MeshInstance3D
	if original_visual != null:
		material = original_visual.material_override
	_disable_body(original)
	var patch := Node3D.new()
	patch.name = "CryptDoorwayWallPatch"
	patch.set_meta("authored_environment", true)
	world.add_child(patch)
	_add_wall_box(patch, "BackWallWest", Vector3(3.85, 6.8, 0.72), Vector3(-5.475, 3.4, 36.55), material)
	_add_wall_box(patch, "BackWallEast", Vector3(7.45, 6.8, 0.72), Vector3(3.675, 3.4, 36.55), material)
	_add_wall_box(patch, "BackWallLintel", Vector3(3.5, 3.45, 0.72), Vector3(-1.8, 5.075, 36.55), material)
	installed = true


func _disable_body(body: StaticBody3D) -> void:
	body.visible = false
	body.collision_layer = 0
	body.collision_mask = 0
	var collision: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)


func _add_wall_box(parent: Node3D, node_name: String, size: Vector3, position_value: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.add_to_group("authored_environment_surface")
	body.set_meta("authored_environment", true)
	body.set_meta("authored_role", "crypt_doorway_wall")
	body.set_meta("collision_required", true)
	parent.add_child(body)
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func get_debug_data() -> Dictionary:
	return {"installed": installed}
