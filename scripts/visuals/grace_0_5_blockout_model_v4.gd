extends "res://scripts/visuals/grace_0_5_blockout_model_v3.gd"
class_name Grace05BlockoutModelV4

# V4 is a silhouette correction, not another skeleton fix. The prior blockout
# occupied a valid human-height rig, but its oversized dark head, hidden legs,
# barrel torso, and long pale side forms still read as a tiny round mascot at the
# gameplay camera distance. Retune every authored part before V3 records its
# direct-bone local transform.


func _enter_tree() -> void:
	super._enter_tree()
	set_meta("grace_0_5_silhouette_v4", true)


func _build_materials() -> void:
	super._build_materials()
	_set_material_tone("skin", Color(0.62, 0.43, 0.33, 1.0), 0.66)
	_set_material_tone("skin_warm", Color(0.7, 0.47, 0.37, 1.0), 0.68)
	_set_material_tone("robe", Color(0.76, 0.71, 0.62, 1.0), 0.8)
	_set_material_tone("robe_shadow", Color(0.48, 0.43, 0.42, 1.0), 0.84)
	# The original near-black underlayer and boots vanished into the dojo floor,
	# erasing most of Grace's leg length from the silhouette.
	_set_material_tone("underlayer", Color(0.16, 0.115, 0.22, 1.0), 0.69)
	_set_material_tone("leather", Color(0.2, 0.12, 0.075, 1.0), 0.7)
	_set_material_tone("hair", Color(0.075, 0.05, 0.08, 1.0), 0.61)


func _add_mesh(
	part_name: String,
	bone_name: String,
	mesh: Mesh,
	material: Material,
	local_position: Vector3,
	local_rotation_degrees: Vector3 = Vector3.ZERO,
	local_scale: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var tuned_position: Vector3 = local_position
	var tuned_rotation: Vector3 = local_rotation_degrees
	var tuned_scale: Vector3 = local_scale

	if bone_name == "Head":
		# Scale facial features around one shared center so eyes, hair, ears, and
		# brows remain assembled while the head drops from mascot to adolescent.
		var head_center: Vector3 = Vector3(0.0, 0.075, -0.02)
		var offset: Vector3 = tuned_position - head_center
		offset *= Vector3(0.8, 0.84, 0.82)
		tuned_position = head_center + offset
		tuned_scale *= Vector3(0.8, 0.84, 0.82)
		if part_name == "HairBack":
			tuned_scale *= Vector3(0.96, 0.78, 0.92)
			tuned_position.y += 0.025
		elif part_name.begins_with("HairLock"):
			tuned_scale *= Vector3(0.9, 0.72, 0.88)
			tuned_position.y += 0.035
		elif part_name.begins_with("Fringe"):
			tuned_scale *= Vector3(0.92, 0.82, 0.9)

	match part_name:
		"UnderTorso":
			tuned_scale *= Vector3(1.08, 1.13, 1.02)
			tuned_position.y -= 0.025
		"RobeUpper":
			tuned_scale *= Vector3(1.08, 1.12, 1.0)
			tuned_position.y -= 0.025
		"RobeCollar":
			tuned_scale *= Vector3(0.92, 0.86, 0.94)
			tuned_position.y += 0.01
		"LowerTorso":
			tuned_scale *= Vector3(0.94, 1.08, 0.96)
			tuned_position.y += 0.015
		"WaistSash":
			tuned_scale *= Vector3(1.04, 0.92, 1.0)
			tuned_position.y -= 0.015
		"BackRobePanel":
			tuned_scale *= Vector3(0.86, 0.62, 0.92)
			tuned_position.y += 0.075
		"SashTailLeft", "SashTailRight":
			tuned_scale *= Vector3(0.82, 0.56, 0.9)
			tuned_position.y += 0.055
		"LeftHandShape", "RightHandShape":
			tuned_scale *= Vector3(1.12, 1.08, 1.1)
		"LeftThumb", "RightThumb":
			tuned_scale *= Vector3(1.08, 1.08, 1.08)
		"LeftThigh", "RightThigh":
			tuned_scale *= Vector3(1.05, 1.08, 1.08)
		"LeftShin", "RightShin":
			tuned_scale *= Vector3(1.05, 1.08, 1.08)
		"LeftBootLeg", "RightBootLeg":
			tuned_scale *= Vector3(1.12, 1.06, 1.12)
		"LeftBootCuff", "RightBootCuff":
			tuned_scale *= Vector3(1.08, 0.9, 1.08)
		"LeftBootFoot", "RightBootFoot":
			tuned_scale *= Vector3(1.13, 1.08, 1.16)
		"LeftBootToe", "RightBootToe":
			tuned_scale *= Vector3(1.12, 1.06, 1.16)
		_:
			if part_name.ends_with("ShoulderSleeve"):
				tuned_scale *= Vector3(1.15, 0.86, 1.02)
			elif part_name.ends_with("UpperSleeve"):
				tuned_scale *= Vector3(0.94, 1.06, 0.96)
			elif part_name.ends_with("Forearm"):
				tuned_scale *= Vector3(1.02, 1.06, 1.02)
			elif part_name.begins_with("FrontPanel"):
				tuned_scale *= Vector3(0.78, 0.64, 0.9)
				tuned_position.y += 0.075
				tuned_position.z += 0.012
			elif part_name.begins_with("SidePanel"):
				tuned_scale *= Vector3(0.76, 0.61, 0.72)
				tuned_position.y += 0.072

	return super._add_mesh(
		part_name,
		bone_name,
		mesh,
		material,
		tuned_position,
		tuned_rotation,
		tuned_scale
	)


func _set_material_tone(
	material_id: String,
	color: Color,
	roughness_value: float
) -> void:
	var material: StandardMaterial3D = materials.get(
		material_id
	) as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = color
	material.roughness = clampf(roughness_value, 0.0, 1.0)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["grace_0_5_silhouette_v4"] = true
	data["adolescent_head_ratio"] = true
	data["visible_leg_contrast"] = true
	data["shortened_robe_panels"] = true
	return data
