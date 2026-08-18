extends "res://scripts/presentation/presentation_director_spell_audio.gd"
class_name PresentationDirectorAudioFidelityV2

# Thin semantic upgrade over the existing Director. It keeps all established
# impact, reaction, break, spell, haptic, camera, and hit-stop ownership intact,
# while routing footsteps and weapon motion through the richer V2 audio palette.


func present(event_type: String, context: Dictionary = {}) -> Dictionary:
	var normalized: String = event_type.strip_edges().to_lower()
	if normalized == "weapon_motion":
		return present_weapon_motion(context)
	return super.present(event_type, context)


func present_movement(kind: String, context: Dictionary = {}) -> Dictionary:
	var normalized: String = kind.strip_edges().to_lower()
	if normalized != "footstep" or audio == null or not audio.has_method("get_fidelity_version"):
		return super.present_movement(kind, context)
	if int(audio.call("get_fidelity_version")) < 2:
		return super.present_movement(kind, context)

	var actor: Node = _valid_node(context.get("actor"))
	var position: Vector3 = _resolve_position(context, actor)
	var material_id: String = str(context.get("material", "auto")).to_lower()
	if material_id in ["", "auto"]:
		material_id = infer_floor_material(actor, position)
	var strength: float = clampf(float(context.get("strength", 0.22)), 0.0, 0.42)
	var cue_material: String = _normalize_material_cue(material_id)
	var cue_id: String = "footstep_" + cue_material
	var audio_data: Dictionary = audio.play_cue(
		cue_id,
		position,
		clampf(0.20 + strength * 1.25, 0.18, 0.62),
		0.045
	)
	return _record_event("footstep", {
		"actor": actor,
		"position": position,
		"material": material_id,
		"strength": snappedf(strength, 0.01),
		"audio": audio_data,
		"audio_fidelity_v2": true,
		"material_specific_footstep": true,
	})


func present_weapon_motion(context: Dictionary = {}) -> Dictionary:
	var actor: Node = _valid_node(context.get("actor"))
	var position: Vector3 = _resolve_position(context, actor)
	var weapon_class: String = str(context.get("weapon_class", "sword")).strip_edges().to_lower()
	var input_kind: String = str(context.get("input_kind", "light")).strip_edges().to_lower()
	var tags_value: Variant = context.get("tags", [])
	var tags: Array = tags_value as Array if tags_value is Array else []
	var intensity: float = clampf(float(context.get("intensity", 0.5)), 0.0, 1.0)
	var cue_id: String = _weapon_motion_cue(weapon_class, input_kind, tags)
	var audio_data: Dictionary = {}
	if audio != null:
		audio_data = audio.play_cue(
			cue_id,
			position,
			clampf(0.26 + intensity * 0.62, 0.22, 0.92),
			0.035 if input_kind == "heavy" else 0.05
		)
	return _record_event("weapon_motion", {
		"actor": actor,
		"position": position,
		"weapon_class": weapon_class,
		"input_kind": input_kind,
		"attack_id": str(context.get("attack_id", "unknown")),
		"intensity": snappedf(intensity, 0.01),
		"cue": cue_id,
		"audio": audio_data,
		"audio_fidelity_v2": true,
		"camera": false,
		"hit_stop": false,
	})


func _weapon_motion_cue(
	weapon_class: String,
	input_kind: String,
	tags: Array
) -> String:
	if weapon_class == "bow":
		return "weapon_release_bow"
	if weapon_class in ["shuriken", "boomerang"]:
		return "weapon_throw_light"
	if weapon_class == "staff":
		return "weapon_swing_staff"
	if weapon_class == "axe":
		return "weapon_swing_axe"
	if weapon_class in ["whip", "chains", "flail"]:
		return "weapon_swing_flexible"
	if weapon_class in ["daggers", "gauntlets"]:
		return "weapon_swing_fast"
	if weapon_class in ["hammer", "mace", "halberd", "scythe"]:
		return "weapon_swing_heavy"
	if input_kind == "heavy" or tags.has("heavy") or tags.has("cleave"):
		return "weapon_swing_heavy"
	return "weapon_swing_sword"


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["presentation_audio_fidelity_v2"] = true
	data["material_specific_footsteps"] = true
	data["weapon_motion_audio"] = true
	return data
