extends "res://scripts/actions/death_pursuer_spirit.gd"
class_name DeathPursuerSpiritPresented

const SpellPresentation = preload(
	"res://scripts/presentation/spell_presentation_bridge.gd"
)


func configure(
	new_target: Node3D,
	new_source_actor: Node,
	new_payload: DamagePayload,
	entry_direction: Vector3 = Vector3.FORWARD
) -> bool:
	var configured: bool = super.configure(
		new_target,
		new_source_actor,
		new_payload,
		entry_direction
	)
	if configured:
		call_deferred("_emit_initial_sustain")
	return configured


func _emit_initial_sustain() -> void:
	if dissolving or not is_inside_tree():
		return
	_present_wraith_phase("sustain", "pursuit_started", 0.28, true)


func _apply_pass_damage() -> void:
	var was_done: bool = pass_damage_done
	var target_before: Node3D = _safe_target()
	super._apply_pass_damage()
	if was_done or not pass_damage_done:
		return
	_present_wraith_phase(
		"resolve",
		"pass_through_" + str(passes_completed + 1),
		0.56,
		false,
		target_before
	)


func _begin_dissolve(reason: String) -> void:
	if not dissolving:
		var safe_target: Node3D = _safe_target()
		if reason == "passes_complete":
			_present_wraith_phase("resolve", "pursuit_complete", 0.44, true, safe_target)
		elif reason in ["target_lost", "expired"]:
			_present_wraith_phase("cancel", reason, 0.18, true, safe_target)
	super._begin_dissolve(reason)


func _present_wraith_phase(
	phase: String,
	detail: String,
	intensity: float,
	subtle: bool,
	target_override: Node3D = null
) -> void:
	var safe_target: Node3D = target_override
	if safe_target == null:
		safe_target = _safe_target()
	var position: Vector3 = global_position
	if safe_target != null:
		position = safe_target.global_position + Vector3.UP * 0.65
	SpellPresentation.present(self, phase, {
		"actor": source_actor,
		"target": safe_target,
		"position": position,
		"spell_id": "wraith_pursuit",
		"spell_name": "Wraith Pursuit",
		"element": "death",
		"delivery_type": "autonomous_spirit_pursuit",
		"targeting_style": "target_bound",
		"detail": detail,
		"intensity": intensity,
		"subtle": subtle,
	})


func _safe_target() -> Node3D:
	if target_node == null or not is_instance_valid(target_node):
		return null
	return target_node


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["presentation_sustain"] = true
	data["presentation_pass_resolve"] = true
	data["handoff_precedes_sustain"] = true
	return data
