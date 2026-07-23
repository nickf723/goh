extends StaticBody3D
class_name StructuralConnection3D

signal connection_failed(connection: StructuralConnection3D, reason: String, peak_stress_n: float)
signal connection_reset(connection: StructuralConnection3D)

@export var connection_id: String = ""
@export var member_a_path: NodePath
@export var member_b_path: NodePath
@export var anchor_a_to_world: bool = false
@export var anchor_b_to_world: bool = false
@export var integrity_path: NodePath = NodePath("StructuralIntegrity")
@export var break_visual_path: NodePath = NodePath("Visual")
@export var cut_tether_path: NodePath

var member_a: StructuralMember3D = null
var member_b: StructuralMember3D = null
var integrity: StructuralIntegrity = null
var broken: bool = false
var visual_material: StandardMaterial3D = null


func _ready() -> void:
	if connection_id == "":
		connection_id = name.to_snake_case()
	resolve_endpoints()
	integrity = get_node_or_null(integrity_path) as StructuralIntegrity
	if integrity != null:
		integrity.integrity_failed.connect(_on_integrity_failed)
		integrity.integrity_changed.connect(_on_integrity_changed)
	cache_visual_material()
	add_to_group("structural_connections")
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func resolve_endpoints() -> void:
	member_a = get_node_or_null(member_a_path) as StructuralMember3D
	member_b = get_node_or_null(member_b_path) as StructuralMember3D


func has_world_anchor() -> bool:
	return anchor_a_to_world or anchor_b_to_world


func contains_member(member: StructuralMember3D) -> bool:
	return member != null and (member == member_a or member == member_b)


func get_other_member(member: StructuralMember3D) -> StructuralMember3D:
	if member == member_a:
		return member_b
	if member == member_b:
		return member_a
	return null


func set_sustained_load(load_n: float) -> void:
	if integrity != null and not broken:
		integrity.set_sustained_stress(load_n, "supported weight")


func apply_structural_stress(
	stress_n: float,
	source_name: String = "external load"
) -> void:
	if integrity != null and not broken:
		integrity.apply_transient_stress(stress_n, source_name)


func break_connection(
	reason: String = "structural failure",
	peak_stress_n: float = -1.0
) -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	collision_mask = 0
	for child: Node in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).set_deferred("disabled", true)
	if integrity != null and not integrity.failed:
		integrity.fail_integrity(reason, peak_stress_n)
	var tether: Node = get_node_or_null(cut_tether_path)
	if tether != null and tether.has_method("cut"):
		tether.call("cut")
	var anchor: MetalTetherAnchor3D = get_node_or_null("MetalTetherAnchor") as MetalTetherAnchor3D
	if anchor != null and not anchor.broken:
		anchor.accepts_tether = false
	update_visual(1.0, true)
	connection_failed.emit(
		self,
		reason,
		integrity.peak_stress_n if integrity != null else maxf(peak_stress_n, 0.0)
	)


func reset_connection() -> void:
	broken = false
	collision_layer = 1
	collision_mask = 1
	for child: Node in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).set_deferred("disabled", false)
	if integrity != null:
		integrity.reset_integrity()
	var anchor: MetalTetherAnchor3D = get_node_or_null("MetalTetherAnchor") as MetalTetherAnchor3D
	if anchor != null:
		anchor.reset_anchor()
	update_visual(0.0, false)
	connection_reset.emit(self)


func reset_target() -> void:
	reset_connection()


func cache_visual_material() -> void:
	var mesh_instance: MeshInstance3D = get_node_or_null(break_visual_path) as MeshInstance3D
	if mesh_instance == null:
		return
	var existing_material: Material = mesh_instance.material_override
	if existing_material is StandardMaterial3D:
		visual_material = (existing_material as StandardMaterial3D).duplicate(true)
	else:
		visual_material = StandardMaterial3D.new()
	mesh_instance.material_override = visual_material
	update_visual(0.0, false)


func update_visual(stress_ratio: float, is_failed: bool) -> void:
	if visual_material == null or integrity == null or integrity.material_profile == null:
		return
	var profile: StructuralMaterialProfile = integrity.material_profile
	var target_color: Color = profile.failed_color if is_failed else profile.intact_color.lerp(
		profile.stressed_color,
		clampf(stress_ratio, 0.0, 1.0)
	)
	visual_material.albedo_color = target_color
	visual_material.emission_enabled = not is_failed and stress_ratio >= 0.55
	visual_material.emission = target_color
	visual_material.emission_energy_multiplier = clampf(stress_ratio, 0.0, 1.0)


func _on_integrity_changed(stress_n: float, capacity_n: float) -> void:
	update_visual(stress_n / maxf(capacity_n, 1.0), false)


func _on_integrity_failed(reason: String, peak_stress_n: float) -> void:
	if not broken:
		break_connection(reason, peak_stress_n)


func get_debug_data() -> Dictionary:
	return {
		"structural_connection": connection_id,
		"broken": broken,
		"world_anchor": has_world_anchor(),
		"member_a": member_a.structural_id if member_a != null else "none",
		"member_b": member_b.structural_id if member_b != null else "none",
		"integrity": integrity.get_debug_data() if integrity != null else {},
	}
