extends Node
class_name EnemyTelegraph

@export var visual_root_path: NodePath
@export var windup_scale: Vector3 = Vector3(1.18, 1.18, 1.18)
@export var normal_scale: Vector3 = Vector3.ONE

@export var windup_flash_color: Color = Color(1.0, 0.25, 0.15, 1.0)
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 1.0, 0.05) var flash_strength: float = 0.58

@export var windup_pulse_time: float = 0.12
@export var recover_time: float = 0.18

var visual_root: Node3D
var active_tween: Tween
var base_visual_scale: Vector3 = Vector3.ONE
var material_instances: Array[StandardMaterial3D] = []
var material_base_colors: Array[Color] = []


func _ready() -> void:
	add_to_group("debuggable")
	find_visual_root()

	if visual_root != null:
		base_visual_scale = visual_root.scale
		normal_scale = base_visual_scale

	cache_materials()


func find_visual_root() -> void:
	if visual_root_path != NodePath(""):
		visual_root = get_node_or_null(visual_root_path) as Node3D

	if visual_root == null:
		var parent: Node = get_parent()

		if parent != null:
			var visual_candidate: Node = parent.get_node_or_null("VisualRoot")

			if visual_candidate is Node3D:
				visual_root = visual_candidate as Node3D
				return

			for child: Node in parent.get_children():
				if child is MeshInstance3D:
					visual_root = child as Node3D
					return


func cache_materials() -> void:
	material_instances.clear()
	material_base_colors.clear()

	var target: Node = visual_root

	if target == null:
		target = get_parent()

	if target == null:
		return

	cache_materials_recursive(target)


func cache_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var source_material: Material = mesh_instance.material_override

		if source_material is StandardMaterial3D:
			var material_copy: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
			mesh_instance.material_override = material_copy
			material_instances.append(material_copy)
			material_base_colors.append(material_copy.albedo_color)

	for child: Node in node.get_children():
		cache_materials_recursive(child)


func start_windup() -> void:
	if active_tween != null:
		active_tween.kill()

	set_flash(windup_flash_color)

	if visual_root == null:
		return

	if visual_root.has_method("start_windup"):
		visual_root.call("start_windup")

	active_tween = create_tween()
	active_tween.tween_property(
		visual_root,
		"scale",
		base_visual_scale * windup_scale,
		windup_pulse_time
	)


func start_recover() -> void:
	if active_tween != null:
		active_tween.kill()

	set_flash(normal_color, 0.0)

	if visual_root == null:
		return

	if visual_root.has_method("start_recover"):
		visual_root.call("start_recover")

	active_tween = create_tween()
	active_tween.tween_property(
		visual_root,
		"scale",
		base_visual_scale,
		recover_time
	)


func reset() -> void:
	if active_tween != null:
		active_tween.kill()
		active_tween = null

	set_flash(normal_color, 0.0)

	if visual_root != null:
		visual_root.scale = base_visual_scale

		if visual_root.has_method("reset_presentation"):
			visual_root.call("reset_presentation")


func set_flash(color: Color, strength: float = -1.0) -> void:
	var applied_strength: float = flash_strength if strength < 0.0 else strength

	for index: int in range(material_instances.size()):
		var material: StandardMaterial3D = material_instances[index]
		var base_color: Color = material_base_colors[index]
		material.albedo_color = base_color.lerp(color, clamp(applied_strength, 0.0, 1.0))


func get_debug_data() -> Dictionary:
	return {
		"visual": visual_root.name if visual_root != null else "none",
		"mats": material_instances.size(),
		"scale": base_visual_scale,
	}
