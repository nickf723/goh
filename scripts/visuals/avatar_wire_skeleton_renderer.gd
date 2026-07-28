extends "res://scripts/visuals/grace_wire_skeleton_renderer.gd"
class_name AvatarWireSkeletonRenderer

var avatar_palette_override_active: bool = false
var active_avatar_id: String = "grace"
var active_avatar_display_name: String = "Grace"
var active_avatar_element: String = ""
var avatar_palette: Dictionary = {}
var avatar_emission_multiplier: float = 1.35


func set_outfit_id(outfit_id: String) -> void:
	current_outfit_id = outfit_id
	if avatar_palette_override_active:
		_apply_avatar_palette()
		return
	super.set_outfit_id(outfit_id)


func set_avatar_presentation(definition: PlayableAvatarDefinition) -> bool:
	if definition == null:
		return false
	active_avatar_id = definition.avatar_id
	active_avatar_display_name = definition.display_name
	active_avatar_element = definition.element
	avatar_palette_override_active = definition.override_wire_palette
	avatar_palette = definition.get_wire_palette()
	avatar_emission_multiplier = maxf(definition.wire_emission_multiplier, 0.05)
	if avatar_palette_override_active:
		_apply_avatar_palette()
	else:
		super.set_outfit_id(current_outfit_id)
	return true


func clear_avatar_presentation() -> void:
	avatar_palette_override_active = false
	active_avatar_id = "grace"
	active_avatar_display_name = "Grace"
	active_avatar_element = ""
	avatar_palette.clear()
	avatar_emission_multiplier = 1.35
	super.set_outfit_id(current_outfit_id)
	_set_wire_emission(avatar_emission_multiplier)


func capture_avatar_presentation() -> Dictionary:
	return {
		"override": avatar_palette_override_active,
		"avatar_id": active_avatar_id,
		"display_name": active_avatar_display_name,
		"element": active_avatar_element,
		"palette": avatar_palette.duplicate(true),
		"emission": avatar_emission_multiplier,
		"outfit_id": current_outfit_id,
	}


func restore_avatar_presentation(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		clear_avatar_presentation()
		return true
	current_outfit_id = str(snapshot.get("outfit_id", current_outfit_id))
	avatar_palette_override_active = bool(snapshot.get("override", false))
	active_avatar_id = str(snapshot.get("avatar_id", "grace"))
	active_avatar_display_name = str(snapshot.get("display_name", "Grace"))
	active_avatar_element = str(snapshot.get("element", ""))
	var palette_value: Variant = snapshot.get("palette", {})
	avatar_palette = (
		(palette_value as Dictionary).duplicate(true)
		if palette_value is Dictionary
		else {}
	)
	avatar_emission_multiplier = maxf(float(snapshot.get("emission", 1.35)), 0.05)
	if avatar_palette_override_active:
		_apply_avatar_palette()
	else:
		super.set_outfit_id(current_outfit_id)
		_set_wire_emission(avatar_emission_multiplier)
	return true


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["avatar_id"] = active_avatar_id
	data["avatar_display_name"] = active_avatar_display_name
	data["avatar_element"] = active_avatar_element
	data["avatar_palette_override"] = avatar_palette_override_active
	data["avatar_emission"] = avatar_emission_multiplier
	return data


func _apply_avatar_palette() -> void:
	_set_material_color(
		center_material,
		avatar_palette.get("center", Color(0.88, 0.9, 1.0))
	)
	_set_material_color(
		left_material,
		avatar_palette.get("left", Color(0.28, 0.82, 1.0))
	)
	_set_material_color(
		right_material,
		avatar_palette.get("right", Color(1.0, 0.42, 0.78))
	)
	_set_material_color(
		joint_material,
		avatar_palette.get("joint", Color(1.0, 0.76, 0.24))
	)
	_set_wire_emission(float(avatar_palette.get("emission", avatar_emission_multiplier)))


func _set_wire_emission(multiplier: float) -> void:
	avatar_emission_multiplier = maxf(multiplier, 0.05)
	for material: StandardMaterial3D in [
		center_material,
		left_material,
		right_material,
		joint_material,
	]:
		if material != null:
			material.emission_energy_multiplier = avatar_emission_multiplier
