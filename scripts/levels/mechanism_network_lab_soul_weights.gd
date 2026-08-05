extends "res://scripts/levels/mechanism_network_lab_performance.gd"
class_name MechanismNetworkLabSoulWeights

const WeightBlockScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_weight_block.tscn"
)

var soul_weight_upgrade_count: int = 0
var soul_weight_instruction: Label3D


func _ready() -> void:
	super._ready()
	_upgrade_generated_weight_blocks()
	_add_soul_weight_instruction()
	_show_message(
		"Puzzle weights are now Soul-marked. Select Soul Grip in Focus, hold Cast, and place them on the plates."
	)
	call_deferred("_refresh_all_presentations")


func _upgrade_generated_weight_blocks() -> void:
	var candidates: Array[Node] = get_tree().get_nodes_in_group(
		"mechanism_weights"
	).duplicate()
	for candidate: Node in candidates:
		if not candidate is RigidBody3D or not is_ancestor_of(candidate):
			continue
		_upgrade_rigid_weight(candidate as RigidBody3D)


func _upgrade_rigid_weight(legacy_body: RigidBody3D) -> void:
	if legacy_body == null or not is_instance_valid(legacy_body):
		return
	var parent: Node = legacy_body.get_parent()
	if parent == null:
		return

	var original_name: String = legacy_body.name
	var original_transform: Transform3D = legacy_body.transform
	var original_layer: int = legacy_body.collision_layer
	var original_mask: int = legacy_body.collision_mask
	var mass_kg: float = maxf(
		float(
			legacy_body.get_meta(
				"mechanism_mass_kg",
				legacy_body.mass
			)
		),
		0.1
	)
	var size_value: Vector3 = _read_legacy_block_size(legacy_body)
	var color: Color = _read_legacy_block_color(legacy_body)

	parent.remove_child(legacy_body)
	legacy_body.free()

	var replacement: MechanismWeightBlock = (
		WeightBlockScene.instantiate() as MechanismWeightBlock
	)
	if replacement == null:
		push_warning("Could not instantiate Soul-grippable weight " + original_name)
		return
	replacement.name = original_name
	replacement.transform = original_transform
	replacement.collision_layer = original_layer
	replacement.collision_mask = original_mask
	replacement.configure_weight_block(
		mass_kg,
		size_value,
		color,
		original_name.replace("_", " ")
	)
	parent.add_child(replacement)
	soul_weight_upgrade_count += 1


func _read_legacy_block_size(body: RigidBody3D) -> Vector3:
	var collision: CollisionShape3D = body.get_node_or_null(
		"CollisionShape3D"
	) as CollisionShape3D
	if collision != null and collision.shape is BoxShape3D:
		return (collision.shape as BoxShape3D).size
	var mesh_instance: MeshInstance3D = body.get_node_or_null(
		"MeshInstance3D"
	) as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh is BoxMesh:
		return (mesh_instance.mesh as BoxMesh).size
	return Vector3(1.3, 1.3, 1.3)


func _read_legacy_block_color(body: RigidBody3D) -> Color:
	var mesh_instance: MeshInstance3D = body.get_node_or_null(
		"MeshInstance3D"
	) as MeshInstance3D
	if (
		mesh_instance != null
		and mesh_instance.material_override is StandardMaterial3D
	):
		return (
			mesh_instance.material_override as StandardMaterial3D
		).albedo_color
	return Color(0.48, 0.27, 0.11, 1.0)


func _add_soul_weight_instruction() -> void:
	soul_weight_instruction = _create_station_label(
		"SOUL-GRIPPABLE WEIGHTS\nSelect Soul Grip in Focus • Hold Cast to lift • D-pad adjusts depth",
		Vector3(0.0, 4.15, 178.5),
		Color(0.18, 0.92, 1.0)
	)
	soul_weight_instruction.font_size = 22
	soul_weight_instruction.visibility_range_end = (
		instruction_label_visibility_distance
	)
	soul_weight_instruction.visibility_range_end_margin = 4.0


func reset_lab() -> void:
	super.reset_lab()
	for candidate: Node in get_tree().get_nodes_in_group("mechanism_weights"):
		if (
			candidate is MechanismWeightBlock
			and is_ancestor_of(candidate)
			and candidate.has_method("reset_target")
		):
			candidate.call("reset_target")
	call_deferred("_refresh_all_presentations")


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var soul_weight_count: int = 0
	for candidate: Node in get_tree().get_nodes_in_group("mechanism_weights"):
		if candidate is MechanismWeightBlock and is_ancestor_of(candidate):
			soul_weight_count += 1
	data["soul_grippable_weights"] = soul_weight_count
	data["soul_weight_upgrades"] = soul_weight_upgrade_count
	data["soul_weight_runtime"] = true
	return data
