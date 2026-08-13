extends CharacterMaterialPresentationDirector3D
class_name CharacterMaterialSurfacePresentationDirector3D

var surface_targets: Dictionary = {}


func register_surface(target: MeshInstance3D, surface_index: int, role: String) -> bool:
	if profile == null or target == null or not is_instance_valid(target) or target.mesh == null:
		return false
	if surface_index < 0 or surface_index >= target.mesh.get_surface_count():
		return false
	var normalized_role: String = role.strip_edges().to_lower()
	if normalized_role == "":
		return false
	var original_override: Material = target.get_surface_override_material(surface_index)
	var source_material: StandardMaterial3D = original_override as StandardMaterial3D
	if source_material == null:
		source_material = target.mesh.surface_get_material(surface_index) as StandardMaterial3D
	if source_material == null:
		return false
	var key: String = "%d:%d" % [target.get_instance_id(), surface_index]
	if surface_targets.has(key):
		return true
	surface_targets[key] = {
		"ref": weakref(target),
		"source": source_material,
		"original_override": original_override,
		"role": normalized_role,
		"mesh": target.mesh,
		"surface_index": surface_index,
	}
	role_counts[normalized_role] = int(role_counts.get(normalized_role, 0)) + 1
	target.add_to_group("character_material_presentation_target")
	target.set_meta("character_material_surface_role_%d" % surface_index, normalized_role)
	_apply_surface_quality(target, surface_targets[key] as Dictionary, _current_quality())
	return true


func _apply_quality(quality: int) -> void:
	super._apply_quality(quality)
	if profile == null:
		return
	var invalid_keys: Array[String] = []
	for raw_key: Variant in surface_targets.keys():
		var key: String = str(raw_key)
		var record: Dictionary = surface_targets[key] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			invalid_keys.append(key)
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if not target_value is MeshInstance3D:
			invalid_keys.append(key)
			continue
		_apply_surface_quality(target_value as MeshInstance3D, record, active_quality)
	for key: String in invalid_keys:
		surface_targets.erase(key)


func _apply_surface_quality(target: MeshInstance3D, record: Dictionary, quality: int) -> void:
	if target == null or target.mesh == null:
		return
	var surface_index: int = int(record.get("surface_index", -1))
	if surface_index < 0 or surface_index >= target.mesh.get_surface_count():
		return
	var source: StandardMaterial3D = record.get("source") as StandardMaterial3D
	if source == null:
		return
	if not enabled or quality <= 0:
		target.set_surface_override_material(surface_index, record.get("original_override") as Material)
		restored_target_count += 1
		return
	var enhanced: StandardMaterial3D = _get_or_create_enhanced_material(
		source,
		str(record.get("role", "generic")),
		quality
	)
	if enhanced != null:
		target.set_surface_override_material(surface_index, enhanced)


func _restore_originals() -> void:
	super._restore_originals()
	for raw_key: Variant in surface_targets.keys():
		var record: Dictionary = surface_targets[str(raw_key)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if not target_value is MeshInstance3D:
			continue
		var surface_index: int = int(record.get("surface_index", -1))
		if surface_index >= 0:
			(target_value as MeshInstance3D).set_surface_override_material(
				surface_index,
				record.get("original_override") as Material
			)
			restored_target_count += 1


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var live_surface_targets: int = 0
	var surface_geometry_unchanged: bool = true
	for raw_key: Variant in surface_targets.keys():
		var record: Dictionary = surface_targets[str(raw_key)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if target_value is MeshInstance3D:
			live_surface_targets += 1
			if (target_value as MeshInstance3D).mesh != record.get("mesh"):
				surface_geometry_unchanged = false
	data["surface_presentation"] = true
	data["surface_target_count"] = live_surface_targets
	data["target_count"] = int(data.get("target_count", 0)) + live_surface_targets
	data["geometry_unchanged"] = bool(data.get("geometry_unchanged", true)) and surface_geometry_unchanged
	return data
