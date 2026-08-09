extends "res://scripts/actions/death_wraith_projectile.gd"
class_name DeathWraithProjectilePresented

const SpellPresentation = preload(
	"res://scripts/presentation/spell_presentation_bridge.gd"
)


func _spawn_pursuer_spirit(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	super._spawn_pursuer_spirit(target)
	SpellPresentation.present(self, "handoff", {
		"actor": source_actor,
		"target": target,
		"position": global_position,
		"spell_id": "wraith_pursuit",
		"spell_name": "Wraith Pursuit",
		"element": "death",
		"delivery_type": "projectile_spirit_pursuit",
		"targeting_style": "aimed",
		"detail": "projectile_to_spirit",
		"intensity": 0.74,
	})


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["presentation_handoff"] = true
	return data
