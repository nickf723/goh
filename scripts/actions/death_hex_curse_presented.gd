extends "res://scripts/actions/death_hex_curse.gd"
class_name DeathHexCursePresented

const SpellPresentation = preload(
	"res://scripts/presentation/spell_presentation_bridge.gd"
)


func bind_to_target(
	new_target: Node3D,
	new_source_actor: Node,
	new_payload: DamagePayload,
	duration: float = -1.0
) -> bool:
	var bound: bool = super.bind_to_target(
		new_target,
		new_source_actor,
		new_payload,
		duration
	)
	if bound:
		call_deferred("_emit_initial_sustain")
	return bound


func _emit_initial_sustain() -> void:
	if released or not is_inside_tree():
		return
	_present_hex_phase("sustain", "curse_active", 0.24, true)


func refresh_hex(
	duration: float = -1.0,
	new_source_actor: Node = null,
	new_payload: DamagePayload = null
) -> void:
	super.refresh_hex(duration, new_source_actor, new_payload)
	if not released:
		_present_hex_phase("sustain", "curse_refreshed", 0.32, true)


func _apply_decay_pulse() -> void:
	var before_index: int = pulse_index
	var pulse_damage: int = get_damage_for_pulse(before_index)
	super._apply_decay_pulse()
	if released or pulse_index <= before_index:
		return
	_present_hex_phase(
		"resolve",
		"decay_pulse_" + str(pulse_index),
		clampf(0.36 + float(pulse_damage) * 0.12, 0.36, 0.78),
		false
	)


func _present_hex_phase(
	phase: String,
	detail: String,
	intensity: float,
	subtle: bool
) -> void:
	var safe_target: Node3D = null
	if target != null and is_instance_valid(target):
		safe_target = target
	var position: Vector3 = global_position
	if visual_root != null and is_instance_valid(visual_root):
		position = visual_root.global_position
	elif safe_target != null:
		position = safe_target.global_position + Vector3.UP * 0.8
	SpellPresentation.present(self, phase, {
		"actor": source_actor,
		"target": safe_target,
		"position": position,
		"spell_id": "death_hex",
		"spell_name": "Death Hex",
		"element": "death",
		"delivery_type": "target_bound_curse",
		"targeting_style": "single_target",
		"detail": detail,
		"intensity": intensity,
		"subtle": subtle,
	})


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["presentation_sustain"] = true
	data["presentation_decay_pulses"] = true
	data["manifest_precedes_sustain"] = true
	return data
