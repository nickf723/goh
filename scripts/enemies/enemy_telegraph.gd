extends Node
class_name EnemyTelegraph

@export var visual_root_path: NodePath
@export var windup_scale: Vector3 = Vector3(1.18, 1.18, 1.18)
@export var normal_scale: Vector3 = Vector3.ONE

@export var windup_flash_color: Color = Color(1.0, 0.25, 0.15, 1.0)
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var windup_pulse_time: float = 0.12
@export var recover_time: float = 0.18

var visual_root: Node3D
var active_tween: Tween
var material_instances: Array[StandardMaterial3D] = []


func _ready() -> void:
	add_to_group("debuggable")
	find_visual_root()
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

	var target: Node = visual_root

	if target == null:
		target = get_parent()

	if target == null:
		return

	cache_materials_recursive(target)

func cache_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = normal_color
		mesh_instance.material_override = material
		material_instances.append(material)

	for child: Node in node.get_children():
		cache_materials_recursive(child)

func start_windup() -> void:
	if active_tween != null:
		active_tween.kill()

	set_color(windup_flash_color)

	if visual_root == null:
		return

	active_tween = create_tween()
	active_tween.tween_property(
		visual_root,
		"scale",
		windup_scale,
		windup_pulse_time
	)

func start_recover() -> void:
	if active_tween != null:
		active_tween.kill()

	set_color(normal_color)

	if visual_root == null:
		return

	active_tween = create_tween()
	active_tween.tween_property(
		visual_root,
		"scale",
		normal_scale,
		recover_time
	)

func reset() -> void:
	if active_tween != null:
		active_tween.kill()

	set_color(normal_color)

	if visual_root != null:
		visual_root.scale = normal_scale

func set_color(color: Color) -> void:
	for material: StandardMaterial3D in material_instances:
		material.albedo_color = color

func get_debug_data() -> Dictionary:
	return {
		"visual": visual_root.name if visual_root != null else "none",
		"mats": material_instances.size(),
	}
