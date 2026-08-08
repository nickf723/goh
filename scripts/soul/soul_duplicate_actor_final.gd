extends "res://scripts/soul/soul_duplicate_actor_ready.gd"
class_name SoulDuplicateActorFinal

var source_visual: Node3D = null
var spectral_weapon: MeshInstance3D = null
var spectral_material: StandardMaterial3D = null


func configure(source: CharacterBody3D, index: int = 0) -> void:
	super.configure(source, index)
	source_visual = (
		source_actor.get_node_or_null("GraceVisualV1") as Node3D
		if source_actor != null
		else null
	)
	_build_spectral_weapon()
	set_process(true)


func _process(_delta: float) -> void:
	if source_visual == null or visual_root == null:
		return
	# Soul and original receive the same action intent, so the authored Grace pose
	# is reusable. Only local articulated pose is copied; Soul Grace keeps her own
	# world transform, collision result, velocity, and form scale.
	visual_root.rotation = source_visual.rotation
	_sync_pose_children(source_visual, visual_root)


func _sync_pose_children(source_node: Node, target_node: Node) -> void:
	for target_child: Node in target_node.get_children():
		var source_child: Node = source_node.get_node_or_null(NodePath(str(target_child.name)))
		if source_child == null:
			continue
		if target_child is Node3D and source_child is Node3D:
			var target_3d := target_child as Node3D
			var source_3d := source_child as Node3D
			# Preserve any independently authored root-scale relationship. Nested
			# pivots can safely copy their complete local transform.
			target_3d.transform = source_3d.transform
		_sync_pose_children(source_child, target_child)


func get_mechanism_mass_kg() -> float:
	match current_form:
		"grown":
			return 150.0
		"shrunk":
			return 24.0
	return 70.0


func _tint_visual_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = 0.22
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material: Material = mesh_instance.material_override
		if material is StandardMaterial3D:
			var duplicate_material := (material as StandardMaterial3D).duplicate(true) as StandardMaterial3D
			duplicate_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			duplicate_material.albedo_color = duplicate_material.albedo_color.lerp(Color(0.26, 0.9, 1.0, 0.7), 0.35)
			duplicate_material.albedo_color.a = 0.7
			duplicate_material.emission_enabled = true
			duplicate_material.emission = Color(0.08, 0.66, 1.0)
			duplicate_material.emission_energy_multiplier = 0.9
			mesh_instance.material_override = duplicate_material
	for child: Node in node.get_children():
		_tint_visual_recursive(child)


func _build_spectral_weapon() -> void:
	if visual_root == null or spectral_weapon != null:
		return
	var hand: Node3D = visual_root.find_child("RightHandAnchor", true, false) as Node3D
	if hand == null:
		hand = visual_root
	spectral_weapon = MeshInstance3D.new()
	spectral_weapon.name = "SoulSpectralWeapon"
	spectral_weapon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.075, 0.075, 1.15)
	spectral_weapon.mesh = mesh
	spectral_weapon.position = Vector3(0.0, 0.0, -0.5)
	spectral_material = StandardMaterial3D.new()
	spectral_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spectral_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spectral_material.albedo_color = Color(0.28, 0.92, 1.0, 0.64)
	spectral_material.emission_enabled = true
	spectral_material.emission = Color(0.16, 0.78, 1.0)
	spectral_material.emission_energy_multiplier = 2.0
	spectral_weapon.material_override = spectral_material
	hand.add_child(spectral_weapon)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["live_pose_mirroring"] = source_visual != null
	data["spectral_weapon"] = spectral_weapon != null
	data["mechanism_mass_kg"] = get_mechanism_mass_kg()
	data["final_presentation"] = true
	return data
